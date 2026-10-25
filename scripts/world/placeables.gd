class_name Placeables
extends RefCounted
## Fábrica dos objetos colocáveis (cama, mesa de magia, estábulo...).


static func create(place_id: StringName) -> Node3D:
	match place_id:
		&"bed":
			return Bed.new()
	return null


class Bed extends StaticBody3D:
	func _ready() -> void:
		collision_layer = 16
		add_to_group(&"bed")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 0.5, 2.0)
		shape.shape = box
		shape.position.y = 0.25
		add_child(shape)
		var frame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(1.0, 0.3, 2.0)
		frame.mesh = fm
		frame.position.y = 0.15
		frame.material_override = MaterialFactory.solid(Color(0.5, 0.33, 0.2))
		add_child(frame)
		var mattress := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.9, 0.2, 1.9)
		mattress.mesh = mm
		mattress.position.y = 0.4
		mattress.material_override = MaterialFactory.solid(Color(0.85, 0.4, 0.4))
		add_child(mattress)
		var pillow := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 0.14, 0.4)
		pillow.mesh = pm
		pillow.position = Vector3(0, 0.55, 0.7)
		pillow.material_override = MaterialFactory.solid(Color(0.95, 0.93, 0.85))
		add_child(pillow)

	func interact(player: Player) -> void:
		Game.spawn_point = global_position + Vector3(0, 0.6, 0) + global_basis.x * 1.4
		EventBus.message.emit("Cama definida como seu ponto de renascimento.")
