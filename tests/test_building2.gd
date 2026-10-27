extends Node
## Ajuste 2 (Etapa 6): porta, janela, viga e vaso de flores; a estabilidade continua funcionando.

var failures := 0
var b: BuildSystem


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func idx(id: StringName) -> int:
	for i in b.pieces_data.size():
		if b.pieces_data[i].id == id:
			return i
	return -1


func put(id: StringName, at: Vector3) -> BuildPiece:
	b.select(idx(id))
	var t := b.compute_target(at)
	if not t.get("valid", false):
		print("    (", id, " inválido em ", at, ": ", t.get("reason", ""), ")")
		return null
	return b.place(b.pieces_data[idx(id)], t)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	b = main.build
	b.grid_enabled = true
	p.inventory.add(Database.item(&"wood"), 64)
	p.inventory.add(Database.item(&"wood"), 64)
	p.inventory.add(Database.item(&"stone"), 64)
	for id in [&"window", &"beam"]:
		var d: BuildPieceData = b.pieces_data[idx(id)]
		check(idx(id) >= 0 and not d.cost_items.is_empty(), "%s existe e tem custo (%s)" % [d.display_name, b._cost_text(d)])

	# Casa: piso, porta, 2 janelas, 1 parede, vigas nos cantos, telhado.
	var h: float = main.chunks.height_at(16.0, 16.0)
	var fl := put(&"floor", Vector3(16, h, 16))
	check(fl != null, "piso")
	var fp := fl.global_position
	var door := put(&"door", fp + Vector3(0, 1.4, 2))
	var win1 := put(&"window", fp + Vector3(2, 1.4, 0))
	var win2 := put(&"window", fp + Vector3(-2, 1.4, 0))
	var wall := put(&"wall", fp + Vector3(0, 1.4, -2))
	check(door != null and door.panel != null, "porta com painel que abre")
	check(win1 != null and win2 != null, "duas janelas encaixam nas bordas do piso")
	check(wall != null, "parede")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if win1 != null:
		# A abertura: um raio na altura do meio da janela passa direto.
		var mid := win1.global_position + Vector3(0, PieceGeometry.WINDOW_SILL + PieceGeometry.WINDOW_HEIGHT * 0.5, 0)
		var q := PhysicsRayQueryParameters3D.create(mid + Vector3(1, 0, 0), mid - Vector3(1, 0, 0), 16)
		check(p.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "a janela tem abertura de verdade")
		var q2 := PhysicsRayQueryParameters3D.create(mid + Vector3(1, -0.8, 0), mid - Vector3(1, 0.8, 0), 16)
		check(not p.get_world_3d().direct_space_state.intersect_ray(q2).is_empty(), "abaixo do peitoril é parede")
	var beams: Array[BuildPiece] = []
	for c in [Vector3(2, 0, 2), Vector3(-2, 0, 2), Vector3(2, 0, -2), Vector3(-2, 0, -2)]:
		var bm := put(&"beam", fp + c + Vector3(0, 1.4, 0))
		if bm != null:
			beams.append(bm)
	check(beams.size() == 4, "4 vigas nos cantos do piso (%d)" % beams.size())
	var roof := put(&"roof", fp + Vector3(0, 3.2, 0))
	check(roof != null, "telhado em cima de paredes e vigas")
	if roof != null:
		var via_beam := false
		for n in roof.links:
			via_beam = via_beam or n.piece_id == &"beam"
		check(via_beam, "o telhado está ligado às vigas")
		check(roof.stability > 0.9, "telhado apoiado em viga fica mais estável (%.2f > 0.90 das paredes)" % roof.stability)

	# Viga aumenta o alcance: um balanço de pisos elevados só se sustenta com vigas.
	var gx := 40.0
	var gz := 40.0
	var base := put(&"beam", Vector3(gx + 2, main.chunks.height_at(gx + 2, gz + 2), gz + 2))
	check(base != null and base.grounded, "viga solta no chão (canto da grade)")
	if base != null:
		var top := base.global_position + Vector3(0, PieceGeometry.WALL_HEIGHT, 0)
		var deck := put(&"floor", top + Vector3(-2, 0, -2))
		check(deck != null, "piso elevado em cima da viga")
		if deck != null:
			check(deck.stability > 0.9, "piso sobre viga quase totalmente estável (%.2f)" % deck.stability)
			var ext: Array[BuildPiece] = []
			var at := deck.global_position
			for i in 3:
				at += Vector3(-4, 0, 0)
				var e := put(&"floor", at)
				if e == null:
					break
				ext.append(e)
			check(ext.size() >= 2, "o piso elevado se estende a partir da viga (%d vãos)" % ext.size())
			# Tira a viga: tudo que ela segurava desaba.
			b.demolish(base)
			await get_tree().process_frame
			check(not is_instance_valid(deck) or deck.is_queued_for_deletion(), "sem a viga, o piso elevado desaba")

	# Vaso de flores: receita, colocar sobre o piso da casa e cair junto.
	var pot_recipe: RecipeData = null
	for r in Database.recipes:
		if r.output.id == &"flower_pot":
			pot_recipe = r
	check(pot_recipe != null, "vaso tem receita de crafting")
	p.inventory.add(Database.item(&"sapling"), 4)
	p.inventory.add(Database.item(&"berries"), 4)
	check(pot_recipe != null and Crafting.craft(p.inventory, pot_recipe), "crafta o vaso")
	var it: PlayerInteraction = p.get_node("Interaction")
	# Fica dentro da casa olhando para o piso.
	p.global_position = fp + Vector3(0, 0.3, 0)
	await get_tree().physics_frame
	var slot := -1
	for i in p.inventory.size():
		var st := p.inventory.get_stack(i)
		if st != null and st.item.id == &"flower_pot":
			slot = i
	p.inventory.slots[0] = p.inventory.slots[slot]
	if slot != 0:
		p.inventory.slots[slot] = null
	p.inventory.changed.emit()
	p.select_slot(0)
	(p.get_node("CameraPivot/SpringArm3D") as Node3D).rotation.x = deg_to_rad(-60)
	for _i in 6:
		await get_tree().process_frame
	var spot := it._place_spot(&"flower_pot")
	check(spot.get("valid", false) and spot.get("on") is BuildPiece, "vaso pode ir sobre o piso da casa")
	it._cooldown = 0.0
	it.primary_action()
	await get_tree().process_frame
	var pots := get_tree().get_nodes_in_group(&"flower_pot")
	check(pots.size() == 1 and pots[0].get_parent() is BuildPiece, "vaso colocado e preso ao piso")
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
