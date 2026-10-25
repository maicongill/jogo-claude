class_name PlayerMagic
extends Node
## Mana, magias aprendidas e lançamento (botão direito).

const REGEN_DELAY := 1.5

var player: Player
var max_mana := 100.0
var mana := 100.0
var regen_per_second := 8.0
var learned: Array[StringName] = []
var selected: StringName = &""

var _cooldowns: Dictionary = {}
var _regen_wait := 0.0


func _ready() -> void:
	player = get_parent() as Player
	for id: StringName in Database.magic:
		if Database.magic[id].learned_by_default:
			learned.append(id)
	if not learned.is_empty():
		selected = learned[0]
	EventBus.mana_changed.emit(mana, max_mana)


func _process(delta: float) -> void:
	for k: StringName in _cooldowns.keys():
		_cooldowns[k] = maxf(_cooldowns[k] - delta, 0.0)
	if _regen_wait > 0.0:
		_regen_wait -= delta
	elif mana < max_mana:
		mana = minf(mana + regen_per_second * delta, max_mana)
		EventBus.mana_changed.emit(mana, max_mana)


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_ui_open() or Game.build_mode:
		return
	if event.is_action_pressed(&"secondary"):
		cast()


func knows(id: StringName) -> bool:
	return id in learned


func learn(id: StringName) -> bool:
	if knows(id) or Database.spell(id) == null:
		return false
	learned.append(id)
	if selected == &"":
		select(id)
	EventBus.spell_learned.emit(Database.spell(id))
	return true


func select(id: StringName) -> void:
	if not knows(id):
		return
	selected = id
	EventBus.spell_selected.emit(Database.spell(id))


func current() -> MagicData:
	return Database.spell(selected)


## Lança a magia selecionada. Devolve true se foi lançada.
func cast() -> bool:
	if player.stats.dead:
		return false
	var spell := current()
	if spell == null:
		EventBus.message.emit("Nenhuma magia selecionada (V abre o livro de magia).")
		return false
	if _cooldowns.get(spell.id, 0.0) > 0.0:
		return false
	if mana < spell.mana_cost:
		EventBus.message.emit("Mana insuficiente.")
		return false
	mana -= spell.mana_cost
	_regen_wait = REGEN_DELAY
	_cooldowns[spell.id] = spell.cooldown
	EventBus.mana_changed.emit(mana, max_mana)
	player.face_flat(player.camera_forward())
	player.held_visual.swing(0)
	var origin := player.global_position + Vector3(0, 1.35, 0)
	var dir := _aim_direction(origin)
	match spell.effect:
		&"fireball":
			Fireball.launch(player.get_parent(), origin + dir * 0.8, dir, 20.0, spell.damage, spell.radius, player)
		&"wind_gust":
			MagicEffects.wind_visual(player.get_parent(), origin + dir * 0.6, dir)
			MagicEffects.wind_gust(get_tree(), player.global_position, dir, 7.0, spell.damage)
		&"earth_wall":
			_cast_earth_wall(dir)
		&"tame":
			if not _cast_tame(spell):
				mana = minf(mana + spell.mana_cost, max_mana)  # sem alvo: devolve a mana
				_cooldowns[spell.id] = 0.0
				EventBus.mana_changed.emit(mana, max_mana)
				return false
		_:
			pass
	EventBus.spell_cast.emit(spell)
	return true


func _aim_direction(origin: Vector3) -> Vector3:
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + player.camera_forward() * 60.0, 1 | 4 | 8 | 16)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3 = hit["position"] if not hit.is_empty() else cam.global_position + player.camera_forward() * 60.0
	return (target - origin).normalized()


func _cast_earth_wall(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	var pos := player.global_position + flat * 4.5
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 8, 0), pos + Vector3(0, -12, 0), 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		pos = hit["position"]
	MagicEffects.earth_wall(player.get_parent(), pos, atan2(-flat.x, -flat.z))


## Magia de doma: age sobre a criatura mais bem mirada dentro do alcance.
func _cast_tame(spell: MagicData) -> bool:
	var cam := player.camera
	var best: FlyingPet = null
	var best_dot := 0.8
	for pet: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if pet.state == FlyingPet.State.DEAD:
			continue
		var d := pet.global_position + Vector3(0, 1.0, 0) - cam.global_position
		if d.length() > spell.range:
			continue
		var dot := player.camera_forward().dot(d.normalized())
		if dot > best_dot:
			best_dot = dot
			best = pet
	if best == null:
		EventBus.message.emit("Nenhuma criatura na mira.")
		return false
	var gain := best.on_tame_spell()
	EventBus.message.emit("Doma: +%d de confiança." % int(gain))
	return true
