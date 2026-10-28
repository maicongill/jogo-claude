class_name ChunkBuilder
extends RefCounted
## Gera os dados de um chunk (malha, alturas e posições de recursos). Só usa dados
## simples e objetos próprios, então é seguro rodar em outra thread.

const CELL := 4  # tamanho da célula de distribuição de recursos (metros)

const PLAIN_COLOR := Color(0.55, 0.80, 0.38)
const FOREST_COLOR := Color(0.30, 0.58, 0.30)
const ROCK_COLOR := Color(0.55, 0.52, 0.48)


## defs: lista de Dictionary {index, density_plain, density_forest, radius, scale_min, scale_max}
static func build(world_seed: int, coord: Vector2i, size: int, defs: Array) -> Dictionary:
	var gen := TerrainGenerator.new(world_seed)
	var ox := coord.x * size
	var oz := coord.y * size
	var n := size + 1
	var w := size + 3  # 1 vértice de margem em cada lado, para normais sem emendas
	var hm := PackedFloat32Array()
	hm.resize(w * w)
	for j in w:
		for i in w:
			hm[j * w + i] = gen.height_at(ox + i - 1, oz + j - 1)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var heights := PackedFloat32Array()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	heights.resize(n * n)
	for j in n:
		for i in n:
			var c := (j + 1) * w + (i + 1)
			var h := hm[c]
			var normal := Vector3(hm[c - 1] - hm[c + 1], 2.0, hm[c - w] - hm[c + w]).normalized()
			var wx := ox + i
			var wz := oz + j
			verts[j * n + i] = Vector3(i, h, j)
			normals[j * n + i] = normal
			colors[j * n + i] = ground_color(gen, wx, wz, normal)
			heights[j * n + i] = h

	var indices := PackedInt32Array()
	indices.resize(size * size * 6)
	var k := 0
	for j in size:
		for i in size:
			var a := j * n + i
			var b := a + 1
			var c2 := a + n
			var d := c2 + 1
			indices[k] = a; indices[k + 1] = b; indices[k + 2] = c2
			indices[k + 3] = b; indices[k + 4] = d; indices[k + 5] = c2
			k += 6

	return {
		"coord": coord,
		"vertices": verts, "normals": normals, "colors": colors, "indices": indices,
		"heights": heights,
		"fields": _place_resources(gen, world_seed, coord, size, defs),
	}


## Cor do chão num ponto (planície/floresta, variação e rocha nas encostas). Usada também pelo
## terreno distante (FarBuilder), para as faixas de detalhe terem a mesma cor.
static func ground_color(gen: TerrainGenerator, wx: float, wz: float, normal: Vector3) -> Color:
	var col := PLAIN_COLOR.lerp(FOREST_COLOR, gen.forest_amount(wx, wz))
	col = col.lightened(gen.tint_at(wx, wz) * 0.12)
	return col.lerp(ROCK_COLOR, smoothstep(0.22, 0.45, 1.0 - normal.y))


static func _place_resources(gen: TerrainGenerator, world_seed: int, coord: Vector2i, size: int, defs: Array) -> Array:
	var result: Array = []
	var occupied: Array[Vector3] = []  # x, z, raio
	var cells := size / CELL
	for def: Dictionary in defs:
		var rng := RandomNumberGenerator.new()
		rng.seed = _mix(world_seed, coord.x, coord.y, def["index"])
		var xforms: Array[Transform3D] = []
		for cj in cells:
			for ci in cells:
				# Sorteia sempre os mesmos valores, para o resultado depender só da seed.
				var roll := rng.randf()
				var jx := rng.randf_range(0.4, CELL - 0.4)
				var jz := rng.randf_range(0.4, CELL - 0.4)
				var yaw := rng.randf() * TAU
				var sc := rng.randf_range(def["scale_min"], def["scale_max"])
				var lx := ci * CELL + jx
				var lz := cj * CELL + jz
				var wx := coord.x * size + lx
				var wz := coord.y * size + lz
				if roll > lerpf(def["density_plain"], def["density_forest"], gen.forest_amount(wx, wz)):
					continue
				if Vector2(wx, wz).length() < 8.0:
					continue
				var h := gen.height_at(wx, wz)
				var slope := maxf(absf(gen.height_at(wx + 1.0, wz) - h), absf(gen.height_at(wx, wz + 1.0) - h))
				if slope > 0.7:
					continue
				var r: float = def["radius"] * sc
				var blocked := false
				for o in occupied:
					if Vector2(o.x - lx, o.y - lz).length() < o.z + r:
						blocked = true
						break
				if blocked:
					continue
				occupied.append(Vector3(lx, lz, r))
				xforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), Vector3(lx, h, lz)))
		result.append({"index": def["index"], "xforms": xforms})
	return result


static func _mix(a: int, b: int, c: int, d: int) -> int:
	return (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
