extends Node
## Fantasma dos objetos colocáveis e opção de nascer com todos os itens.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _slot_of(p: Player, id: StringName) -> int:
	for i in p.inventory.size():
		var s := p.inventory.get_stack(i)
		if s != null and s.item.id == id:
			return i
	return -1


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	check(p.inventory.count_of(Database.item(&"bed")) == 0, "nos testes o jogador não ganha o kit completo")
	p.give_all_items()
	var missing: PackedStringArray = []
	for id: StringName in Database.items:
		if p.inventory.count_of(Database.items[id]) == 0:
			missing.append(id)
	check(missing.is_empty(), "give_all_items dá todos os itens (faltando: %s)" % ", ".join(missing))
	check(p.inventory.count_of(Database.item(&"wood")) == Database.item(&"wood").stack_max, "recursos vêm em pilha cheia")

	# Olha para o chão à frente e segura a cama na hotbar.
	(p.get_node("CameraPivot/SpringArm3D") as Node3D).rotation.x = deg_to_rad(-35)
	var slot := _slot_of(p, &"bed")
	p.inventory.slots[0] = p.inventory.slots[slot]
	p.inventory.slots[slot] = null
	p.inventory.changed.emit()
	p.select_slot(0)
	var stables_before := Game.stables.size()
	for _i in 5:
		await get_tree().process_frame
	var ghost: Node3D = (p.get_node("Interaction") as PlayerInteraction)._ghost
	check(ghost != null and ghost.visible, "fantasma aparece segurando a cama")
	if ghost != null:
		check(ghost.get_groups().is_empty(), "fantasma não entra nos grupos do objeto real")
		check((ghost as CollisionObject3D).collision_layer == 0, "fantasma não tem colisão")
		check((p.get_node("Interaction") as PlayerInteraction)._ghost_mat.albedo_color.g > 0.9, "fantasma verde (lugar válido)")
		var gpos := ghost.global_position
		(p.get_node("Interaction") as PlayerInteraction).primary_action()
		await get_tree().process_frame
		var tables := get_tree().get_nodes_in_group(&"bed")
		check(tables.size() == 1 and (tables[0] as Node3D).global_position.distance_to(gpos) < 0.15, "cama é colocada onde estava o fantasma")
	# Estábulo fantasma não registra ponto de renascimento do pet.
	var st := _slot_of(p, &"stable")
	p.inventory.slots[0] = p.inventory.slots[st]
	p.inventory.slots[st] = null
	p.inventory.changed.emit()
	for _i in 5:
		await get_tree().process_frame
	check((p.get_node("Interaction") as PlayerInteraction)._ghost_id == &"stable", "fantasma troca para o estábulo")
	check(Game.stables.size() == stables_before, "estábulo fantasma não vira ponto de renascimento")
	p.select_slot(1)
	await get_tree().process_frame
	check((p.get_node("Interaction") as PlayerInteraction)._ghost == null or p.held_item() != null and p.held_item().kind == ItemData.Kind.PLACEABLE, "fantasma some ao trocar para outro item")
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
