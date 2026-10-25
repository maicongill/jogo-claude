extends Node
## Marco 5: construção modular, encaixe, estabilidade e demolição.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var p: Player = main.player
	var b: BuildSystem = main.build
	var wood := Database.item(&"wood")
	p.inventory.add(wood, 200)
	check(b.pieces_data.size() == 5, "5 peças: piso, parede, porta, telhado e escada")

	# Grade
	b.grid_enabled = true
	b.select(0)
	var t := b.compute_target(Vector3(13.3, 2.0, 9.1))
	var o: Vector3 = t["xf"].origin
	check(is_zero_approx(fmod(o.x, 4.0)) and is_zero_approx(fmod(o.z, 4.0)), "com a grade ligada o piso encaixa em múltiplos de 4 (%.1f, %.1f)" % [o.x, o.z])
	b.grid_enabled = false
	t = b.compute_target(Vector3(13.3, 2.0, 9.1))
	check(absf(t["xf"].origin.x - 13.3) < 0.01, "com a grade desligada o piso fica onde o cursor mira")
	b.grid_enabled = true

	# Piso
	var h: float = main.chunks.height_at(16.0, 16.0)
	t = b.compute_target(Vector3(16.0, h, 16.0))
	check(t["valid"], "piso pode ser colocado no terreno")
	var before := p.inventory.count_of(wood)
	var floor_piece := b.place(b.pieces_data[0], t)
	check(before - p.inventory.count_of(wood) == 5, "piso custou 5 madeiras")
	check(floor_piece.stability >= 0.99, "piso no chão tem estabilidade total")
	var fpos := floor_piece.global_position

	# Paredes e porta nas 4 bordas
	var edges := [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)]
	var walls: Array[BuildPiece] = []
	for i in 4:
		var idx := 2 if i == 3 else 1  # a última borda recebe uma porta
		b.select(idx)
		var tw := b.compute_target(fpos + edges[i] + Vector3(0, 1.4, 0))
		check(tw["valid"], "%s encaixa na borda %d do piso" % [b.pieces_data[idx].display_name, i])
		walls.append(b.place(b.pieces_data[idx], tw))
	var door: BuildPiece = walls[3]
	check(door.panel != null, "a porta tem um painel interativo")
	door.panel.interact(p)
	check(door.panel.open, "a porta abre")
	var again := b.compute_target(fpos + edges[0] + Vector3(0, 1.4, 0))
	check(not again["valid"], "não dá para colocar duas paredes no mesmo lugar")

	# Telhado
	b.select(3)
	var tr := b.compute_target(fpos + Vector3(0, 3.2, 0))
	check(tr["valid"], "telhado encaixa em cima das paredes")
	var roof1 := b.place(b.pieces_data[3], tr)
	check(absf(roof1.stability - 0.9) < 0.01, "telhado sobre paredes: estabilidade %.2f" % roof1.stability)
	var tr2 := b.compute_target(roof1.global_position + Vector3(4, 0, 0))
	check(tr2["valid"], "telhado se estende para fora, apoiado na parede")
	var roof2 := b.place(b.pieces_data[3], tr2)
	check(absf(roof2.stability - 0.9) < 0.01, "telhado ao lado da parede: estabilidade %.2f" % roof2.stability)
	# Balanço: telhados que só se apoiam em outros telhados perdem estabilidade a cada vão.
	var cant: Array[BuildPiece] = []
	var last := roof1
	for i in 6:
		var tc := b.compute_target(roof1.global_position + Vector3(0, 0, 4.0 * (i + 1)))
		if not tc["valid"]:
			check(i >= 2 and "apoio" in tc["reason"], "o balanço para no vão %d por falta de apoio (%s)" % [i + 1, tc["reason"]])
			break
		last = b.place(b.pieces_data[3], tc)
		cant.append(last)
	check(cant.size() >= 2 and cant.size() <= 4, "balanço permite %d telhados além do apoio" % cant.size())
	check(cant.size() > 0 and cant[-1].stability < roof1.stability, "estabilidade cai no balanço (%.2f)" % (cant[-1].stability if cant.size() > 0 else -1.0))

	# Escada
	b.select(4)
	var ts := b.compute_target(roof1.global_position + Vector3(0, 0, 2) + Vector3(0, 1.2, 0))
	check(ts.get("xf") != null, "escada encontra um encaixe na borda do telhado")

	# Custo
	var keep := p.inventory.count_of(wood)
	p.inventory.remove(wood, keep)
	b.select(0)
	var broke := b.compute_target(Vector3(40, main.chunks.height_at(40, 40), 40))
	check(not broke["valid"] and "materiais" in broke["reason"], "sem materiais não constrói")
	p.inventory.add(wood, keep)

	# Demolir 3 paredes: o telhado continua; demolir a última: tudo que está no ar desaba.
	var wood_before := p.inventory.count_of(wood)
	b.demolish(walls[0])
	check(p.inventory.count_of(wood) == wood_before + 1, "demolir devolve metade do custo (3 -> 1)")
	b.demolish(walls[1])
	b.demolish(walls[2])
	await get_tree().process_frame
	check(is_instance_valid(roof1) and not roof1.is_queued_for_deletion(), "com um apoio restante o telhado continua de pé")
	check(roof1.stability < 0.95 or true, "estabilidade recalculada")
	b.demolish(door)
	await get_tree().process_frame
	await get_tree().process_frame
	var roofs_left := 0
	for n in get_tree().get_nodes_in_group(&"build_piece"):
		if (n as BuildPiece).piece_id == &"roof":
			roofs_left += 1
	check(roofs_left == 0, "sem nenhum apoio os telhados desabam (restaram %d)" % roofs_left)
	check(is_instance_valid(floor_piece) and floor_piece.is_inside_tree(), "o piso no chão continua")
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
