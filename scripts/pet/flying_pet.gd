class_name FlyingPet
extends CharacterBody3D
## Criatura voadora (Aerolho): selvagem pelo mundo, pode ser domada, selada e montada.
## Movimento cinemático por código; o chão vem da função de altura do terreno.

enum State { PERCH, WANDER, FLEE, FOLLOW, MOUNTED, DEAD }

signal trust_changed(pet: FlyingPet)
signal died(pet: FlyingPet)

const OBSERVE_FOOD_AT := 3.0
const OBSERVE_BIOME_AT := 6.0
const FLEE_DISTANCE := 9.0
const OBSERVE_RANGE := 20.0
const FOOD_BUFF_TIME := 30.0

var data: PetData
var height_fn: Callable
var forest_fn: Callable  # (x, z) -> bool

var state: State = State.PERCH
var trust := 0.0
var level := 0
var saddled := false
var health := 60.0
var stamina := 100.0
var exhausted := false
var observe_time := 0.0
var knows_food := false
var knows_biome := false
var respawn_delay := 6.0

var rider: Player
var seat: Marker3D

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _timer := 0.0
var _food_buff := 0.0
var _flap := 0.0
var _wings: Array[Node3D] = []
var _label: Label3D
var _body: Node3D
var _player: Player
var _last_player_pos := Vector3.ZERO
var _player_idle := 0.0
var _flying := false


func _ready() -> void:
	add_to_group(&"pet")
	collision_layer = 64
	collision_mask = 0
	health = data.max_health
	stamina = data.max_stamina
	_home = global_position
	_build_model()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.7
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_enter_perch()
	_update_label()


func _build_model() -> void:
	_body = Node3D.new()
	add_child(_body)
	var teal := Color(0.30, 0.78, 0.82)
	var dark := Color(0.18, 0.52, 0.70)
	var cream := Color(0.97, 0.93, 0.80)
	var orange := Color(0.98, 0.65, 0.2)
	_add_mesh(_body, _sphere(0.6, Vector3(1.0, 0.9, 1.45)), Vector3(0, 0.95, 0), teal)
	_add_mesh(_body, _sphere(0.45, Vector3(0.9, 0.55, 1.1)), Vector3(0, 0.75, -0.1), cream)
	_add_mesh(_body, _sphere(0.34, Vector3.ONE), Vector3(0, 1.45, -0.7), teal)
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.1
	beak.height = 0.35
	var bm := _add_mesh(_body, beak, Vector3(0, 1.4, -1.1), orange)
	bm.rotation.x = -PI / 2.0
	for sx in [-1, 1]:
		_add_mesh(_body, _sphere(0.06, Vector3.ONE), Vector3(0.14 * sx, 1.52, -0.95), Color(0.1, 0.1, 0.15), MaterialFactory.Hull.NONE)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.5, 0.08, 0.9)
	var tm := _add_mesh(_body, tail, Vector3(0, 1.0, 1.0), dark, MaterialFactory.Hull.BOX)
	tm.rotation.x = 0.25
	for sx in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.45 * sx, 1.05, 0)
		_body.add_child(pivot)
		var wing := BoxMesh.new()
		wing.size = Vector3(1.7, 0.07, 0.8)
		var wm := _add_mesh(pivot, wing, Vector3(0.85 * sx, 0, 0), dark, MaterialFactory.Hull.BOX)
		wm.name = "Wing"
		_wings.append(pivot)
	seat = Marker3D.new()
	seat.position = Vector3(0, 1.45, 0.1)
	_body.add_child(seat)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.7, 0)
	_label.font_size = 40
	_label.outline_size = 10
	_label.no_depth_test = true
	add_child(_label)


func _sphere(r: float, squash: Vector3) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	set_meta(&"squash", squash)
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, hull := MaterialFactory.Hull.NORMAL) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if mesh is SphereMesh and has_meta(&"squash"):
		mi.scale = get_meta(&"squash")
		remove_meta(&"squash")
	mi.material_override = MaterialFactory.solid(color, hull)
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- confiança e preferências

func trust_to_level(t: float) -> int:
	var lv := 0
	for i in data.trust_thresholds.size():
		if t >= data.trust_thresholds[i]:
			lv = i + 1
	return lv


func add_trust(amount: float) -> void:
	trust = minf(trust + amount, float(data.trust_thresholds[data.trust_thresholds.size() - 1]))
	var new_level := trust_to_level(trust)
	if new_level > level:
		level = new_level
		var texts := ["", "%s já tolera você.", "%s vai seguir você!", "%s aceita sela e montaria!"]
		EventBus.message.emit(texts[level] % data.display_name)
		if level >= 1 and state in [State.FLEE]:
			_enter_perch()
	trust_changed.emit(self)
	_update_label()


## Magia de doma: ganha confiança; preferências conhecidas e atendidas aceleram.
func on_tame_spell() -> float:
	var gain := 8.0
	if in_favorite_biome():
		gain *= 1.5
	if _food_buff > 0.0:
		gain *= 2.0
	add_trust(gain)
	_spawn_hearts()
	return gain


func in_favorite_biome() -> bool:
	var forest: bool = forest_fn.call(global_position.x, global_position.z)
	return (data.favorite_biome == &"forest") == forest


func feed(food: ItemData) -> void:
	if data.favorite_food != null and food.id == data.favorite_food.id:
		add_trust(15.0)
		_food_buff = FOOD_BUFF_TIME
		knows_food = true
		EventBus.message.emit("%s adorou %s! A confiança vai subir mais rápido por um tempo." % [data.display_name, food.display_name])
	else:
		add_trust(3.0)
		EventBus.message.emit("%s aceitou, mas não é seu favorito." % data.display_name)
	_spawn_hearts()
	_update_label()


func _spawn_hearts() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 10
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0, -0.5, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(1.0, 0.45, 0.65)
	quad.material = m
	p.mesh = quad
	add_child(p)
	p.position.y = 2.0
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _update_label() -> void:
	if _label == null:
		return
	var t := "%s  Nv %d  (%d/%d)" % [data.display_name, level, int(trust), data.trust_thresholds[data.trust_thresholds.size() - 1]]
	var likes: PackedStringArray = []
	if knows_food and data.favorite_food != null:
		likes.append(data.favorite_food.display_name)
	if knows_biome:
		likes.append("floresta" if data.favorite_biome == &"forest" else "planície")
	if likes.size() > 0:
		t += "\nGosta de: " + ", ".join(likes)
	elif level < 3:
		t += "\nPreferências: ? (observe)"
	if saddled:
		t += "\n[selado]"
	_label.text = t


# ---------------------------------------------------------------- interação

func interact(player: Player) -> void:
	var held := player.held_item()
	if held != null and held.kind == ItemData.Kind.SADDLE:
		if level < 3:
			EventBus.message.emit("%s ainda não confia o bastante para aceitar a sela (nível 3)." % data.display_name)
		elif saddled:
			EventBus.message.emit("Já está selado.")
		else:
			saddled = true
			player.inventory.remove_from_slot(player.selected_slot, 1)
			EventBus.message.emit("Sela colocada! Aperte F perto dele para montar.")
			_update_label()
		return
	if held != null and held.kind == ItemData.Kind.FOOD:
		feed(held)
		player.inventory.remove_from_slot(player.selected_slot, 1)
		return
	if saddled and level >= 3:
		toggle_mount(player)
		return
	EventBus.message.emit("%s — confiança %d/%d. Mire nele, use a magia de doma e ofereça comida." % [data.display_name, int(trust), data.trust_thresholds[data.trust_thresholds.size() - 1]])


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"mount") or Game.is_ui_open() or state == State.DEAD:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if rider == player:
		toggle_mount(player)
	elif saddled and level >= 3 and rider == null and global_position.distance_to(player.global_position) < 5.0 and player.mounted_pet == null:
		toggle_mount(player)


func toggle_mount(player: Player) -> void:
	if rider == player:
		dismount()
	elif rider == null and player.mounted_pet == null:
		mount(player)


func mount(player: Player) -> void:
	rider = player
	player.mounted_pet = self
	player.frozen = true
	player.velocity = Vector3.ZERO
	player.set_collision_enabled(false)
	state = State.MOUNTED
	EventBus.message.emit("Montado! WASD voa, Espaço sobe, C desce, Shift acelera (gasta estamina). F desmonta.")
	EventBus.pet_mounted.emit(self, true)


func dismount() -> void:
	if rider == null:
		return
	var player := rider
	rider = null
	player.mounted_pet = null
	player.global_position = global_position + Vector3(0, 0.2, 0) + global_basis.x * 1.6
	player.velocity = Vector3.ZERO
	player.set_collision_enabled(true)
	player.frozen = false
	state = State.FOLLOW if level >= 2 else State.PERCH
	_timer = 0.0
	EventBus.pet_mounted.emit(self, false)


## Dano recebido (inclusive dos ataques que mirariam no cavaleiro).
func take_damage(amount: float, _from: Vector3 = Vector3.ZERO, _knockback := 0.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		die()


func die() -> void:
	if rider != null:
		dismount()
	state = State.DEAD
	visible = false
	collision_layer = 0
	died.emit(self)
	if Game.stables.is_empty():
		EventBus.message.emit("%s morreu. Construa um estábulo para que seu pet possa renascer." % data.display_name)
		queue_free()
		return
	EventBus.message.emit("%s morreu e vai renascer no estábulo." % data.display_name)
	await get_tree().create_timer(respawn_delay).timeout
	var best: Vector3 = Game.stables[0]
	global_position = best + Vector3(0, 0.1, 1.8)
	health = data.max_health
	stamina = data.max_stamina
	exhausted = false
	visible = true
	collision_layer = 64
	_home = global_position
	state = State.FOLLOW if level >= 2 else State.PERCH
	_enter_perch()
	EventBus.message.emit("%s renasceu no estábulo." % data.display_name)


# ---------------------------------------------------------------- comportamento

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	_food_buff = maxf(_food_buff - delta, 0.0)
	_observe(delta)
	match state:
		State.PERCH:
			_do_perch(delta)
		State.WANDER:
			_do_wander(delta)
		State.FLEE:
			_do_flee(delta)
		State.FOLLOW:
			_do_follow(delta)
		State.MOUNTED:
			_do_mounted(delta)
	_apply_ground()
	_animate(delta)
	if state != State.MOUNTED:
		_regen(delta, false)


func _observe(delta: float) -> void:
	if _player == null or level >= 3 and knows_food and knows_biome or rider != null:
		return
	var to_pet := global_position + Vector3(0, 1.0, 0) - _player.camera.global_position
	if to_pet.length() > OBSERVE_RANGE or to_pet.length() < 0.5:
		return
	if _player.camera_forward().dot(to_pet.normalized()) < 0.85:
		return
	var before := observe_time
	observe_time += delta
	if before < OBSERVE_FOOD_AT and observe_time >= OBSERVE_FOOD_AT:
		knows_food = true
		EventBus.message.emit("Você observou: %s gosta de %s." % [data.display_name, data.favorite_food.display_name])
		_update_label()
	if before < OBSERVE_BIOME_AT and observe_time >= OBSERVE_BIOME_AT:
		knows_biome = true
		EventBus.message.emit("Você observou: %s prefere %s." % [data.display_name, "a floresta" if data.favorite_biome == &"forest" else "a planície"])
		_update_label()


func _regen(delta: float, flying_fast: bool) -> void:
	if flying_fast:
		return
	var rate := data.stamina_regen * (1.6 if not _flying else 1.0) * (0.5 if exhausted else 1.0)
	stamina = minf(stamina + rate * delta, data.max_stamina)
	if exhausted and stamina >= data.max_stamina * 0.6:
		exhausted = false


func _ground_y() -> float:
	return height_fn.call(global_position.x, global_position.z)


func _apply_ground() -> void:
	var g := _ground_y()
	if global_position.y < g:
		global_position.y = g
	_flying = global_position.y > g + 0.3


func _enter_perch() -> void:
	state = State.PERCH
	_timer = randf_range(4.0, 8.0)
	velocity = Vector3.ZERO


func _pick_wander_point() -> void:
	var a := randf() * TAU
	var p := _home + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 18.0)
	_target = Vector3(p.x, height_fn.call(p.x, p.z) + randf_range(3.5, 8.0), p.z)


func _fly_to(point: Vector3, speed: float, delta: float, accel := 4.0) -> void:
	var d := point - global_position
	var dir := d.normalized() if d.length() > 0.05 else Vector3.ZERO
	velocity = velocity.lerp(dir * speed, 1.0 - exp(-accel * delta))
	global_position += velocity * delta
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-6.0 * delta))


func _do_perch(delta: float) -> void:
	velocity = Vector3.ZERO
	if global_position.y > _ground_y() + 0.1:
		global_position.y = move_toward(global_position.y, _ground_y(), 4.0 * delta)
	_timer -= delta
	if _player != null and level == 0 and global_position.distance_to(_player.global_position) < FLEE_DISTANCE:
		_start_flee()
	elif level >= 2 and _player != null and global_position.distance_to(_player.global_position) > 6.0:
		state = State.FOLLOW
	elif _timer <= 0.0:
		state = State.WANDER
		_pick_wander_point()


func _do_wander(delta: float) -> void:
	_fly_to(_target, data.fly_speed * 0.55, delta)
	if _player != null and level == 0 and global_position.distance_to(_player.global_position) < FLEE_DISTANCE:
		_start_flee()
		return
	if level >= 2 and _player != null and global_position.distance_to(_player.global_position) > 10.0:
		state = State.FOLLOW
		return
	if global_position.distance_to(_target) < 1.0:
		if randf() < 0.5:
			_target.y = _ground_y()
			state = State.PERCH
			_timer = randf_range(4.0, 8.0)
		else:
			_pick_wander_point()


func _start_flee() -> void:
	state = State.FLEE
	_timer = 3.0
	var away := global_position - _player.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.RIGHT
	var p := global_position + away * 28.0
	_target = Vector3(p.x, height_fn.call(p.x, p.z) + 7.0, p.z)
	_home = Vector3(p.x, 0, p.z)


func _do_flee(delta: float) -> void:
	_fly_to(_target, data.fly_speed * 1.2, delta, 3.0)
	_timer -= delta
	if _timer <= 0.0 or global_position.distance_to(_target) < 2.0:
		_enter_perch()


func _do_follow(delta: float) -> void:
	if _player == null:
		return
	if (_player.global_position - _last_player_pos).length() < 0.02:
		_player_idle += delta
	else:
		_player_idle = 0.0
	_last_player_pos = _player.global_position
	var dist := global_position.distance_to(_player.global_position)
	if level < 2:
		_enter_perch()
		return
	if _player_idle > 3.0 and dist < 8.0:
		# Pousa ao lado do jogador.
		var spot := _player.global_position + _player.global_basis.x * 2.2
		spot.y = height_fn.call(spot.x, spot.z)
		_fly_to(spot, data.fly_speed * 0.6, delta)
		return
	var hover := _player.global_position + Vector3(2.0, 2.4, 2.0)
	hover.y = maxf(hover.y, height_fn.call(hover.x, hover.z) + 2.0)
	var speed := data.fast_speed if dist > 18.0 else data.fly_speed
	if dist > 3.5:
		_fly_to(hover, speed, delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-4.0 * delta))


func _do_mounted(delta: float) -> void:
	var inp := Vector2.ZERO
	var up := 0.0
	var fast := false
	if not Game.is_ui_open():
		inp = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		up = Input.get_axis(&"crouch", &"jump")
		fast = Input.is_action_pressed(&"sprint")
	var pivot := rider.get_node("CameraPivot") as Node3D
	var b := pivot.global_basis
	var dir := b.x * inp.x + b.z * inp.y
	dir.y = 0.0
	dir = dir.normalized() * minf(inp.length(), 1.0)
	var on_ground := global_position.y <= _ground_y() + 0.35
	var speed := data.fly_speed
	if fast and stamina > 0.0 and not exhausted and dir != Vector3.ZERO:
		speed = data.fast_speed
		stamina = maxf(stamina - data.stamina_drain * delta, 0.0)
		if stamina <= 0.0:
			exhausted = true
			EventBus.message.emit("Estamina acabou! %s começa a planar." % data.display_name)
	else:
		_regen(delta, false)
	var target := dir * speed
	var vy := up * 6.0
	if exhausted:
		# Sem estamina: não sobe e vai perdendo altitude; no chão não consegue decolar.
		vy = minf(vy, 0.0) if not on_ground else 0.0
		if not on_ground:
			vy = minf(vy, -3.0)
		target *= 0.6
	elif on_ground and up <= 0.0:
		vy = 0.0
	velocity.x = lerpf(velocity.x, target.x, 1.0 - exp(-5.0 * delta))
	velocity.z = lerpf(velocity.z, target.z, 1.0 - exp(-5.0 * delta))
	velocity.y = lerpf(velocity.y, vy, 1.0 - exp(-5.0 * delta))
	global_position += velocity * delta
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.8:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-5.0 * delta))
	# O jogador acompanha a sela.
	rider.global_position = seat.global_position - Vector3(0, 0.15, 0)
	rider.velocity = Vector3.ZERO
	rider.face_direction(-global_basis.z)
	rider.set_mounted_pose()
	EventBus.pet_stamina_changed.emit(stamina, data.max_stamina)


func _animate(delta: float) -> void:
	_flap += delta * (11.0 if _flying else 2.0)
	var amp := 0.7 if _flying else 0.08
	for i in _wings.size():
		var sx := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = sin(_flap) * amp * -sx - (0.0 if _flying else 0.9 * sx * -1.0)
	_body.rotation.x = clampf(-velocity.y * 0.04, -0.4, 0.4)
	if _label != null:
		_label.visible = state != State.MOUNTED and global_position.distance_to(_player.global_position) < 25.0 if _player != null else true
