extends Node
## Marco 10: a meta do protótipo, jogada de ponta a ponta pelas mesmas regras do jogo
## (coletar, craftar, construir, aprender magia, domar, voar e derrotar um inimigo), mais salvar/carregar.

var failures := 0
var main: Node
var p: Player
var inter: PlayerInteraction


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var hint := [""]
	EventBus.hint_requested.connect(func(t: String) -> void: hint[0] = t)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	p = main.player
	inter = p.get_node("Interaction")
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	main.spawner.queue_free()
	check(hint[0].contains("Bem-vindo") and hint[0].contains("madeira"), "a dica inicial explica o primeiro passo")
	check(main.goals.done.is_empty(), "nenhum objetivo concluído no início")
	await _playthrough()
	await _save_load()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- ajudantes

func _item(id: StringName) -> ItemData:
	return Database.item(id)


func _count(id: StringName) -> int:
	return p.inventory.count_of(_item(id))


func _recipe(id: StringName) -> RecipeData:
	for r in Database.recipes:
		if r.id == id:
			return r
	return null


func _select(id: StringName) -> void:
	for i in Inventory.HOTBAR_SIZE:
		var s := p.inventory.get_stack(i)
		if s != null and s.item.id == id:
			p.select_slot(i)
			return
	for i in range(Inventory.HOTBAR_SIZE, p.inventory.size()):
		var s := p.inventory.get_stack(i)
		if s != null and s.item.id == id:
			p.inventory.slots[8] = s
			p.inventory.slots[i] = null
			p.inventory.changed.emit()
			p.select_slot(8)
			return


func _select_empty() -> void:
	for i in Inventory.HOTBAR_SIZE:
		if p.inventory.get_stack(i) == null:
			p.select_slot(i)
			return


func _find(id: StringName) -> Array:
	var best: Array = []
	var best_d := 1e9
	for chunk: Chunk in main.chunks._chunks.values():
		for f in chunk.fields:
			if f.data.id != id:
				continue
			for i in f._xforms.size():
				if f.is_alive(i) and f.world_position_of(i).distance_to(p.global_position) < best_d:
					best_d = f.world_position_of(i).distance_to(p.global_position)
					best = [f, i]
	return best


func _aim_at(target: Vector3, from_dist: float) -> bool:
	var flat := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z).normalized()
	p.global_position = Vector3(target.x, 0, target.z) - flat * from_dist
	p.global_position.y = main.chunks.height_at(p.global_position.x, p.global_position.z) + 0.2
	p.velocity = Vector3.ZERO
	var pivot := p.get_node("CameraPivot") as Node3D
	pivot.rotation.y = atan2(-flat.x, -flat.z)
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	# A câmera fica por cima do ombro (deslocada para a direita): mira a partir dela, não do personagem.
	for deg in range(-30, 36, 3):
		arm.rotation.x = deg_to_rad(deg)
		for _k in 3:
			var to := target - p.camera.global_position
			pivot.rotation.y = atan2(-to.x, -to.z)
			await get_tree().physics_frame
		var hit := inter.aim_ray()
		if not hit.is_empty() and hit["collider"].has_method("damage_shape") and hit["position"].distance_to(target) < 2.5:
			return true
	return false


## Inimigo parado (sem IA) para os golpes finais da meta.
func _foe(type_id: StringName, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.type_id = type_id
	main.add_child(e)
	pos.y = main.chunks.height_at(pos.x, pos.z) + 0.3
	e.global_position = pos
	e.sight_range = 0.0
	e.set_physics_process(false)
	return e


## Aponta a câmera (que fica por cima do ombro) para o meio do inimigo.
func _aim_enemy(e: Enemy) -> void:
	if not is_instance_valid(e):
		return
	var pivot := p.get_node("CameraPivot") as Node3D
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	for _k in 3:
		var to := e.global_position + Vector3(0, 0.6 * e.body_scale, 0) - p.camera.global_position
		pivot.rotation.y = atan2(-to.x, -to.z)
		arm.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		await get_tree().physics_frame


## Vai até o recurso mais próximo e bate até acabar (ou até desistir).
func _harvest(id: StringName, height: float, dist: float) -> bool:
	var t := _find(id)
	if t.is_empty():
		return false
	var f: ResourceField = t[0]
	if not await _aim_at(f.world_position_of(t[1]) + Vector3(0, height, 0), dist):
		return false
	for i in 14:
		inter._cooldown = 0.0
		inter.primary_action()
		if not f.is_alive(t[1]):
			break
	return not f.is_alive(t[1])


func _pet_aim(pet: FlyingPet, dist := 10.5) -> void:
	var base := pet.global_position
	var from := base + Vector3(dist, 0, 0)
	from.y = main.chunks.height_at(from.x, from.z) + 0.3
	p.global_position = from
	p.velocity = Vector3.ZERO
	var flat := Vector3(base.x - from.x, 0, base.z - from.z).normalized()
	(p.get_node("CameraPivot") as Node3D).rotation.y = atan2(-flat.x, -flat.z)
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	var best := 0.0
	var best_dot := -1.0
	for deg in range(-40, 40, 2):
		arm.rotation.x = deg_to_rad(deg)
		await get_tree().physics_frame
		var dd := (pet.global_position + Vector3(0, 1.0, 0) - p.camera.global_position).normalized()
		if p.camera_forward().dot(dd) > best_dot:
			best_dot = p.camera_forward().dot(dd)
			best = deg
	arm.rotation.x = deg_to_rad(best)
	await get_tree().physics_frame


# ---------------------------------------------------------------- a meta

func _playthrough() -> void:
	var t0 := Time.get_ticks_msec()
	# 1) Madeira com as mãos, depois com o machado.
	_select_empty()
	var tries := 0
	while _count(&"wood") < 8 and tries < 12:
		await _harvest(&"tree", 1.2, 2.4)
		tries += 1
	check(main.goals.is_done(&"wood"), "objetivo: coletar madeira (%d)" % _count(&"wood"))
	check(Crafting.craft(p.inventory, _recipe(&"wooden_pickaxe")), "craftou a picareta de madeira")
	check(main.goals.is_done(&"tool"), "objetivo: fazer uma ferramenta")
	Crafting.craft(p.inventory, _recipe(&"wooden_axe"))
	# 2) Pedra com a picareta
	_select(&"wooden_pickaxe")
	tries = 0
	while _count(&"stone") < 16 and tries < 14:
		await _harvest(&"rock", 0.5, 2.6)
		tries += 1
	check(main.goals.is_done(&"stone"), "objetivo: coletar pedra (%d)" % _count(&"stone"))
	# Mais madeira para tudo o que vem a seguir.
	_select(&"wooden_axe")
	tries = 0
	while _count(&"wood") < 55 and tries < 40:
		await _harvest(&"tree", 1.2, 2.4)
		tries += 1
	print("    madeira %d, pedra %d, frutinhas %d" % [_count(&"wood"), _count(&"stone"), _count(&"berries")])
	# Frutinhas de um arbusto (comida favorita do pet)
	_select_empty()
	await _harvest(&"bush", 0.6, 2.2)
	check(_count(&"berries") >= 2, "colheu frutinhas (%d)" % _count(&"berries"))

	# 3) Casa pequena
	p.global_position = Vector3(8, main.chunks.height_at(8, 8) + 0.3, 8)
	var b: BuildSystem = main.build
	var fh: float = main.chunks.height_at(16, 16)
	var floor_piece := b.place(b.pieces_data[0], b.compute_target(Vector3(16, fh, 16), 0))
	var fp := floor_piece.global_position
	var edges := [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]
	# Duas janelas, uma parede e uma porta nas bordas; telhado em cima.
	var window_idx := 5
	for i in 4:
		var idx: int = [window_idx, window_idx, 1, 2][i]
		var t: Dictionary = b.compute_target(fp + edges[i] + Vector3(0, 1.4, 0), idx)
		if t.get("valid", false):
			b.place(b.pieces_data[idx], t)
		else:
			print("    (peça %s inválida: %s)" % [b.pieces_data[idx].id, t.get("reason", "")])
	b.place(b.pieces_data[3], b.compute_target(fp + Vector3(0, 3.2, 0), 3))
	check(main.goals.is_done(&"house"), "objetivo: construir uma casa com porta e janelas")

	# 5) Pet: observar, domar, selar
	Crafting.craft(p.inventory, _recipe(&"saddle"))
	var pet: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], Vector3(30, main.chunks.height_at(30, 10), 10))
	pet._timer = 100000.0
	await _pet_aim(pet)
	await get_tree().create_timer(6.5).timeout
	check(pet.knows_food and pet.knows_biome, "observou as preferências do pet")
	_select(&"berries")
	pet.interact(p)
	p.magic.select(&"tame")
	var casts := 0
	while pet.level < 3 and casts < 30:
		p.magic._cooldowns.clear()
		p.magic.mana = 100.0
		p.magic.cast()
		casts += 1
	check(pet.level == 3 and main.goals.is_done(&"tame"), "objetivo: domar o pet voador (%d doma(s))" % casts)
	_select(&"saddle")
	pet.state = FlyingPet.State.PERCH
	pet._timer = 100000.0
	p.global_position = pet.global_position + Vector3(2, 0, 0)
	pet.interact(p)
	check(pet.saddled, "selou o pet")
	pet.mount(p)
	# Sobe, acelera, mergulha e plana.
	Input.action_press(&"jump")
	await get_tree().create_timer(3.0).timeout
	Input.action_press(&"move_forward")
	await get_tree().create_timer(1.5).timeout
	Input.action_release(&"jump")
	Input.action_press(&"crouch")
	await get_tree().create_timer(1.5).timeout
	Input.action_release(&"crouch")
	Input.action_press(&"jump")
	await get_tree().create_timer(1.5).timeout
	Input.action_release(&"jump")
	Input.action_press(&"dodge")
	await get_tree().create_timer(2.0).timeout
	Input.action_release(&"dodge")
	check(main.goals.is_done(&"fly"), "objetivo: voar fazendo manobras (%s)" % ", ".join(main.goals.maneuvers.keys()))
	# Alforje: guarda madeira e voa uns 40 m.
	pet.bag.add(Database.item(&"wood"), 10)
	Input.action_press(&"jump")
	await get_tree().create_timer(1.0).timeout
	Input.action_release(&"jump")
	await get_tree().create_timer(5.5).timeout
	Input.action_release(&"move_forward")
	check(main.goals.is_done(&"carry"), "objetivo: carregar itens com o pet (%.0f m)" % main.goals.carried_distance)
	pet.dismount()

	# 6) Inimigos de tipos diferentes: espada (saltilho), arco (cuspidor) e magia (musgolho).
	Crafting.craft(p.inventory, _recipe(&"wooden_sword"))
	Crafting.craft(p.inventory, _recipe(&"bow"))
	Crafting.craft(p.inventory, _recipe(&"arrow"))
	Crafting.craft(p.inventory, _recipe(&"arrow"))
	await get_tree().create_timer(1.5).timeout
	p.global_position = Vector3(-10, main.chunks.height_at(-10, -10) + 0.3, -10)
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.5).timeout
	var pivot := p.get_node("CameraPivot") as Node3D
	pivot.rotation.y = 0.0
	(p.get_node("CameraPivot/SpringArm3D") as Node3D).rotation.x = deg_to_rad(-8)
	await get_tree().physics_frame
	var face := -p.camera.global_basis.z
	face.y = 0.0
	face = face.normalized()
	# Espada
	_select(&"wooden_sword")
	var s1 := _foe(&"saltilho", p.global_position + face * 1.5)
	for i in 6:
		p.combat._cooldown = 0.0
		p.combat.attack(p.held_item())
		await get_tree().create_timer(0.45).timeout
		if not is_instance_valid(s1) or s1.state == Enemy.State.DEAD:
			break
		s1.global_position = p.global_position + face * 1.5
	# Arco (mira no inimigo a 6 m)
	_select(&"bow")
	var c1 := _foe(&"cuspidor", p.global_position + face * 6.0)
	for i in 6:
		await _aim_enemy(c1)
		p.combat._cooldown = 0.0
		p.combat.attack(p.held_item())
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(c1) or c1.state == Enemy.State.DEAD:
			break
		c1.global_position = p.global_position + face * 6.0
	# Magia (rajada de vento no musgolho, com a vida já baixa)
	var m1 := _foe(&"musgolho", p.global_position + face * 3.0)
	m1.health = 8.0
	p.magic.select(&"wind_gust")
	for i in 4:
		await _aim_enemy(m1)
		p.magic._cooldowns.clear()
		p.magic.mana = p.magic.max_mana
		p.magic.cast()
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(m1) or m1.state == Enemy.State.DEAD:
			break
		m1.global_position = p.global_position + face * 3.0
	check(main.goals.is_done(&"enemy_types"), "objetivo: derrotar 2 tipos de inimigo (%s)" % ", ".join(main.goals.killed_types.keys()))
	check(main.goals.is_done(&"arsenal"), "objetivo: derrotar com espada, arco e magia (%s)" % ", ".join(main.goals.kill_sources.keys()))
	check(main.goals.all_done(), "TODOS os objetivos da meta foram cumpridos")
	print("    (jogada simulada em %.1f s de teste)" % ((Time.get_ticks_msec() - t0) / 1000.0))


# ---------------------------------------------------------------- salvar e carregar

func _save_load() -> void:
	var path := "user://test_save.json"
	var wood := _count(&"wood")
	var stone := _count(&"stone")
	var pieces := get_tree().get_nodes_in_group(&"build_piece").size()
	var learned := p.magic.learned.size()
	var pet_level := 0
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		pet_level = maxi(pet_level, q.level)
	var pos := p.global_position
	check(SaveSystem.save_to(main, path), "salvou o jogo")
	# Bagunça o estado
	p.inventory.clear()
	for n in get_tree().get_nodes_in_group(&"build_piece"):
		n.queue_free()
	p.magic.learned.clear()
	main.goals.done.clear()
	p.global_position += Vector3(50, 0, 50)
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await get_tree().create_timer(0.3).timeout
	check(get_tree().get_nodes_in_group(&"build_piece").size() == 0 and _count(&"wood") == 0, "estado bagunçado antes de carregar")
	check(SaveSystem.load_from(main, path), "carregou o jogo")
	var frames := 0
	while p.frozen and frames < 1500:
		await get_tree().process_frame
		frames += 1
	await get_tree().create_timer(0.5).timeout
	check(_count(&"wood") == wood and _count(&"stone") == stone, "inventário restaurado (madeira %d, pedra %d)" % [_count(&"wood"), _count(&"stone")])
	check(get_tree().get_nodes_in_group(&"build_piece").size() == pieces, "construções restauradas (%d peças)" % pieces)
	check(p.magic.learned.size() == learned, "magias restauradas")
	check(main.goals.all_done(), "objetivos restaurados")
	check(p.global_position.distance_to(pos) < 3.0, "posição restaurada")
	var pet_back := 0
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if q.trust > 0.0:
			pet_back = maxi(pet_back, q.level)
	check(pet_back == pet_level and pet_back == 3, "pet restaurado com a confiança (nível %d)" % pet_back)
	# Os recursos coletados continuam coletados depois do recarregamento dos chunks
	var stable_pieces := 0
	for n in get_tree().get_nodes_in_group(&"build_piece"):
		if (n as BuildPiece).stability >= BuildSystem.stab_min:
			stable_pieces += 1
	check(stable_pieces == pieces, "a casa restaurada continua estável")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
