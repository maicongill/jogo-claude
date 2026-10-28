extends Node
## Distância de renderização em faixas: imagens (PNG) dos objetos na faixa média, nas mesmas
## posições dos 3D; manchas de cor sólida juntando árvores na faixa longe; terreno distante abaixo
## do de perto (nunca por cima); árvore cortada não volta como imagem.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	var fw: FarWorld = main.far_world
	check(fw != null and fw.enabled(), "mundo distante ligado")
	for f in ["tree", "rock", "bush", "cluster"]:
		check(load("res://assets/impostors/%s.png" % f) != null, "imagem %s.png existe" % f)
	# Espera os blocos.
	var t0 := Time.get_ticks_msec()
	while (fw.tile_count(false) < 40 or fw.tile_count(true) < 20) and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().process_frame
	print("    blocos médios %d, longes %d (%.1f s)" % [fw.tile_count(false), fw.tile_count(true), (Time.get_ticks_msec() - t0) / 1000.0])
	check(fw.tile_count(false) >= 40, "blocos da faixa média criados")
	check(fw.tile_count(true) >= 20, "blocos da faixa longe criados")

	# 1) As imagens ficam onde estão os objetos 3D (mesmo sorteio).
	# Um chunk de perto com árvores, longe o bastante para já ter bloco médio por baixo (> 140 m).
	var field: ResourceField = null
	for c: Chunk in main.chunks._chunks.values():
		if Vector2(c.position.x + 16, c.position.z + 16).distance_to(Vector2(p.global_position.x, p.global_position.z)) < 150.0:
			continue
		for f in c.fields:
			if f.data.mesh_id == &"tree" and f._xforms.size() >= 3:
				field = f
				break
		if field != null:
			break
	check(field != null, "achou um chunk com árvores a mais de 140 m")
	var fr: Dictionary = fw._frames[field.data.id]
	var matched := 0
	var tile_size: int = fw._cfg.get("mid_tile", 64)
	for i in field._xforms.size():
		var wp: Vector3 = field.global_transform * field._xforms[i].origin
		var key := [false, Vector2i(floori(wp.x / tile_size), floori(wp.z / tile_size))]
		if not fw._tiles.has(key):
			continue
		for mmi in fw._tiles[key].get_children():
			if mmi is MultiMeshInstance3D and String(mmi.name) == "Impostors_%s" % field.data.id:
				for xfi: Transform3D in mmi.get_meta(&"transforms"):
					var ip: Vector3 = mmi.global_transform * xfi.origin
					var sc := field._xforms[i].basis.get_scale().x
					if Vector2(ip.x, ip.z).distance_to(Vector2(wp.x, wp.z)) < 0.01 and absf(ip.y - (wp.y + float(fr["bottom"]) * sc)) < 0.01:
						matched += 1
	check(matched == field._xforms.size(), "imagens nas mesmas posições das árvores 3D (%d de %d)" % [matched, field._xforms.size()])

	# 2) Árvore cortada não volta como imagem quando o chunk dela sai.
	var cut_wp: Vector3 = field.global_transform * field._xforms[0].origin
	field.damage_instance(0, 1000.0, false)
	var coord := Vector2i(floori(cut_wp.x / main.chunks.chunk_size), floori(cut_wp.z / main.chunks.chunk_size))
	main.chunks.chunk_unloaded.emit(coord)
	await get_tree().process_frame
	await get_tree().process_frame
	var still := false
	var key2 := [false, Vector2i(floori(cut_wp.x / tile_size), floori(cut_wp.z / tile_size))]
	if fw._tiles.has(key2):
		for mmi in fw._tiles[key2].get_children():
			if mmi is MultiMeshInstance3D and not mmi.is_queued_for_deletion():
				for xfi: Transform3D in mmi.get_meta(&"transforms"):
					var ip: Vector3 = mmi.global_transform * xfi.origin
					if Vector2(ip.x, ip.z).distance_to(Vector2(cut_wp.x, cut_wp.z)) < 0.01:
						still = true
	check(fw._tiles.has(key2) and not still, "árvore cortada some da faixa média")

	# 3) Manchas: cada uma junta árvores próximas; nunca mais manchas que árvores.
	var blobs := 0
	var trees_far := 0
	var max_count := 0
	for key: Array in fw._data:
		if key[0]:
			for b: Dictionary in fw._data[key]["blobs"]:
				blobs += 1
				trees_far += int(b["count"])
				max_count = maxi(max_count, int(b["count"]))
	print("    %d manchas juntando %d árvores (até %d numa mancha)" % [blobs, trees_far, max_count])
	check(blobs > 0 and blobs < trees_far, "árvores agrupadas em manchas (%d manchas, %d árvores)" % [blobs, trees_far])
	check(max_count >= 3, "manchas juntam várias árvores (até %d)" % max_count)

	# 4) Terreno distante fica abaixo do real (o de perto sempre aparece por cima).
	var worst := -INF
	for key: Array in fw._data:
		var verts: PackedVector3Array = fw._data[key]["terrain"]["vertices"]
		var origin: Vector2i = fw._data[key]["origin"]
		for k in mini(verts.size(), 40):
			var v := verts[k]
			worst = maxf(worst, v.y - main.chunks.height_at(origin.x + v.x, origin.y + v.z))
	check(worst < 0.0, "terreno distante sempre abaixo do de perto (maior diferença %.2f m)" % worst)
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
