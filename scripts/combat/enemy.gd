class_name Enemy
extends CharacterBody3D
## Musgolho: criatura da floresta. Fica parada ou patrulha, persegue quando vê o jogador
## e ataca corpo a corpo (movimento por steering simples).

signal died(enemy: Enemy)

enum State { IDLE, PATROL, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

@export var max_health := 40.0
@export var chase_speed := 3.6
@export var patrol_speed := 1.3
@export var sight_range := 14.0
@export var lose_range := 24.0
@export var attack_range := 1.9
@export var attack_damage := 12.0
@export var windup_time := 0.55
@export var attack_cooldown := 1.4
@export var attack_knockback := 7.0

var health := 40.0
var state: State = State.IDLE
var spawn_key := ""

var _target: Player
var _timer := 0.0
var _patrol_point := Vector3.ZERO
var _home := Vector3.ZERO
var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
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

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.32, 0.55, 0.28)
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
		eye.material_override = MaterialFactory.solid(Color(0.97, 0.95, 0.5))
		add_child(eye)
		var horn := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.0
		hm.bottom_radius = 0.07
		hm.height = 0.3
		horn.mesh = hm
		horn.position = Vector3(0.25 * sx, 1.05, -0.1)
		horn.rotation.z = -0.35 * sx
		horn.material_override = MaterialFactory.solid(Color(0.85, 0.8, 0.6))
		add_child(horn)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 1.6
	_label.font_size = 36
	_label.outline_size = 8
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)
	_pick_idle()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_timer -= delta
	_find_target()
	match state:
		State.IDLE:
			_move_towards(global_position, 0.0, delta)
			if _target and _dist_to_target() < sight_range:
				state = State.CHASE
			elif _timer <= 0.0:
				_start_patrol()
		State.PATROL:
			_move_towards(_patrol_point, patrol_speed, delta)
			if _target and _dist_to_target() < sight_range:
				state = State.CHASE
			elif _flat_dist(_patrol_point) < 0.6 or _timer <= 0.0:
				_pick_idle()
		State.CHASE:
			if _target == null or _target.stats.dead or _dist_to_target() > lose_range:
				_pick_idle()
			elif _dist_to_target() <= attack_range:
				state = State.WINDUP
				_timer = windup_time
				_mat.albedo_color = Color(0.85, 0.25, 0.2)
			else:
				_move_towards(_target.global_position, chase_speed, delta)
		State.WINDUP:
			_move_towards(global_position, 0.0, delta)
			_face(_target.global_position)
			_body.scale = Vector3.ONE * (1.0 + 0.25 * (1.0 - _timer / windup_time))
			if _timer <= 0.0:
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
	move_and_slide()


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
	_timer = 6.0
	var a := randf() * TAU
	_patrol_point = _home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 6.0)


func _strike() -> void:
	_body.scale = Vector3.ONE
	_mat.albedo_color = Color(0.32, 0.55, 0.28)
	if _target and _flat_dist(_target.global_position) <= attack_range + 0.7 and absf(_target.global_position.y - global_position.y) < 2.0:
		_target.take_hit(attack_damage, global_position, attack_knockback)
	state = State.RECOVER
	_timer = attack_cooldown


func take_damage(amount: float, from_pos: Vector3, knockback := 6.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	_label.text = "Musgolho  %d/%d" % [maxi(ceili(health), 0), int(max_health)]
	_label.visible = true
	var away := global_position - from_pos
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	velocity = away * knockback + Vector3(0, 2.5, 0)
	_body.scale = Vector3.ONE
	_mat.albedo_color = Color(1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(0.1)
	tw.tween_callback(func() -> void: _mat.albedo_color = Color(0.32, 0.55, 0.28))
	if health <= 0.0:
		_die()
		return
	state = State.STAGGER
	_timer = 0.35


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
