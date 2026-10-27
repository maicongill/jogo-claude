class_name Enemy
extends CharacterBody3D
## Inimigo genérico. O tipo (config "enemy_types": saltilho, musgolho, cuspidor) define vida,
## velocidade, golpe, resistência e se ataca de perto ou à distância. Vaga pelo mapa, percebe o
## jogador (mostra "!"), persegue, avisa antes de atacar (cresce e fica vermelho) e reage aos
## golpes com recuo, atordoamento e flash branco.

signal died(enemy: Enemy)

enum State { IDLE, PATROL, ALERT, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

# Padrões; config/game_config.json (seção "enemy") sobrescreve ao nascer.
var max_health := 40.0
var chase_speed := 3.6
var patrol_speed := 1.3
var sight_range := 14.0
var lose_range := 24.0
var attack_range := 1.9
var attack_damage := 12.0
var windup_time := 0.55
var attack_cooldown := 1.4
var attack_knockback := 7.0
## Resistência: golpes com dano menor que isto (e que não são carregados) não atordoam.
var poise := 0.0
var display_name := "Musgolho"
var body_scale := 1.0
## Ataque à distância (cuspidor): mantém essa distância e cospe projéteis.
var ranged := false
var keep_distance := 0.0
var projectile_speed := 16.0
var hop := false
var wander_radius := 18.0
var type_id: StringName = &""

var health := 40.0
var state: State = State.IDLE
var spawn_key := ""

var _target: Player
var _timer := 0.0
var _patrol_point := Vector3.ZERO
var _home := Vector3.ZERO
var _body: MeshInstance3D
var _mat: ShaderMaterial
var _color := Color(0.32, 0.55, 0.28)
var _label: Label3D
var _fire: BurnEffect
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _alert: Label3D
var _t := 0.0
var _body_y := 0.55


func _ready() -> void:
	var c := Config.section("enemy")
	max_health = c.get("max_health", max_health)
	chase_speed = c.get("chase_speed", chase_speed)
	patrol_speed = c.get("patrol_speed", patrol_speed)
	sight_range = c.get("sight_range", sight_range)
	lose_range = c.get("lose_range", lose_range)
	attack_range = c.get("attack_range", attack_range)
	attack_damage = c.get("attack_damage", attack_damage)
	windup_time = c.get("windup_time", windup_time)
	attack_cooldown = c.get("attack_cooldown", attack_cooldown)
	attack_knockback = c.get("attack_knockback", attack_knockback)
	wander_radius = c.get("wander_radius", wander_radius)
	if type_id != &"":
		_apply_type(Config.get_value("enemy_types." + String(type_id), {}))
	add_to_group(&"enemy")
	collision_layer = 4
	collision_mask = 1 | 2 | 16
	health = max_health
	_home = global_position
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.1
	cs.shape = cap
	cs.position.y = 0.55
	add_child(cs)

	scale = Vector3.ONE * body_scale
	_mat = MaterialFactory.solid(_color, MaterialFactory.Hull.NORMAL)
	_body = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 0.95
	_body.mesh = sphere
	_body.position.y = 0.55
	_body.material_override = _mat
	add_child(_body)
	# Olhos e chifrinhos (voltados para -Z, como o jogador).
	for sx in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		eye.mesh = em
		eye.position = Vector3(0.18 * sx, 0.75, -0.42)
		eye.material_override = MaterialFactory.solid(Color(0.97, 0.95, 0.5), MaterialFactory.Hull.NONE)
		add_child(eye)
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.0
		hm.bottom_radius = 0.07
		hm.height = 0.3
		horn.mesh = hm
		horn.position = Vector3(0.25 * sx, 1.05, -0.1)
		horn.rotation.z = -0.35 * sx
		horn.material_override = MaterialFactory.solid(Color(0.85, 0.8, 0.6), MaterialFactory.Hull.NORMAL)
		add_child(horn)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.6
	_label.font_size = 36
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)
	_alert = Label3D.new()
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.position.y = 1.35
	_alert.font_size = 72
	_alert.outline_size = 12
	_alert.modulate = Color(1, 0.85, 0.2)
	_alert.no_depth_test = true
	_alert.text = "!"
	_alert.visible = false
	add_child(_alert)
	if ranged:
		# Cuspidor: boca em forma de tubo.
		var mouth := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.12
		mm.bottom_radius = 0.16
		mm.height = 0.3
		mouth.mesh = mm
		mouth.rotation.x = PI / 2.0
		mouth.position = Vector3(0, 0.5, -0.5)
		mouth.material_override = MaterialFactory.solid(_color.darkened(0.35), MaterialFactory.Hull.NORMAL)
		add_child(mouth)
	_pick_idle()


## Lê um bloco de "enemy_types" (o que faltar mantém o valor padrão da seção "enemy").
func _apply_type(t: Dictionary) -> void:
	display_name = t.get("name", display_name)
	max_health = t.get("max_health", max_health)
	chase_speed = t.get("chase_speed", chase_speed)
	patrol_speed = t.get("patrol_speed", patrol_speed)
	sight_range = t.get("sight_range", sight_range)
	lose_range = t.get("lose_range", lose_range)
	attack_range = t.get("attack_range", attack_range)
	attack_damage = t.get("attack_damage", attack_damage)
	windup_time = t.get("windup_time", windup_time)
	attack_cooldown = t.get("attack_cooldown", attack_cooldown)
	attack_knockback = t.get("attack_knockback", attack_knockback)
	poise = t.get("poise", poise)
	body_scale = t.get("scale", body_scale)
	ranged = t.get("ranged", ranged)
	keep_distance = t.get("keep_distance", keep_distance)
	projectile_speed = t.get("projectile_speed", projectile_speed)
	hop = t.get("hop", hop)
	wander_radius = t.get("wander_radius", wander_radius)
	_color = Config.to_color(t.get("color"), _color)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_timer -= delta
	_t += delta
	_find_target()
	match state:
		State.IDLE:
			_move_towards(global_position, 0.0, delta)
			if _sees_target():
				_start_alert()
			elif _timer <= 0.0:
				_start_patrol()
		State.PATROL:
			_move_towards(_patrol_point, patrol_speed, delta)
			if _sees_target():
				_start_alert()
			elif _flat_dist(_patrol_point) < 0.6 or _timer <= 0.0:
				_pick_idle()
		State.ALERT:
			# Percebeu o jogador: para, olha e mostra "!" antes de partir para cima.
			_move_towards(global_position, 0.0, delta)
			if _target:
				_face(_target.global_position)
			if _timer <= 0.0:
				_alert.visible = false
				state = State.CHASE
		State.CHASE:
			if _target == null or _target.stats.dead or _dist_to_target() > lose_range:
				_pick_idle()
			elif ranged and _dist_to_target() < keep_distance:
				# Muito perto: recua mantendo a distância.
				var away := global_position + (global_position - _target.global_position)
				_move_towards(away, chase_speed, delta)
				_face(_target.global_position)
			elif _dist_to_target() <= attack_range:
				state = State.WINDUP
				_timer = windup_time
				_set_color(Color(0.85, 0.25, 0.2))
				_alert.visible = true
				_alert.modulate = Color(1, 0.3, 0.2)
			else:
				_move_towards(_target.global_position, chase_speed, delta)
		State.WINDUP:
			_move_towards(global_position, 0.0, delta)
			_face(_target.global_position)
			_body.scale = Vector3.ONE * (1.0 + 0.25 * (1.0 - _timer / windup_time))
			if _timer <= 0.0:
				_alert.visible = false
				_strike()
		State.RECOVER:
			_move_towards(global_position, 0.0, delta)
			if _timer <= 0.0:
				state = State.CHASE if _target and _dist_to_target() < lose_range else State.IDLE
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
			if _timer <= 0.0:
				state = State.CHASE
	if hop and state in [State.PATROL, State.CHASE] and Vector2(velocity.x, velocity.z).length() > 0.5:
		_body.position.y = _body_y + absf(sin(_t * 13.0)) * 0.22  # o saltilho anda pulando
	else:
		_body.position.y = lerpf(_body.position.y, _body_y, 0.3)
	move_and_slide()


func _sees_target() -> bool:
	return _target != null and not _target.stats.dead and _dist_to_target() < sight_range


func _start_alert() -> void:
	state = State.ALERT
	_timer = Config.f("enemy.alert_time", 0.45)
	_alert.modulate = Color(1, 0.85, 0.2)
	_alert.visible = true


## Pega fogo por alguns segundos (dano contínuo).
func burn(duration: float) -> void:
	if state == State.DEAD or _fire != null:
		return
	_fire = BurnEffect.new()
	_fire.dps = Config.f("magic.burn_dps_enemy", 4.0)
	_fire.duration = duration
	_fire.size = 0.7
	add_child(_fire)
	_fire.position.y = 0.6
	_fire.tick.connect(func(amount: float) -> void: take_damage(amount, global_position + global_basis.z, 0.0))


func _set_color(c: Color) -> void:
	_mat.set_shader_parameter("albedo", c)


func _find_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Player


func _dist_to_target() -> float:
	return global_position.distance_to(_target.global_position)


func _flat_dist(p: Vector3) -> float:
	return Vector2(global_position.x - p.x, global_position.z - p.z).length()


func _face(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), 0.25)


func _move_towards(p: Vector3, speed: float, delta: float) -> void:
	var d := p - global_position
	d.y = 0.0
	var dir := d.normalized() if d.length() > 0.05 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, dir.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 18.0 * delta)
	if dir != Vector3.ZERO:
		_face(p)


func _pick_idle() -> void:
	state = State.IDLE
	_timer = randf_range(1.5, 4.0)


func _start_patrol() -> void:
	state = State.PATROL
	var a := randf() * TAU
	# Vaga pelo mapa: cada passeio vai para um ponto novo perto de onde está (e não volta sempre à casa).
	var from := global_position.lerp(_home, 0.25)
	_patrol_point = from + Vector3(cos(a), 0, sin(a)) * randf_range(wander_radius * 0.35, wander_radius)
	_timer = 12.0


func _strike() -> void:
	_body.scale = Vector3.ONE
	_set_color(_color)
	if ranged:
		if _target:
			var from := global_position + Vector3(0, 0.6 * body_scale, 0) - global_basis.z * 0.6
			var aim := _target.global_position + Vector3(0, 1.0, 0) + _target.velocity * 0.25
			EnemyProjectile.launch(get_parent(), from, aim - from, projectile_speed, attack_damage, attack_knockback, self)
		state = State.RECOVER
		_timer = attack_cooldown
		return
	if _target and _flat_dist(_target.global_position) <= attack_range + 0.7 and absf(_target.global_position.y - global_position.y) < 2.0:
		_target.take_hit(attack_damage, global_position, attack_knockback)
	state = State.RECOVER
	_timer = attack_cooldown


func take_damage(amount: float, from_pos: Vector3, knockback := 6.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_label.text = "%s  %d/%d" % [display_name, maxi(ceili(health), 0), int(max_health)]
	_label.visible = true
	# Golpe forte (dano >= resistência ou carregado) atordoa; fraco num inimigo resistente só o empurra um pouco.
	var staggers := knockback > 0.0 and (amount >= poise or knockback >= Config.f("enemy.heavy_knockback", 10.0))
	if knockback > 0.0:
		var away := global_position - from_pos
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else -global_basis.z
		var kb := knockback if staggers else knockback * 0.2
		velocity = away * kb + Vector3(0, 2.5 if staggers else 0.0, 0)
	if staggers:
		_body.scale = Vector3.ONE
		_alert.visible = false
		_set_color(_color)
	_set_color(Color(1, 1, 1))
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_callback(func() -> void: _set_color(_color))
	if health <= 0.0:
		_die()
		return
	if staggers:
		state = State.STAGGER
		_timer = Config.f("enemy.stagger_time", 0.45)
	elif state in [State.IDLE, State.PATROL, State.ALERT]:
		state = State.CHASE  # levou um golpe: vai atrás de quem bateu


## Texto que sobe e some sobre o inimigo (ex.: "Crítico!").
func popup(text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.outline_size = 10
	l.modulate = color
	l.no_depth_test = true
	l.position.y = 1.8
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 2.6, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	if spawn_key != "":
		WorldState.killed_enemies[spawn_key] = true
	var meat := Database.item(&"meat")
	if meat != null:
		ItemPickup.spawn(get_parent(), global_position + Vector3(0, 0.3, 0), meat, randi_range(1, 2))
	EventBus.enemy_killed.emit(self)
	died.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.4)
	tw.tween_callback(queue_free)
