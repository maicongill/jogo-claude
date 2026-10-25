extends Node3D
## Cena principal. No marco 1: chão plano de teste com alguns obstáculos.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var player: Player


func _ready() -> void:
	_build_test_floor()
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = Vector3(0, 0.5, 0)


func _build_test_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "TestFloor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(200, 1, 200)
	mesh.mesh = plane
	mesh.position.y = -0.5
	mesh.material_override = _color_material(Color(0.45, 0.65, 0.35))
	floor_body.add_child(mesh)
	add_child(floor_body)

	# Obstáculos para testar pulo e câmera.
	for i in 5:
		_add_box(Vector3(6 + i * 3, 0.5 + i * 0.4, -4), Vector3(2, 1 + i * 0.8, 2), Color(0.7, 0.6, 0.45))
	_add_box(Vector3(-5, 1.5, -6), Vector3(0.4, 3, 8), Color(0.6, 0.55, 0.5))
	_add_box(Vector3(0, 1.25, -9), Vector3(6, 2.5, 0.4), Color(0.6, 0.55, 0.5))


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _color_material(color)
	body.add_child(mesh)
	add_child(body)


func _color_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
