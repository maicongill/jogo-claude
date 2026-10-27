class_name PlayerCombat
extends Node
## Ataques do jogador: espada com combo (hitbox Area3D), arco e flechas, e socos sem arma.
## Segurar o ataque carrega: espada -> golpe carregado; arco -> tiro mais forte e rápido.
## Golpe de espada no ar (pulando/caindo) é crítico.

const HIT_START := 0.08
const HIT_END := 0.28

# Padrões; sobrescritos por config/game_config.json (seção "combat").
var combo_window := 0.7
var swing_time := 0.38
var combo_damage: Array = [1.0, 1.1, 1.7]
var combo_knockback: Array = [4.0, 4.0, 9.0]
var fist_damage := 4.0
var bow_cooldown := 0.65
var arrow_speed := 32.0
var sword_charge_time := 0.55
var charged_damage := 2.2
var charged_knockback := 12.0
var air_crit_multiplier := 1.5
var bow_charge_time := 1.0
var bow_min_power := 0.35
var bow_full_bonus := 1.4

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
var _swing_crit := false
var _swing_heavy := false
## Carga em andamento (botão de ataque segurado com espada ou arco).
var _charging := false
var _charge_item: ItemData
var _charge_start := 0.0


func apply_config() -> void:
	var c := Config.section("combat")
	combo_window = c.get("combo_window", combo_window)
	swing_time = c.get("swing_time", swing_time)
	combo_damage = c.get("combo_damage", combo_damage)
	combo_knockback = c.get("combo_knockback", combo_knockback)
	fist_damage = c.get("fist_damage", fist_damage)
	bow_cooldown = c.get("bow_cooldown", bow_cooldown)
	arrow_speed = c.get("arrow_speed", arrow_speed)
	sword_charge_time = c.get("sword_charge_time", sword_charge_time)
	charged_damage = c.get("charged_damage", charged_damage)
	charged_knockback = c.get("charged_knockback", charged_knockback)
	air_crit_multiplier = c.get("air_crit_multiplier", air_crit_multiplier)
	bow_charge_time = c.get("bow_charge_time", bow_charge_time)
	bow_min_power = c.get("bow_min_power", bow_min_power)
	bow_full_bonus = c.get("bow_full_bonus", bow_full_bonus)


func _ready() -> void:
	player = get_parent() as Player
	apply_config()
	Config.reloaded.connect(apply_config)
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
	if _charging and (Game.is_ui_open() or player.stats.dead or player.held_item() != _charge_item):
		_charging = false  # trocou de item, abriu menu ou morreu: cancela a carga


## Começa a carregar (botão de ataque apertado com espada ou arco).
func begin_charge(item: ItemData) -> void:
	if _cooldown > 0.0 or player.stats.dead or _charging:
		return
	_charging = true
	_charge_item = item
	_charge_start = Time.get_ticks_msec() / 1000.0


## Botão solto: golpe normal (clique rápido) ou carregado.
func release_charge() -> void:
	if not _charging:
		return
	_charging = false
	var held_for := Time.get_ticks_msec() / 1000.0 - _charge_start
	if _charge_item != null and _charge_item.tool_kind == &"bow":
		_shoot(_charge_item, clampf(held_for / bow_charge_time, 0.0, 1.0))
	else:
		_swing(_charge_item, held_for >= sword_charge_time)


## 0 a 1: quanto da carga já foi feito (para o indicador na tela). -1 = não está carregando.
func charge_ratio() -> float:
	if not _charging:
		return -1.0
	var held_for := Time.get_ticks_msec() / 1000.0 - _charge_start
	var full := bow_charge_time if _charge_item != null and _charge_item.tool_kind == &"bow" else sword_charge_time
	return clampf(held_for / full, 0.0, 1.0)


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


func _swing(item: ItemData, heavy := false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	combo = (combo + 1) % combo_damage.size() if now - _last_swing < combo_window else 0
	_last_swing = now
	_cooldown = swing_time
	var base := item.damage if item != null and item.damage > 0.0 else fist_damage
	_swing_damage = base * combo_damage[combo]
	_swing_knockback = combo_knockback[combo]
	_swing_heavy = heavy
	if heavy:
		combo = 2  # o golpe carregado fecha o combo
		_swing_damage = base * charged_damage
		_swing_knockback = charged_knockback
		_cooldown = swing_time * 1.4
	# Crítico: golpe de espada no ar (pulando ou caindo), a pé.
	_swing_crit = item != null and item.tool_kind == &"sword" and not player.is_on_floor() and player.mounted_pet == null
	if _swing_crit:
		_swing_damage *= air_crit_multiplier
	_swing_item = item
	_swing_slot = player.selected_slot
	_hit_set.clear()
	player.face_flat(player.camera_forward())
	player.held_visual.swing(combo)
	if heavy:
		EventBus.message.emit("Golpe carregado!")
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
	if _swing_crit:
		enemy.popup("Crítico!", Color(1, 0.85, 0.2))
	elif _swing_heavy:
		enemy.popup("Forte!", Color(1, 0.55, 0.25))
	if _swing_item != null and _swing_item.max_durability > 0:
		var s := player.inventory.get_stack(_swing_slot)
		if s != null and s.item.id == _swing_item.id:
			player.inventory.use_durability(_swing_slot, 1)


## power: 0 (clique rápido) a 1 (carga cheia = tiro carregado, mais dano e alcance).
func _shoot(bow: ItemData, power := 1.0) -> void:
	var arrow := Database.item(&"arrow")
	if not player.inventory.remove(arrow, 1):
		EventBus.message.emit("Sem flechas.")
		_cooldown = 0.3
		return
	_cooldown = bow_cooldown
	player.inventory.use_durability(player.selected_slot, 1)
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + player.camera_forward() * 80.0, 1 | 4 | 8 | 16)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target_point: Vector3 = hit["position"] if not hit.is_empty() else cam.global_position + player.camera_forward() * 80.0
	var origin := player.global_position + Vector3(0, 1.35, 0)
	var dir := (target_point - origin).normalized()
	player.face_flat(player.camera_forward())
	player.held_visual.swing(0)
	var mult := lerpf(bow_min_power, 1.0, power)
	var dmg := bow.damage * mult * (bow_full_bonus if power >= 1.0 else 1.0)
	var arrow_node := Arrow.launch(player.get_parent(), origin + dir * 0.7, dir, arrow_speed * lerpf(0.7, 1.0, power), dmg, player)
	if power >= 1.0:
		arrow_node.knockback = 8.0
		arrow_node.charged = true
