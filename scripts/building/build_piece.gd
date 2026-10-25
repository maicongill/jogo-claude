class_name BuildPiece
extends StaticBody3D
## Uma peça construída. Guarda quem a sustenta (links) e a estabilidade calculada.

var data: BuildPieceData
var piece_id: StringName
var links: Array[BuildPiece] = []
var stability := 0.0
var grounded := false
var hp := 40.0
var panel: DoorPanel
var _fire: BurnEffect


func setup(piece_data: BuildPieceData) -> void:
	data = piece_data
	piece_id = piece_data.id
	hp = piece_data.fire_hp
	collision_layer = 16  # camada 5: construções
	collision_mask = 0
	add_to_group(&"build_piece")
	for v in PieceGeometry.make_visuals(piece_id):
		add_child(v)
	for s in PieceGeometry.make_shapes(piece_id):
		add_child(s)
	if piece_id == &"door":
		panel = DoorPanel.new()
		add_child(panel)


## Põe fogo na peça (se for inflamável): ela queima e acaba destruída.
func ignite() -> void:
	if not data.flammable or _fire != null:
		return
	_fire = BurnEffect.new()
	_fire.dps = Config.f("magic.burn_dps_piece", 6.0)
	_fire.size = 2.2
	add_child(_fire)
	_fire.position = Vector3(0, 1.0 if piece_id in [&"wall", &"door"] else 0.3, 0)
	_fire.tick.connect(func(amount: float) -> void:
		if burn_damage(amount) and is_instance_valid(_fire):
			_fire.queue_free())


func unlink_all() -> void:
	for other in links:
		other.links.erase(self)
	links.clear()


## Fogo (marco 8) ou outro dano contínuo. Devolve true se a peça foi destruída.
func burn_damage(amount: float) -> bool:
	hp -= amount
	if hp <= 0.0:
		EventBus.piece_destroyed.emit(self)
		return true
	return false


## A peça cai como entulho e some.
func collapse() -> void:
	var debris := RigidBody3D.new()
	debris.collision_layer = 0
	debris.collision_mask = 1
	debris.mass = 20.0
	for child in get_children():
		if child is MeshInstance3D:
			child.reparent(debris, false)
	for s in PieceGeometry.make_shapes(piece_id):
		debris.add_child(s)
	var xf := global_transform
	get_parent().add_child(debris)
	debris.global_transform = xf
	debris.apply_central_impulse(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)) * 8.0)
	debris.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 15.0)
	var tw := debris.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(debris.queue_free)
	unlink_all()
	remove_from_group(&"build_piece")
	queue_free()


class DoorPanel extends StaticBody3D:
	var open := false
	var _pivot: Node3D

	func _ready() -> void:
		collision_layer = 16
		_pivot = Node3D.new()
		_pivot.position = Vector3(-PieceGeometry.DOOR_WIDTH * 0.5, 0, 0)
		add_child(_pivot)
		var w := PieceGeometry.DOOR_WIDTH - 0.04
		var h := PieceGeometry.DOOR_HEIGHT - 0.02
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(w, h, 0.08)
		mi.mesh = m
		mi.position = Vector3(w * 0.5 + 0.02, h * 0.5, 0)
		mi.material_override = MaterialFactory.solid(Color(0.36, 0.23, 0.13))
		_pivot.add_child(mi)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(w, h, 0.08)
		cs.shape = b
		cs.position = mi.position
		_pivot.add_child(cs)
		# A colisão acompanha o painel porque é filha do pivô (que gira).

	func interact(_player: Player) -> void:
		open = not open
		var tw := create_tween()
		tw.tween_property(_pivot, "rotation:y", deg_to_rad(-100.0) if open else 0.0, 0.25)
