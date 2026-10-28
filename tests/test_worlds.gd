extends Node
## Menu de mundos: criar, listar, excluir; ao sair e voltar para um mundo, tudo está como foi salvo
## (posição, inventário, construções, árvore cortada, item no chão, pet com alforje, objetivos,
## câmera); e um mundo não vaza para outro.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func open_world() -> Node:
	var w: Node = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	var t0 := Time.get_ticks_msec()
	while (w.player.frozen or Game.loading_world) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	return w


func close_world(w: Node) -> void:
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Game.reset_world_state()


func _ready() -> void:
	check(Worlds.root == "user://worlds_test/", "nos testes os mundos ficam em outra pasta")
	for w in Worlds.list():
		Worlds.delete(w["id"])

	# --- criar e listar
	var a := Worlds.create("Meu Mundo", "777")
	var b := Worlds.create("", "")
	check(int(a["seed"]) == 777 and a["name"] == "Meu Mundo", "cria mundo com nome e seed escolhidos")
	check(String(b["name"]).begins_with("Mundo") and int(b["seed"]) >= 0, "sem nome/seed: nome padrão e seed sorteada")
	check(Worlds.list().size() == 2 and not a["has_save"], "lista os 2 mundos, ainda sem save")

	# --- jogar no mundo A e mudar várias coisas
	check(Game.prepare_world(a["id"]) and Game.world_seed == 777 and not Game.loading_world, "entrar no mundo A (novo)")
	var w: Node = await open_world()
	var p: Player = w.player
	p.inventory.clear()
	p.inventory.add(Database.item(&"stone"), 17)
	p.inventory.add(Database.item(&"wood"), 30)
	var h: float = w.chunks.height_at(20, 30)
	p.global_position = Vector3(20, h + 0.5, 30)
	(p.get_node("CameraPivot") as Node3D).global_rotation.y = 1.25
	await get_tree().create_timer(0.5).timeout
	var b_sys: BuildSystem = w.build
	b_sys.place(b_sys.pieces_data[0], b_sys.compute_target(Vector3(28, w.chunks.height_at(28, 28), 28), 0))
	# Corta uma árvore.
	var cut_key := ""
	for c: Chunk in w.chunks._chunks.values():
		for f in c.fields:
			if f.data.mesh_id == &"tree" and cut_key == "":
				f.damage_instance(0, 1000.0, false)
				cut_key = f.key
	ItemPickup.spawn(w, p.global_position + Vector3(9, 0.5, 0), Database.item(&"berries"), 3)  # longe, para não ser coletado
	var pet: FlyingPet = w.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + Vector3(4, 0, 0))
	pet.add_trust(100.0)
	pet.saddled = true
	pet.bag.add(Database.item(&"stone"), 5)
	w.goals.maneuvers[&"dive"] = true
	w.goals.complete(&"wood")
	await get_tree().physics_frame
	var pos := p.global_position
	var pieces := get_tree().get_nodes_in_group(&"build_piece").size()
	check(w.save_game() and Worlds.has_save(a["id"]), "salvou no mundo A")
	await close_world(w)
	check(WorldState.resource_states.is_empty() and Game.stables.is_empty(), "ao sair, o estado do mundo é limpo")

	# --- mundo B (novo) não herda nada do A
	await get_tree().create_timer(1.1).timeout  # "jogado em" com segundos diferentes
	Game.prepare_world(b["id"])
	w = await open_world()
	check(get_tree().get_nodes_in_group(&"build_piece").is_empty(), "mundo novo não tem as construções do outro")
	check(w.player.inventory.count_of(Database.item(&"stone")) != 17, "mundo novo não tem o inventário do outro")
	await close_world(w)

	# --- volta ao mundo A: tudo como foi salvo
	await get_tree().create_timer(1.1).timeout
	check(Game.prepare_world(a["id"]) and Game.loading_world, "entrar no mundo A de novo (com save)")
	w = await open_world()
	p = w.player
	check(p.global_position.distance_to(pos) < 1.5, "posição restaurada (%.1f m do salvo)" % p.global_position.distance_to(pos))
	check(p.inventory.count_of(Database.item(&"stone")) == 17 and p.inventory.count_of(Database.item(&"wood")) >= 25, "inventário restaurado")
	check(get_tree().get_nodes_in_group(&"build_piece").size() == pieces and pieces > 0, "construção restaurada (%d peça)" % pieces)
	var cut_ok := false
	var st: Dictionary = WorldState.resource_states.get(cut_key, {})
	if st.has(0):
		cut_ok = float(st[0][0]) <= 0.0
	check(cut_ok, "árvore cortada continua cortada")
	var berries := false
	for n in get_tree().get_nodes_in_group(&"pickup"):
		if n.item.id == &"berries" and n.count == 3:
			berries = true
	check(berries, "item largado no chão continua lá")
	var pet_back: FlyingPet = null
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if q.trust > 0.0:
			pet_back = q
	check(pet_back != null and pet_back.saddled and pet_back.bag.count_of(Database.item(&"stone")) == 5, "pet restaurado (selado, com o alforje)")
	check(w.goals.is_done(&"wood") and w.goals.maneuvers.has(&"dive"), "objetivos e progresso restaurados")
	check(absf(wrapf((p.get_node("CameraPivot") as Node3D).global_rotation.y - 1.25, -PI, PI)) < 0.01, "câmera olhando para o mesmo lado")
	await close_world(w)

	# --- menu: lista os mundos e exclui
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu._list.get_child_count() == 2, "o menu mostra os 2 mundos")
	var first: Control = menu._list.get_child(0)
	check(String(first.name) == "World_" + String(a["id"]), "o mundo jogado por último aparece em cima")
	menu.ask_delete(String(b["id"]), String(b["name"]))
	menu._confirm.confirmed.emit()
	await get_tree().process_frame
	check(Worlds.list().size() == 1 and menu._list.get_child_count() == 1, "excluir apaga o mundo e atualiza a lista")
	menu.queue_free()
	Worlds.delete(a["id"])
	Game.current_world = ""
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
