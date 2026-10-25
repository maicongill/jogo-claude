class_name PlayerCombat
extends Node
## Ataques do jogador: espada com combo (hitbox Area3D), arco e flechas, e socos sem arma.

const COMBO_WINDOW := 0.7
const SWING_TIME := 0.38
const HIT_START := 0.08
const HIT_END := 0.28
const COMBO_DAMAGE := [1.0, 1.1, 1.7]
const COMBO_KNOCKBACK := [4.0, 4.0, 9.0]
const FIST_DAMAGE := 4.0
const BOW_COOLDOWN := 0.65
const ARROW_SPEED := 32.0

var player: Player
var combo := 0
var hitbox: Area3D

var _cooldown := 0.0
var _last_swing := -10.0
var _hit_active := false
var _hit_set: Dictionary = {}
var _swing_damage := 0.0
var _swing_knockback := 0.0
var _swing_item: ItemData
var _swing_slot := 0


func _ready() -> void:
	player = get_parent() as Player
	hitbox = Area3D.new()
	hitbox.name = "SwordHitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 4
	hitbox.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.6, 2.0)
	cs.shape = box
	hitbox.add_child(cs)
	hitbox.position = Vector3(0, 1.0, -1.1)
	# Fica sob o modelo, então gira junto com o personagem.
	player.get_node("Model").add_child.call_deferred(hitbox)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _physics_process(_delta: float) -> void:
	if not _hit_active:
		return
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group(&"enemy") and not _hit_set.has(body):
			_hit_set[body] = true
			_apply_hit(body as Enemy)


func attack(item: ItemData) -> void:
	if _cooldown > 0.0 or player.stats.dead:
		return
	if item != null and item.tool_kind == &"bow":
		_shoot(item)
	else:
		_swing(item)


func _swing(item: ItemData) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	combo = (combo + 1) % COMBO_DAMAGE.size() if now - _last_swing < COMBO_WINDOW else 0
	_last_swing = now
	_cooldown = SWING_TIME
	var base := item.damage if item != null and item.damage > 0.0 else FIST_DAMAGE
	_swing_damage = base * COMBO_DAMAGE[combo]
	_swing_knockback = COMBO_KNOCKBACK[combo]
	_swing_item = item
	_swing_slot = player.selected_slot
	_hit_set.clear()
	player.face_flat(player.camera_forward())
	player.held_visual.swing(combo)
	await get_tree().create_timer(HIT_START).timeout
	if hitbox == null or not is_instance_valid(hitbox):
		return
	hitbox.monitoring = true
	_hit_active = true
	await get_tree().create_timer(HIT_END - HIT_START).timeout
	_hit_active = false
	if is_instance_valid(hitbox):
		hitbox.monitoring = false


func _apply_hit(enemy: Enemy) -> void:
	enemy.take_damage(_swing_damage, player.global_position, _swing_knockback)
	if _swing_item != null and _swing_item.max_durability > 0:
		var s := player.inventory.get_stack(_swing_slot)
		if s != null and s.item.id == _swing_item.id:
			player.inventory.use_durability(_swing_slot, 1)


func _shoot(bow: ItemData) -> void:
	var arrow := Database.item(&"arrow")
	if not player.inventory.remove(arrow, 1):
		EventBus.message.emit("Sem flechas.")
		_cooldown = 0.3
		return
	_cooldown = BOW_COOLDOWN
	player.inventory.use_durability(player.selected_slot, 1)
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + player.camera_forward() * 80.0, 1 | 4 | 16)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target_point: Vector3 = hit["position"] if not hit.is_empty() else cam.global_position + player.camera_forward() * 80.0
	var origin := player.global_position + Vector3(0, 1.35, 0)
	var dir := (target_point - origin).normalized()
	player.face_flat(player.camera_forward())
	player.held_visual.swing(0)
	Arrow.launch(player.get_parent(), origin + dir * 0.7, dir, ARROW_SPEED, bow.damage, player)
