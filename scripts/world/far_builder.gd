class_name FarBuilder
extends RefCounted
## Gera, em outra thread, um bloco do mundo distante: terreno simplificado (com "saia" nas bordas
## para não abrir frestas) e onde ficam os objetos. Faixa média: a posição exata de cada árvore,
## pedra e arbusto (as mesmas dos chunks perto). Faixa longe: as árvores de cada célula juntadas
## em uma mancha. Só usa dados simples, então é seguro fora da thread principal.

## p: {seed, origin (Vector2i, metros), size, step, chunk_size, defs, lower, skirt, far (bool),
##     cluster_cell, tree_index}
static func build(p: Dictionary) -> Dictionary:
	var gen := TerrainGenerator.new(p["seed"])
	var origin: Vector2i = p["origin"]
	var size: int = p["size"]
	var step: int = p["step"]
	var out := {"origin": origin, "far": p["far"]}
	out["terrain"] = _terrain(gen, origin, size, step, p["lower"], p["skirt"])
	# Objetos: refaz o sorteio de cada chunk do bloco (o mesmo que os chunks perto usam).
	var cs: int = p["chunk_size"]
	var per := size / cs
	var c0 := Vector2i(floori(float(origin.x) / cs), floori(float(origin.y) / cs))
	var objects: Array = []  # [{index, key, i, xf}] na faixa média
	var trees: Array[Vector3] = []  # x, z (locais ao bloco), escala — para as manchas
	for cz in per:
		for cx in per:
			var coord := c0 + Vector2i(cx, cz)
			var offset := Vector3(coord.x * cs - origin.x, 0, coord.y * cs - origin.y)
			for f: Dictionary in ChunkBuilder._place_resources(gen, p["seed"], coord, cs, p["defs"]):
				var idx: int = f["index"]
				var xfs: Array = f["xforms"]
				for i in xfs.size():
					var xf: Transform3D = xfs[i]
					xf.origin += offset
					if p["far"]:
						if idx == p["tree_index"]:
							trees.append(Vector3(xf.origin.x, xf.origin.z, xf.basis.get_scale().x))
					else:
						objects.append({"index": idx, "key": "%d,%d" % [coord.x, coord.y], "i": i, "xf": xf})
	if p["far"]:
		out["blobs"] = _clusters(gen, origin, trees, p["cluster_cell"])
	else:
		out["objects"] = objects
	return out


static func _terrain(gen: TerrainGenerator, origin: Vector2i, size: int, step: int, lower: float, skirt: float) -> Dictionary:
	var n := size / step + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for j in n:
		for i in n:
			var wx := float(origin.x + i * step)
			var wz := float(origin.y + j * step)
			var h := gen.height_at(wx, wz)
			var e := float(step)
			var normal := Vector3(gen.height_at(wx - e, wz) - gen.height_at(wx + e, wz), 2.0 * e,
					gen.height_at(wx, wz - e) - gen.height_at(wx, wz + e)).normalized()
			verts.append(Vector3(i * step, h - lower, j * step))
			normals.append(normal)
			colors.append(ChunkBuilder.ground_color(gen, wx, wz, normal))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	# Saia: uma faixa que desce nas 4 bordas, cobrindo a diferença de altura para o vizinho.
	var edges: Array = []
	for i in n - 1:
		edges.append([i, i + 1])                                  # borda z = 0
		edges.append([(n - 1) * n + i + 1, (n - 1) * n + i])      # borda z = max
		edges.append([(i + 1) * n, i * n])                        # borda x = 0
		edges.append([i * n + n - 1, (i + 1) * n + n - 1])        # borda x = max
	for e2 in edges:
		var a: int = e2[0]
		var b: int = e2[1]
		var base := verts.size()
		verts.append(verts[a] - Vector3(0, skirt, 0))
		verts.append(verts[b] - Vector3(0, skirt, 0))
		normals.append(normals[a])
		normals.append(normals[b])
		colors.append(colors[a].darkened(0.1))
		colors.append(colors[b].darkened(0.1))
		indices.append_array([a, b, base, b, base + 1, base])
		indices.append_array([a, base, b, b, base, base + 1])  # dos dois lados
	return {"vertices": verts, "normals": normals, "colors": colors, "indices": indices}


## Junta as árvores de cada célula numa mancha: centro, chão, quantas são, espalhamento e escala média.
static func _clusters(gen: TerrainGenerator, origin: Vector2i, trees: Array[Vector3], cell: float) -> Array:
	var cells := {}
	for t in trees:
		var k := Vector2i(floori(t.x / cell), floori(t.y / cell))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(t)
	var blobs: Array = []
	for k: Vector2i in cells:
		var list: Array = cells[k]
		var sum := Vector2.ZERO
		var sc := 0.0
		for t: Vector3 in list:
			sum += Vector2(t.x, t.y)
			sc += t.z
		var c := sum / list.size()
		var spread := 0.0
		for t: Vector3 in list:
			spread = maxf(spread, Vector2(t.x, t.y).distance_to(c))
		var ground := gen.height_at(origin.x + c.x, origin.y + c.y)
		blobs.append({"x": c.x, "z": c.y, "y": ground, "count": list.size(), "spread": spread, "scale": sc / list.size(),
				"tint": gen.tint_at(origin.x + c.x, origin.y + c.y)})
	return blobs
