class_name PrimitiveMeshes
extends RefCounted
## Formas procedurais (placeholders) com cor por vértice.

static var _cache: Dictionary = {}


static func get_mesh(mesh_id: StringName) -> ArrayMesh:
	if not _cache.has(mesh_id):
		match mesh_id:
			&"tree": _cache[mesh_id] = _tree()
			&"rock": _cache[mesh_id] = _rock()
			&"bush": _cache[mesh_id] = _bush(true)
			&"bush_empty": _cache[mesh_id] = _bush(false)
			&"sapling": _cache[mesh_id] = _sapling()
			_: _cache[mesh_id] = _tree()
	return _cache[mesh_id]


static func _tree() -> ArrayMesh:
	var b := _Builder.new()
	b.add(_cylinder(0.22, 0.34, 2.4), Transform3D(Basis(), Vector3(0, 1.2, 0)), Color(0.42, 0.28, 0.18))
	b.add(_sphere(1.55, 0.8), Transform3D(Basis(), Vector3(0, 3.3, 0)), Color(0.30, 0.62, 0.28))
	b.add(_sphere(1.1, 0.9), Transform3D(Basis(), Vector3(0.1, 4.3, 0.1)), Color(0.36, 0.70, 0.30))
	return b.build()


static func _rock() -> ArrayMesh:
	var b := _Builder.new()
	b.add(_sphere(0.9, 0.7), Transform3D(Basis().scaled(Vector3(1.0, 0.8, 1.1)), Vector3(0, 0.4, 0)), Color(0.55, 0.55, 0.58))
	b.add(_sphere(0.55, 0.7), Transform3D(Basis(), Vector3(0.7, 0.25, 0.3)), Color(0.62, 0.62, 0.65))
	return b.build()


static func _bush(with_berries: bool) -> ArrayMesh:
	var b := _Builder.new()
	b.add(_sphere(0.65, 0.8), Transform3D(Basis(), Vector3(0, 0.5, 0)), Color(0.25, 0.55, 0.25))
	if with_berries:
		for p in [Vector3(0.45, 0.65, 0.2), Vector3(-0.3, 0.75, 0.4), Vector3(0.1, 0.95, -0.35), Vector3(-0.45, 0.5, -0.2), Vector3(0.3, 0.45, -0.5)]:
			b.add(_sphere(0.1, 1.0), Transform3D(Basis(), p), Color(0.85, 0.15, 0.25))
	return b.build()


static func _sapling() -> ArrayMesh:
	var b := _Builder.new()
	b.add(_cylinder(0.04, 0.06, 0.6), Transform3D(Basis(), Vector3(0, 0.3, 0)), Color(0.42, 0.28, 0.18))
	b.add(_sphere(0.25, 0.8), Transform3D(Basis(), Vector3(0, 0.7, 0)), Color(0.40, 0.75, 0.32))
	return b.build()


static func _cylinder(top: float, bottom: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


static func _sphere(r: float, h_ratio: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * h_ratio
	m.radial_segments = 8
	m.rings = 4
	return m


class _Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add(mesh: Mesh, xf: Transform3D, color: Color) -> void:
		var arrays := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in v.size():
			verts.append(xf * v[i])
			normals.append((nb * n[i]).normalized())
			colors.append(color)
		for i in idx:
			indices.append(base + i)

	func build() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
