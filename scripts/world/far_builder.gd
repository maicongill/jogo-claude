class_name FarBuilder
extends RefCounted
## Gera, em outra thread, um bloco do mundo distante: terreno simplificado (com "saia" nas bordas
## para não abrir frestas) e onde ficam os objetos. Faixa média: a posição exata de cada árvore,
## pedra e arbusto (as mesmas dos chunks perto). Faixa longe: quanto de floresta há em cada vértice
## do terreno (as árvores viram um dossel no próprio terreno). Seguro fora da thread principal.

## p: {seed, origin (Vector2i, metros), size, step, chunk_size, defs, lower, skirt, far (bool),
##     tree_index, canopy_min, canopy_full}
static func build(p: Dictionary) -> Dictionary:
	var gen := TerrainGenerator.new(p["seed"])
	var origin: Vector2i = p["origin"]
	var size: int = p["size"]
	var step: int = p["step"]
	var out := {"origin": origin, "far": p["far"]}
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
	var canopy := PackedFloat32Array()
	if p["far"]:
		canopy = _canopy(trees, size, step, p.get("canopy_min", 1.5), p.get("canopy_full", 7.5))
	else:
		out["objects"] = objects
	out["terrain"] = _terrain(gen, origin, size, step, p["lower"], p["skirt"], canopy)
	out["trees"] = trees.size()
	return out


## Floresta em cada vértice (0 a 1): conta as árvores nas células em volta (3 x 3 células do
## tamanho do passo). Árvores soltas não contam; floresta fechada chega a 1.
static func _canopy(trees: Array[Vector3], size: int, step: int, min_count: float, full_count: float) -> PackedFloat32Array:
	var n := size / step + 1
	var grid := PackedInt32Array()
	grid.resize((n + 1) * (n + 1))
	for t in trees:
		var gx := clampi(floori(t.x / step + 0.5), 0, n)
		var gz := clampi(floori(t.y / step + 0.5), 0, n)
		grid[gz * (n + 1) + gx] += 1
	var out := PackedFloat32Array()
	out.resize(n * n)
	for j in n:
		for i in n:
			var count := 0
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var x: int = i + dx
					var z: int = j + dz
					if x >= 0 and z >= 0 and x <= n and z <= n:
						count += grid[z * (n + 1) + x]
			out[j * n + i] = clampf((count - min_count) / maxf(full_count - min_count, 0.1), 0.0, 1.0)
	return out


static func _terrain(gen: TerrainGenerator, origin: Vector2i, size: int, step: int, lower: float, skirt: float,
		canopy: PackedFloat32Array) -> Dictionary:
	var n := size / step + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
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
			uvs.append(Vector2(canopy[j * n + i] if not canopy.is_empty() else 0.0, 0.0))
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
		uvs.append(uvs[a])  # a saia sobe junto com o dossel da borda
		uvs.append(uvs[b])
		indices.append_array([a, b, base, b, base + 1, base])
		indices.append_array([a, base, b, b, base, base + 1])  # dos dois lados
	return {"vertices": verts, "normals": normals, "colors": colors, "uvs": uvs, "indices": indices}
