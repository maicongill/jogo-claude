class_name Player
extends CharacterBody3D
## Personagem em terceira pessoa: andar, correr, agachar e pular.

# Valores padrão; config/game_config.json (seção "player") sobrescreve em _apply_config().
var walk_speed := 2.0
var run_speed := 5.0
var crouch_speed := 1.2
var acceleration := 12.0
var air_acceleration := 3.0
var jump_velocity := 6.5
var coyote_time := 0.12
var dash_speed := 11.0
var dash_time := 0.22
var dash_cooldown := 0.8
var dash_invulnerable := 0.45
@export_group("Câmera")
@export var camera_pitch_limits := Vector2(-70.0, 35.0)
## Distância da câmera ao personagem (a pé e montado no pet) e quanto ela sobe quando montado.
@export var camera_distance := 3.2
## Câmera por cima do ombro: quanto ela se desloca para a direita (o personagem fica à esquerda da mira).
@export var camera_shoulder_offset := 1.1
@export var camera_distance_mounted := 5.2
@export var camera_height_mounted := 0.7

## Velocidade (m/s) em que cada ciclo de animação foi feito no Blender.
## O speed_scale da animação é velocidade_real / valor_abaixo, para os pés não deslizarem.
const ANIM_SPEED := {&"walk": 1.8, &"run": 4.5, &"crouch_walk": 1.0}

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var crouching := false
var frozen := false  ## Verdadeiro até o chão carregar sob o jogador.

var inventory: Inventory
var selected_slot := 0
var stats: PlayerStats
var combat: PlayerCombat
var magic: PlayerMagic
var held_visual: HeldItemVisual
var dodging := false
var mounted_pet: FlyingPet
var _base_fov := -1.0

var _coyote := 0.0
var _jumping := false
var _dash_time := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector3.ZERO

@onready var _model: CharacterModel = $Model
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _apply_config() -> void:
	var c := Config.section("player")
	walk_speed = c.get("walk_speed", walk_speed)
	run_speed = c.get("run_speed", run_speed)
	crouch_speed = c.get("crouch_speed", crouch_speed)
	acceleration = c.get("acceleration", acceleration)
	air_acceleration = c.get("air_acceleration", air_acceleration)
	jump_velocity = c.get("jump_velocity", jump_velocity)
	coyote_time = c.get("coyote_time", coyote_time)
	dash_speed = c.get("dash_speed", dash_speed)
	dash_time = c.get("dash_time", dash_time)
	dash_cooldown = c.get("dash_cooldown", dash_cooldown)
	dash_invulnerable = c.get("dash_invulnerable", dash_invulnerable)
	camera_distance = c.get("camera_distance", camera_distance)
	camera_shoulder_offset = c.get("camera_shoulder_offset", camera_shoulder_offset)
	camera_distance_mounted = c.get("camera_distance_mounted", camera_distance_mounted)
	camera_height_mounted = c.get("camera_height_mounted", camera_height_mounted)


func _ready() -> void:
	camera.near = 0.05
	inventory = Inventory.new(Config.i("game.inventory_size", 36))
	_apply_config()
	Config.reloaded.connect(_apply_config)
	_arm.spring_length = camera_distance
	_arm.position.x = camera_shoulder_offset
	add_to_group(&"player")
	_arm.add_excluded_object(get_rid())
	_set_crouch(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	stats = PlayerStats.new()
	stats.name = "Stats"
	add_child(stats)
	EventBus.player_died.connect(_on_died)
	var interaction := PlayerInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	magic = PlayerMagic.new()
	magic.name = "Magic"
	add_child(magic)
	held_visual = HeldItemVisual.new()
	held_visual.name = "HeldVisual"
	add_child(held_visual)
	held_visual.setup(_model)
	inventory.changed.connect(_update_held_visual)
	EventBus.hotbar_selected.connect(func(_i: int) -> void: _update_held_visual())
	_update_held_visual()
	if Game.debug_starter_kit:
		for id in [&"wooden_axe", &"wooden_pickaxe"]:
			inventory.add(Database.item(id))
	if Game.start_with_all_items and not _running_test():
		give_all_items()
	EventBus.player_spawned.emit(self)


## Montado: a câmera segue o pet com um leve atraso (suaviza os solavancos) e o campo de visão
## abre com a velocidade.
func _update_flight_camera(delta: float, on_pet: bool) -> void:
	if _base_fov < 0.0:
		_base_fov = camera.fov
	var pivot_y := (CROUCH_HEIGHT if crouching else STAND_HEIGHT) - 0.3
	var fov_target := _base_fov
	if on_pet:
		if not _pivot.top_level:
			_pivot.top_level = true
		var target := global_position + Vector3.UP * pivot_y
		var smooth := Config.f("pet.camera_follow_smooth", 9.0)
		_pivot.global_position = _pivot.global_position.lerp(target, 1.0 - exp(-smooth * delta))
		var pd := mounted_pet.data
		var t := clampf((mounted_pet.air_speed - pd.fly_speed) / maxf(pd.fast_speed * 1.45 - pd.fly_speed, 0.1), 0.0, 1.0)
		fov_target += Config.f("pet.camera_fov_boost", 14.0) * t
	elif _pivot.top_level:
		_pivot.top_level = false
		_pivot.position = Vector3(0, pivot_y, 0)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-3.0 * delta))


## Uma pilha cheia de cada item do jogo (ferramentas e armas: uma unidade).
func give_all_items() -> void:
	var ids := Database.items.keys()
	ids.sort()
	for id: StringName in ids:
		var it: ItemData = Database.items[id]
		inventory.add(it, it.stack_max if it.is_stackable() else 1)


func _running_test() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.begins_with("res://tests/")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pivot.rotate_y(-event.relative.x * Game.mouse_sensitivity)
		_arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * Game.mouse_sensitivity,
				deg_to_rad(camera_pitch_limits.x), deg_to_rad(camera_pitch_limits.y))
	elif event is InputEventMouseButton and event.pressed and not Game.is_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	# Montado, a câmera se afasta e sobe para o pet não tampar a visão.
	var on_pet := mounted_pet != null
	var k := 1.0 - exp(-4.0 * delta)
	_arm.spring_length = lerpf(_arm.spring_length, camera_distance_mounted if on_pet else camera_distance, k)
	_arm.position.y = lerpf(_arm.position.y, camera_height_mounted if on_pet else 0.0, k)
	_arm.position.x = lerpf(_arm.position.x, 0.0 if on_pet else camera_shoulder_offset, k)
	_update_flight_camera(delta, on_pet)
	# Árvores, pedras e móveis entre a câmera e o personagem ficam pontilhados.
	Visuals.set_camera_fade(camera.global_position, global_position + Vector3.UP * 1.1)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var input := Vector2.ZERO
	if not Game.is_ui_open():
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := _camera_relative(input)

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if not Game.is_ui_open() and Input.is_action_just_pressed(&"dodge"):
		start_dodge(dir)
	if _dash_time > 0.0:
		_dash_time -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		dodging = _dash_time > 0.0
		_model.play(&"run", 1.6)
		return

	_update_crouch()
	var speed := crouch_speed if crouching else (run_speed if Input.is_action_pressed(&"sprint") and not Game.is_ui_open() else walk_speed)
	var target := dir * speed
	var accel := acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).lerp(target, 1.0 - exp(-accel * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if is_on_floor():
		_coyote = coyote_time
		_jumping = false
	else:
		_coyote -= delta
		velocity.y -= gravity * delta

	if not Game.is_ui_open() and Input.is_action_just_pressed(&"jump") and _coyote > 0.0 and not crouching:
		velocity.y = jump_velocity
		_coyote = 0.0
		_jumping = true

	if dir != Vector3.ZERO:
		var target_yaw := atan2(-dir.x, -dir.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	move_and_slide()
	_update_animation()


func start_dodge(dir: Vector3) -> void:
	if _dash_cooldown > 0.0 or stats.dead or not is_on_floor():
		return
	_dash_dir = dir if dir != Vector3.ZERO else Vector3(-sin(_model.rotation.y), 0, -cos(_model.rotation.y))
	_dash_dir = _dash_dir.normalized()
	_dash_time = dash_time
	_dash_cooldown = dash_cooldown
	dodging = true
	stats.invulnerable_time = dash_invulnerable
	face_direction(_dash_dir)


## Dano recebido de um inimigo (com recuo). Quando montado, o marco 9 redireciona para o pet.
func take_hit(amount: float, from_pos: Vector3, knockback := 6.0) -> void:
	if mounted_pet != null:
		mounted_pet.take_damage(amount, from_pos, knockback)  # o pet leva o golpe no lugar do cavaleiro
		EventBus.player_hurt.emit(amount * 0.5)
		return
	if stats.hurt(amount, &"inimigo"):
		var away := global_position - from_pos
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.BACK
		velocity = away * knockback + Vector3(0, 3.0, 0)


func set_collision_enabled(on: bool) -> void:
	_shape.disabled = not on


func set_mounted_pose() -> void:
	_model.play(&"crouch")


func face_flat(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length() > 0.01:
		face_direction(dir.normalized())


func _update_held_visual() -> void:
	held_visual.show_item(held_item())


func _on_died() -> void:
	frozen = true
	velocity = Vector3.ZERO
	if Game.lose_items_on_death:
		inventory.clear()
		EventBus.message.emit("Você morreu e perdeu seus itens.")
	else:
		EventBus.message.emit("Você morreu.")
	await get_tree().create_timer(Config.f("survival.respawn_delay", 2.5)).timeout
	respawn()


func respawn() -> void:
	global_position = Game.spawn_point if Game.spawn_point != Vector3.INF else Game.default_spawn
	velocity = Vector3.ZERO
	stats.revive()
	frozen = false
	EventBus.player_respawned.emit()


func held_stack() -> ItemStack:
	return inventory.get_stack(selected_slot)


func held_item() -> ItemData:
	var s := held_stack()
	return s.item if s != null else null


func select_slot(i: int) -> void:
	selected_slot = posmod(i, Inventory.HOTBAR_SIZE)
	EventBus.hotbar_selected.emit(selected_slot)


func face_direction(dir: Vector3) -> void:
	_model.rotation.y = atan2(-dir.x, -dir.z)


func camera_forward() -> Vector3:
	return -camera.global_basis.z


func _camera_relative(input: Vector2) -> Vector3:
	var b := _pivot.global_basis
	var dir := b.x * input.x + b.z * input.y
	dir.y = 0.0
	return dir.normalized() * minf(input.length(), 1.0)


func _update_crouch() -> void:
	var want := Input.is_action_pressed(&"crouch") and not Game.is_ui_open()
	if want == crouching:
		return
	if not want and test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT + 0.05)):
		return  # Sem espaço para levantar.
	_set_crouch(want)


func _set_crouch(value: bool) -> void:
	crouching = value
	var h := CROUCH_HEIGHT if value else STAND_HEIGHT
	(_shape.shape as CapsuleShape3D).height = h
	_shape.position.y = h * 0.5
	_pivot.position.y = h - 0.3


func _update_animation() -> void:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		if _jumping and velocity.y > 0.5:
			_model.play(&"jump")
		else:
			_model.play(&"fall")
		return
	if crouching:
		if h_speed > 0.15:
			_model.play(&"crouch_walk", clampf(h_speed / ANIM_SPEED[&"crouch_walk"], 0.5, 1.6))
		else:
			_model.play(&"crouch")
	elif h_speed > 0.15:
		var key: StringName = &"run" if h_speed > (walk_speed + run_speed) * 0.5 else &"walk"
		_model.play(key, clampf(h_speed / ANIM_SPEED[key], 0.5, 1.6))
	else:
		_model.play(&"idle")
