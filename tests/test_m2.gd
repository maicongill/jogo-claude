extends Node
## Marco 2: terreno por chunks, determinismo e carregamento em volta do jogador.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	var defs: Array = []
	for i in Database.resource_nodes.size():
		var d := Database.resource_nodes[i]
		defs.append({"index": i, "density_plain": d.density_plain, "density_forest": d.density_forest,
				"radius": d.radius, "scale_min": d.scale_min, "scale_max": d.scale_max})

	var a := ChunkBuilder.build(1234, Vector2i(3, -2), 32, defs)
	var b := ChunkBuilder.build(1234, Vector2i(3, -2), 32, defs)
	var c := ChunkBuilder.build(9999, Vector2i(3, -2), 32, defs)
	check(a["heights"] == b["heights"] and a["fields"] == b["fields"], "mesma seed gera o mesmo chunk (terreno e recursos)")
	check(a["heights"] != c["heights"], "seed diferente gera terreno diferente")

	var left := ChunkBuilder.build(1234, Vector2i(0, 0), 32, defs)
	var right := ChunkBuilder.build(1234, Vector2i(1, 0), 32, defs)
	var seam_ok := true
	for j in 33:
		if not is_equal_approx(left["heights"][j * 33 + 32], right["heights"][j * 33]):
			seam_ok = false
	check(seam_ok, "chunks vizinhos se encontram sem emenda")

	var tree_idx := 0
	for i in Database.resource_nodes.size():
		if Database.resource_nodes[i].id == &"tree":
			tree_idx = i
	var trees := 0
	var forest_chunks := 0
	for cx in range(-8, 9):
		for cz in range(-8, 9):
			var d := ChunkBuilder.build(1234, Vector2i(cx, cz), 32, defs)
			for f in d["fields"]:
				if f["index"] == tree_idx:
					trees += f["xforms"].size()
					if f["xforms"].size() > 12:
						forest_chunks += 1
	check(trees > 300, "há árvores no mundo (%d em 289 chunks)" % trees)
	check(forest_chunks > 10, "existem florestas densas (%d chunks)" % forest_chunks)

	# Carregamento real em volta do jogador.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t0 := Time.get_ticks_msec()
	var max_frame := 0.0
	var frames := 0
	while main.chunks.loaded_count() < 100 and frames < 3000:
		var f0 := Time.get_ticks_usec()
		await get_tree().process_frame
		max_frame = maxf(max_frame, (Time.get_ticks_usec() - f0) / 1000.0)
		frames += 1
	check(main.chunks.loaded_count() >= 100, "carrega o raio de 6 chunks (%d chunks, %d ms)" % [main.chunks.loaded_count(), Time.get_ticks_msec() - t0])
	check(not main.player.frozen, "jogador liberado quando o chão carregou")
	await get_tree().create_timer(1.0).timeout
	var ground: float = main.chunks.height_at(main.player.global_position.x, main.player.global_position.z)
	check(absf(main.player.global_position.y - ground) < 0.6, "jogador está sobre o terreno (y=%.2f, chão=%.2f)" % [main.player.global_position.y, ground])

	# Anda 15 s em linha reta e confere que nunca cai do mundo e que chunks entram e saem.
	var chunks_seen := {}
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var worst_gap := 0.0
	for i in 900:
		await get_tree().physics_frame
		var p: Vector3 = main.player.global_position
		worst_gap = maxf(worst_gap, absf(p.y - main.chunks.height_at(p.x, p.z)))
		if i % 30 == 0:
			chunks_seen[main.chunks.world_to_chunk(p)] = true
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	check(worst_gap < 6.0, "não atravessa o chão ao andar (maior distância ao chão: %.1f m)" % worst_gap)
	check(chunks_seen.size() >= 3, "atravessou %d chunks" % chunks_seen.size())
	check(main.chunks.loaded_count() < 140, "chunks distantes são descartados (%d carregados)" % main.chunks.loaded_count())

	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
