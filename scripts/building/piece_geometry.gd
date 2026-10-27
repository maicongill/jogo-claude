class_name PieceGeometry
extends RefCounted
## Forma, colisão e pontos de encaixe (sockets) das peças. A peça de 4 x 4 m é a unidade da grade.

static var decay_slab := 0.25
static var decay_stairs := 0.3
static var decay_other := 0.1
## Vigas quase não perdem estabilidade: servem de apoio para pisos e telhados.
static var decay_beam := 0.05

const CELL := 4.0
const SLAB_THICKNESS := 0.2
const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.2
const STAIRS_WIDTH := 2.0
const STAIRS_RUN := 4.0
const STAIRS_RISE := 3.0
const DOOR_WIDTH := 1.4
const DOOR_HEIGHT := 2.3
const WINDOW_WIDTH := 1.6
const WINDOW_HEIGHT := 1.1
const WINDOW_SILL := 1.0
const BEAM_SIZE := 0.32

const COLORS := {
	&"floor": Color(0.66, 0.48, 0.30),
	&"wall": Color(0.74, 0.56, 0.36),
	&"door": Color(0.45, 0.30, 0.18),
	&"roof": Color(0.62, 0.30, 0.24),
	&"stairs": Color(0.66, 0.48, 0.30),
	&"window": Color(0.74, 0.56, 0.36),
	&"beam": Color(0.42, 0.28, 0.16),
}


## "slab" (piso e telhado), "wall" (parede, porta e janela), "beam" (viga) ou "stairs".
static func family(id: StringName) -> StringName:
	match id:
		&"floor", &"roof": return &"slab"
		&"wall", &"door", &"window": return &"wall"
		&"beam": return &"beam"
	return &"stairs"


static func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = MaterialFactory.solid(color)
	return mi


static func _shape(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation = rot
	return cs


## Partes da janela (tamanho, posição): parede com uma abertura no meio.
static func _window_parts() -> Array:
	var side := (CELL - WINDOW_WIDTH) * 0.5
	var top_h := WALL_HEIGHT - WINDOW_SILL - WINDOW_HEIGHT
	return [
		[Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(-(WINDOW_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0)],
		[Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3((WINDOW_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0)],
		[Vector3(WINDOW_WIDTH, WINDOW_SILL, WALL_THICKNESS), Vector3(0, WINDOW_SILL * 0.5, 0)],
		[Vector3(WINDOW_WIDTH, top_h, WALL_THICKNESS), Vector3(0, WALL_HEIGHT - top_h * 0.5, 0)],
	]


## Meshes da peça (origem no centro da base).
static func make_visuals(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var c: Color = COLORS[id]
	match id:
		&"floor", &"roof":
			out.append(_box(Vector3(CELL, SLAB_THICKNESS, CELL), Vector3(0, SLAB_THICKNESS * 0.5, 0), c))
		&"wall":
			out.append(_box(Vector3(CELL, WALL_HEIGHT, WALL_THICKNESS), Vector3(0, WALL_HEIGHT * 0.5, 0), c))
		&"door":
			var side := (CELL - DOOR_WIDTH) * 0.5
			out.append(_box(Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(-(DOOR_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0), COLORS[&"wall"]))
			out.append(_box(Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3((DOOR_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0), COLORS[&"wall"]))
			out.append(_box(Vector3(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS), Vector3(0, DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) * 0.5, 0), COLORS[&"wall"]))
		&"window":
			for part in _window_parts():
				out.append(_box(part[0], part[1], c))
			# Peitoril e moldura mais escuros, para ler como janela de longe.
			out.append(_box(Vector3(WINDOW_WIDTH + 0.2, 0.08, WALL_THICKNESS + 0.12), Vector3(0, WINDOW_SILL, 0), COLORS[&"door"]))
			out.append(_box(Vector3(WINDOW_WIDTH + 0.2, 0.08, WALL_THICKNESS + 0.06), Vector3(0, WINDOW_SILL + WINDOW_HEIGHT, 0), COLORS[&"door"]))
		&"beam":
			out.append(_box(Vector3(BEAM_SIZE, WALL_HEIGHT, BEAM_SIZE), Vector3(0, WALL_HEIGHT * 0.5, 0), c))
		&"stairs":
			var steps := 6
			var sh := STAIRS_RISE / steps
			var sd := STAIRS_RUN / steps
			for i in steps:
				# Degraus descem para +Z a partir da origem (topo, na altura do piso).
				var top := -sh * i
				out.append(_box(Vector3(STAIRS_WIDTH, sh * (steps - i) , sd), Vector3(0, top - sh * (steps - i) * 0.5, sd * (i + 0.5)), c))
	return out


## Colisões da peça.
static func make_shapes(id: StringName) -> Array[CollisionShape3D]:
	var out: Array[CollisionShape3D] = []
	match id:
		&"floor", &"roof":
			out.append(_shape(Vector3(CELL, SLAB_THICKNESS, CELL), Vector3(0, SLAB_THICKNESS * 0.5, 0)))
		&"wall":
			out.append(_shape(Vector3(CELL, WALL_HEIGHT, WALL_THICKNESS), Vector3(0, WALL_HEIGHT * 0.5, 0)))
		&"door":
			var side := (CELL - DOOR_WIDTH) * 0.5
			out.append(_shape(Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3(-(DOOR_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0)))
			out.append(_shape(Vector3(side, WALL_HEIGHT, WALL_THICKNESS), Vector3((DOOR_WIDTH + side) * 0.5, WALL_HEIGHT * 0.5, 0)))
			out.append(_shape(Vector3(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS), Vector3(0, DOOR_HEIGHT + (WALL_HEIGHT - DOOR_HEIGHT) * 0.5, 0)))
		&"window":
			for part in _window_parts():
				out.append(_shape(part[0], part[1]))
		&"beam":
			out.append(_shape(Vector3(BEAM_SIZE, WALL_HEIGHT, BEAM_SIZE), Vector3(0, WALL_HEIGHT * 0.5, 0)))
		&"stairs":
			# Rampa contínua para o personagem subir sem tropeçar nos degraus.
			var length := sqrt(STAIRS_RUN * STAIRS_RUN + STAIRS_RISE * STAIRS_RISE)
			var angle := atan2(STAIRS_RISE, STAIRS_RUN)
			out.append(_shape(Vector3(STAIRS_WIDTH, 0.3, length), Vector3(0, -STAIRS_RISE * 0.5 - 0.15 + 0.25, STAIRS_RUN * 0.5), Vector3(angle, 0, 0)))
	return out


## Pontos onde a peça `piece_id` pode ser encaixada em volta de uma peça já colocada.
## Devolve [{id, xf}] com a posição/rotação em que a nova peça ficaria.
static func offers(piece_id: StringName, xf: Transform3D) -> Array:
	var out: Array = []
	var o := xf.origin
	var b := xf.basis
	match piece_id:
		&"floor", &"roof":
			for d: Vector3 in [b.x, -b.x, b.z, -b.z]:
				out.append({"id": piece_id, "xf": Transform3D(b, o + d * CELL)})
				var edge := o + d * (CELL * 0.5) + Vector3(0, SLAB_THICKNESS, 0)
				var wall_basis := Basis(Vector3.UP.cross(d), Vector3.UP, d)
				out.append({"id": &"wall", "xf": Transform3D(wall_basis, edge)})
				out.append({"id": &"door", "xf": Transform3D(wall_basis, edge)})
				out.append({"id": &"window", "xf": Transform3D(wall_basis, edge)})
				out.append({"id": &"stairs", "xf": Transform3D(wall_basis, edge)})
			# Vigas nos 4 cantos, de pé sobre a placa.
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					var corner := o + b * Vector3(cx * CELL * 0.5, 0, cz * CELL * 0.5) + Vector3(0, SLAB_THICKNESS, 0)
					out.append({"id": &"beam", "xf": Transform3D(b, corner)})
		&"wall", &"door", &"window":
			var top := o + Vector3(0, WALL_HEIGHT, 0)
			out.append({"id": &"wall", "xf": Transform3D(b, top)})
			out.append({"id": &"door", "xf": Transform3D(b, top)})
			out.append({"id": &"window", "xf": Transform3D(b, top)})
			for d: Vector3 in [b.z, -b.z]:
				out.append({"id": &"roof", "xf": Transform3D(Basis(b.x, Vector3.UP, b.z), top + d * (CELL * 0.5))})
		&"beam":
			var top := o + Vector3(0, WALL_HEIGHT, 0)
			out.append({"id": &"beam", "xf": Transform3D(b, top)})
			# A viga sustenta, pelo canto, as placas que tocam o topo dela.
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					var center := top + b * Vector3(cx * CELL * 0.5, 0, cz * CELL * 0.5)
					out.append({"id": &"floor", "xf": Transform3D(b, center)})
					out.append({"id": &"roof", "xf": Transform3D(b, center)})
	return out


## O que cada tipo de peça pode receber (para filtrar as ofertas de acordo com a peça escolhida).
static func accepts(placed_id: StringName, new_id: StringName) -> bool:
	match placed_id:
		&"floor": return new_id in [&"floor", &"wall", &"door", &"window", &"stairs", &"beam"]
		&"roof": return new_id in [&"roof", &"wall", &"door", &"window", &"stairs", &"beam"]
		&"wall", &"door", &"window": return new_id in [&"wall", &"door", &"window", &"roof"]
		&"beam": return new_id in [&"beam", &"floor", &"roof"]
	return false


## Perda de estabilidade ao passar de uma peça para a vizinha.
static func decay(from_id: StringName, to_id: StringName) -> float:
	var a := family(from_id)
	var b := family(to_id)
	if a == &"beam" or b == &"beam":
		return decay_beam
	if a == &"slab" and b == &"slab":
		return decay_slab
	if a == &"stairs" or b == &"stairs":
		return decay_stairs
	return decay_other
