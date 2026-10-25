class_name Player
extends CharacterBody3D
## Personagem em terceira pessoa: andar, correr, agachar e pular.

@export_group("Movimento")
@export var walk_speed := 2.0
@export var run_speed := 5.0
@export var crouch_speed := 1.2
@export var acceleration := 12.0
@export var air_acceleration := 3.0
@export var jump_velocity := 6.5
@export var coyote_time := 0.12
@export_group("Câmera")
@export var camera_pitch_limits := Vector2(-70.0, 35.0)

## Velocidade (m/s) em que cada ciclo de animação foi feito no Blender.
## O speed_scale da animação é velocidade_real / valor_abaixo, para os pés não deslizarem.
const ANIM_SPEED := {&"walk": 1.8, &"run": 4.5, &"crouch_walk": 1.0}

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var crouching := false
var frozen := false  ## Verdadeiro até o chão carregar sob o jogador.

var inventory := Inventory.new()
var selected_slot := 0

var _coyote := 0.0
var _jumping := false

@onready var _model: CharacterModel = $Model
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _pivot: Node3D = $CameraPivot
@onready var _arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(&"player")
	_arm.add_excluded_object(get_rid())
	_set_crouch(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var interaction := PlayerInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	if Game.debug_starter_kit:
		for id in [&"wooden_axe", &"wooden_pickaxe"]:
			inventory.add(Database.item(id))
	EventBus.player_spawned.emit(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_pivot.rotate_y(-event.relative.x * Game.mouse_sensitivity)
		_arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * Game.mouse_sensitivity,
				deg_to_rad(camera_pitch_limits.x), deg_to_rad(camera_pitch_limits.y))
	elif event is InputEventMouseButton and event.pressed and not Game.is_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"ui_cancel") and not Game.is_ui_open():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if frozen:
		return
	var input := Vector2.ZERO
	if not Game.is_ui_open():
		input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var dir := _camera_relative(input)

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
