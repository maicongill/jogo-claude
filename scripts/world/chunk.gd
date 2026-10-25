class_name Chunk
extends Node3D
## Um pedaço do mundo: malha do terreno, colisão e recursos.

var coord := Vector2i.ZERO
var fields: Array[ResourceField] = []


func setup(data: Dictionary, size: int, node_defs: Array[ResourceNodeData]) -> void:
	coord = data["coord"]
	name = "Chunk_%d_%d" % [coord.x, coord.y]
	position = Vector3(coord.x * size, 0, coord.y * size)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MaterialFactory.vertex_color()
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = size + 1
	hm.map_depth = size + 1
	hm.map_data = data["heights"]
	shape.shape = hm
	shape.position = Vector3(size * 0.5, 0, size * 0.5)
	body.add_child(shape)
	add_child(body)

	for f: Dictionary in data["fields"]:
		var xforms: Array[Transform3D] = []
		xforms.assign(f["xforms"])
		if xforms.is_empty():
			continue
		var def := node_defs[f["index"]]
		var field := ResourceField.new()
		field.name = "Field_%s" % def.id
		add_child(field)
		field.setup(def, "%d,%d,%s" % [coord.x, coord.y, def.id], xforms)
		fields.append(field)
