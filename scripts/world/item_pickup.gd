class_name ItemPickup
extends Node3D
## Item solto no mundo. O jogador o recolhe ao chegar perto.

var item: ItemData
var count := 1
var _t := 0.0
var _mesh: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, item_data: ItemData, amount := 1) -> ItemPickup:
	var p := ItemPickup.new()
	p.item = item_data
	p.count = amount
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	add_to_group(&"pickup")
	_mesh = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.3, 0.3, 0.3)
	_mesh.mesh = m
	_mesh.material_override = MaterialFactory.solid(item.color)
	add_child(_mesh)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_mesh.position.y = 0.4 + sin(_t * 3.0) * 0.08
	_mesh.rotation.y += delta * 1.5
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.stats.dead:
		return
	var d := player.global_position.distance_to(global_position)
	if d < 1.6:
		var left := player.inventory.add(item, count)
		if left < count:
			EventBus.item_collected.emit(item, count - left)
		if left == 0:
			queue_free()
		else:
			count = left
	elif d < 4.0:
		global_position = global_position.move_toward(player.global_position, delta * 4.0)
