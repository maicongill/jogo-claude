extends Node
## Marco 3: coleta, ferramentas, inventário e plantio.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	_test_inventory()
	await _test_world()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_inventory() -> void:
	var wood := Database.item(&"wood")
	var axe := Database.item(&"wooden_axe")
	var inv := Inventory.new(9)
	check(inv.add(wood, 100) == 0, "adiciona 100 madeiras (empilha em 64)")
	check(inv.get_stack(0).count == 64 and inv.get_stack(1).count == 36, "pilhas: 64 + 36")
	check(inv.count_of(wood) == 100, "conta 100 madeiras")
	check(inv.remove(wood, 70) and inv.count_of(wood) == 30, "remove 70 madeiras")
	check(not inv.remove(wood, 31), "não remove mais do que tem")
	inv.add(axe, 2)
	check(inv.count_of(axe) == 2 and inv.get_stack(1) != null, "ferramentas não empilham")
	var small := Inventory.new(2)
	check(small.add(wood, 200) == 200 - 128, "inventário cheio devolve o que não coube")
	var tool_inv := Inventory.new(3)
	tool_inv.add(axe)
	for i in 39:
		tool_inv.use_durability(0)
	check(tool_inv.get_stack(0) != null and tool_inv.get_stack(0).durability == 1, "durabilidade cai por uso")
	tool_inv.use_durability(0)
	check(tool_inv.get_stack(0) == null, "ferramenta quebra em zero")


func _find_instance(main: Node, id: StringName) -> Array:
	var best: Array = []
	var best_d := 1e9
	for chunk: Chunk in main.chunks._chunks.values():
		for f in chunk.fields:
			if f.data.id != id:
				continue
			for i in f._xforms.size():
				if not f.is_alive(i):
					continue
				var d := f.world_position_of(i).distance_to(main.player.global_position)
				if d < best_d:
					best_d = d
					best = [f, i]
	return best


func _aim_at(main: Node, target: Vector3, from_dist := 2.4) -> bool:
	var p: Player = main.player
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
		var hit: Dictionary = p.get_node("Interaction").aim_ray()
		if not hit.is_empty() and hit["collider"].has_method("damage_shape") and hit["position"].distance_to(target) < 2.5:
			return true
	return false


func _test_world() -> void:
	Game.debug_starter_kit = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var p: Player = main.player
	var inter: PlayerInteraction = p.get_node("Interaction")
	check(p.inventory.count_of(Database.item(&"wooden_axe")) == 1, "começa com o kit de teste")

	# Árvore com a mão (sem ferramenta na mão selecionada: slot 5 vazio).
	var t := _find_instance(main, &"tree")
	check(not t.is_empty(), "achou uma árvore carregada perto")
	p.select_slot(5)
	var tf: ResourceField = t[0]
	var tpos := tf.world_position_of(t[1]) + Vector3(0, 1.2, 0)
	check(await _aim_at(main, tpos), "consegue mirar na árvore")
	var wood := Database.item(&"wood")
	for i in 5:
		inter._cooldown = 0.0
		inter.primary_action()
	check(tf.is_alive(t[1]), "com a mão a árvore ainda está de pé depois de 5 golpes")
	inter._cooldown = 0.0
	inter.primary_action()
	check(not tf.is_alive(t[1]), "cai no 6º golpe de mão")
	check(p.inventory.count_of(wood) >= 2, "ganhou madeira (%d)" % p.inventory.count_of(wood))

	# Machado é mais rápido.
	var t2 := _find_instance(main, &"tree")
	p.select_slot(0)
	check(p.held_item().id == &"wooden_axe", "machado selecionado na hotbar")
	var tf2: ResourceField = t2[0]
	check(await _aim_at(main, tf2.world_position_of(t2[1]) + Vector3(0, 1.2, 0)), "mira na segunda árvore")
	for i in 3:
		inter._cooldown = 0.0
		inter.primary_action()
	check(not tf2.is_alive(t2[1]), "machado derruba em 3 golpes")
	check(p.get_node("Interaction") != null and p.inventory.get_stack(0).durability == 37, "machado perdeu durabilidade (%d)" % p.inventory.get_stack(0).durability)

	# Pedra exige picareta.
	var r := _find_instance(main, &"rock")
	check(not r.is_empty(), "achou uma pedra")
	var rf: ResourceField = r[0]
	var rpos := rf.world_position_of(r[1]) + Vector3(0, 0.5, 0)
	check(await _aim_at(main, rpos, 2.6), "mira na pedra")
	p.select_slot(5)
	inter._cooldown = 0.0
	inter.primary_action()
	check(rf.is_alive(r[1]) and p.inventory.count_of(Database.item(&"stone")) == 0, "pedra não cede à mão")
	p.select_slot(1)
	for i in 4:
		inter._cooldown = 0.0
		inter.primary_action()
	check(not rf.is_alive(r[1]) and p.inventory.count_of(Database.item(&"stone")) >= 2, "picareta quebra a pedra e dá pedra (%d)" % p.inventory.count_of(Database.item(&"stone")))

	# Arbusto de frutinhas regenera.
	var b := _find_instance(main, &"bush")
	check(not b.is_empty(), "achou um arbusto")
	var bf: ResourceField = b[0]
	check(await _aim_at(main, bf.world_position_of(b[1]) + Vector3(0, 0.6, 0), 2.2), "mira no arbusto")
	p.select_slot(5)
	inter._cooldown = 0.0
	inter.primary_action()
	check(not bf.is_alive(b[1]) and p.inventory.count_of(Database.item(&"berries")) >= 2, "colhe frutinhas (%d)" % p.inventory.count_of(Database.item(&"berries")))
	WorldState.time += 100.0
	await get_tree().create_timer(1.3).timeout
	check(bf.is_alive(b[1]), "o arbusto regenera com o tempo")

	# Estado persiste ao recarregar o chunk.
	var key := tf.key
	var again := ResourceField.new()
	main.add_child(again)
	again.setup(tf.data, key, tf._xforms)
	check(not again.is_alive(t[1]), "árvore derrubada continua derrubada depois de recarregar o chunk")
	again.queue_free()

	# Plantio (em campo aberto, longe dos recursos usados acima).
	p.global_position = Vector3(-4, main.chunks.height_at(-4, -4) + 0.3, -4)
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	var sapling := Database.item(&"sapling")
	p.inventory.add(sapling, 1)
	var before := p.inventory.count_of(sapling)
	for i in p.inventory.size():
		if p.inventory.get_stack(i) != null and p.inventory.get_stack(i).item.id == &"sapling":
			p.select_slot(i) if i < Inventory.HOTBAR_SIZE else p.inventory.set_stack(5, p.inventory.get_stack(i))
			break
	if p.held_item() == null or p.held_item().id != &"sapling":
		p.select_slot(5)
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	var planted := false
	for deg in range(0, 40, 2):
		arm.rotation.x = deg_to_rad(-deg)
		await get_tree().physics_frame
		var any_hit: Dictionary = inter.aim_ray()
		if not any_hit.is_empty() and any_hit["collider"].has_method("damage_shape"):
			continue  # há um recurso na mira; mirar no chão livre
		inter._cooldown = 0.0
		inter.primary_action()
		if get_tree().get_nodes_in_group(&"planted").size() > 0:
			planted = true
			break
	check(planted, "planta a muda no chão")
	check(p.inventory.count_of(sapling) == before - 1, "a muda saiu do inventário")
	var plant: PlantedTree = get_tree().get_nodes_in_group(&"planted")[0]
	check(not plant.grown, "a muda ainda é pequena")
	WorldState.time += 61.0
	await get_tree().create_timer(0.3).timeout
	check(plant.grown, "a muda virou árvore com o tempo")
	var res := plant.damage_shape(0, 10.0)
	check(res["depleted"] and res["drops"].size() >= 1, "a árvore plantada pode ser coletada")
