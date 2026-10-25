class_name HeldItemVisual
extends Node3D
## Mostra o item selecionado na mão direita do personagem (formas simples) e anima o golpe.

var _attachment: BoneAttachment3D
var _holder: Node3D
var _current: StringName = &""
var _model: Node3D
var _base_pitch := 30.0
var _pitch := 30.0
var _yaw := 0.0


func setup(model: Node3D) -> void:
	_model = model
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_attachment = BoneAttachment3D.new()
	_attachment.bone_name = "hand_R"
	skeleton.add_child(_attachment)
	_holder = Node3D.new()
	_attachment.add_child(_holder)


func show_item(item: ItemData) -> void:
	var id: StringName = item.id if item != null else &""
	if id == _current:
		return
	_current = id
	for c in _holder.get_children():
		c.queue_free()
	if item == null:
		return
	match item.tool_kind:
		&"sword":
			_add_box(Vector3(0.05, 0.9, 0.12), Vector3(0, 0.55, 0), item.color.lightened(0.2))
			_add_box(Vector3(0.28, 0.05, 0.08), Vector3(0, 0.08, 0), Color(0.3, 0.2, 0.12))
			_add_box(Vector3(0.06, 0.2, 0.06), Vector3(0, -0.04, 0), Color(0.3, 0.2, 0.12))
		&"axe":
			_add_box(Vector3(0.05, 0.8, 0.05), Vector3(0, 0.35, 0), Color(0.45, 0.3, 0.18))
			_add_box(Vector3(0.05, 0.22, 0.3), Vector3(0, 0.7, -0.1), item.color)
		&"pickaxe":
			_add_box(Vector3(0.05, 0.8, 0.05), Vector3(0, 0.35, 0), Color(0.45, 0.3, 0.18))
			_add_box(Vector3(0.05, 0.1, 0.6), Vector3(0, 0.72, 0), item.color)
		&"bow":
			_add_box(Vector3(0.04, 0.9, 0.05), Vector3(0, 0.3, 0), item.color)
			_add_box(Vector3(0.02, 0.9, 0.02), Vector3(0, 0.3, 0.14), Color(0.9, 0.9, 0.85))
		_:
			_add_box(Vector3(0.2, 0.2, 0.2), Vector3(0, 0.1, 0), item.color)
	_base_pitch = 90.0 if item.tool_kind == &"bow" else 35.0
	_pitch = _base_pitch
	_yaw = 0.0


## A orientação é calculada no espaço do modelo (e não do osso), então o item sempre
## aponta para a frente do personagem, não importa a pose do braço.
func _process(_delta: float) -> void:
	if _model == null or _holder == null:
		return
	var m := _model.global_basis.orthonormalized()
	var up := m.y
	var fwd := -m.z
	var dir := (fwd * cos(deg_to_rad(_pitch)) + up * sin(deg_to_rad(_pitch))).normalized()
	dir = dir.rotated(up, deg_to_rad(_yaw))
	var x_axis := m.x
	var z_axis := x_axis.cross(dir).normalized()
	x_axis = dir.cross(z_axis).normalized()
	_holder.global_basis = Basis(x_axis, dir, z_axis)


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = MaterialFactory.solid(color)
	_holder.add_child(mi)


## Pequena animação de golpe; varia com o passo do combo (alto, lateral e estocada).
func swing(combo: int) -> void:
	var tw := create_tween()
	match combo % 3:
		0:
			tw.tween_property(self, "_pitch", _base_pitch + 100.0, 0.07)
			tw.tween_property(self, "_pitch", _base_pitch - 55.0, 0.1)
			tw.tween_property(self, "_pitch", _base_pitch, 0.2)
		1:
			tw.tween_property(self, "_yaw", 70.0, 0.07)
			tw.tween_property(self, "_yaw", -70.0, 0.12)
			tw.tween_property(self, "_yaw", 0.0, 0.2)
		2:
			tw.tween_property(self, "_pitch", _base_pitch + 120.0, 0.1)
			tw.tween_property(self, "_pitch", _base_pitch - 70.0, 0.08)
			tw.tween_property(self, "_pitch", _base_pitch, 0.25)
