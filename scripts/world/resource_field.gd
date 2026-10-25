class_name ResourceField
extends StaticBody3D
## Todas as instâncias de um tipo de recurso (ex.: árvores) de um chunk. As formas são
## desenhadas por um MultiMesh e cada instância tem sua própria colisão.

signal depleted(field: ResourceField, index: int)

var data: ResourceNodeData
var key := ""

var _xforms: Array[Transform3D] = []
var _hp := PackedFloat32Array()
var _shapes: Array[CollisionShape3D] = []
var _mm_full: MultiMesh
var _mm_empty: MultiMesh
var _state: Dictionary
var _check_timer := 0.0
var _burning: Dictionary = {}  # índice -> BurnEffect


func setup(def: ResourceNodeData, chunk_key: String, xforms: Array[Transform3D]) -> void:
	data = def
	key = chunk_key
	_xforms = xforms
	collision_layer = 8  # camada 4: recursos
	collision_mask = 0
	_state = WorldState.resource_state(key)

	_mm_full = _make_multimesh(def.mesh_id)
	if def.respawn_time > 0.0:
		_mm_empty = _make_multimesh(StringName(String(def.mesh_id) + "_empty"))
	_hp.resize(xforms.size())
	for i in xforms.size():
		var xf := xforms[i]
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		var sc := xf.basis.get_scale().x
		cyl.radius = def.radius * sc
		cyl.height = def.height * sc
		shape.shape = cyl
		shape.position = xf.origin + Vector3(0, cyl.height * 0.5, 0)
		shape.set_meta(&"idx", i)
		add_child(shape)
		_shapes.append(shape)
		_hp[i] = def.hits
		var s: Variant = _state.get(i)
		if s != null:
			_hp[i] = s[0]
		_apply_visual(i)


func _make_multimesh(mesh_id: StringName) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = PrimitiveMeshes.get_mesh(mesh_id)
	mm.instance_count = _xforms.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = MaterialFactory.vertex_color()
	add_child(mmi)
	return mm


func _apply_visual(i: int) -> void:
	var dead := _hp[i] <= 0.0
	var xf := _xforms[i]
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
	if _mm_empty != null:
		_mm_full.set_instance_transform(i, hidden if dead else xf)
		_mm_empty.set_instance_transform(i, xf if dead else hidden)
	else:
		_mm_full.set_instance_transform(i, hidden if dead else xf)
	_shapes[i].set_deferred(&"disabled", dead and _mm_empty == null)


func _process(delta: float) -> void:
	if data == null or data.respawn_time <= 0.0:
		return
	_check_timer += delta
	if _check_timer < 1.0:
		return
	_check_timer = 0.0
	for idx: int in _state.keys():
		var s: Array = _state[idx]
		if s[1] >= 0.0 and WorldState.time - s[1] >= data.respawn_time:
			_hp[idx] = data.hits
			_state.erase(idx)
			_apply_visual(idx)


func index_from_shape(shape_idx: int) -> int:
	var owner_id := shape_find_owner(shape_idx)
	var node := shape_owner_get_owner(owner_id) as CollisionShape3D
	return node.get_meta(&"idx", -1) if node else -1


func is_alive(i: int) -> bool:
	return _hp[i] > 0.0


## Quanto dano a ferramenta (ou a mão) causa neste recurso. 0 = não consegue.
func power_for(tool: ItemData) -> float:
	var matches := tool != null and tool.tool_kind == data.tool_kind and tool.tool_kind != &""
	if data.min_tool_level > 0:
		if matches and tool.tool_level >= data.min_tool_level:
			return tool.tool_power
		return 0.0
	if matches:
		return maxf(data.hand_damage, tool.tool_power)
	return data.hand_damage


## Aplica dano a uma instância (pelo índice da shape atingida). Devolve o resultado do golpe.
func damage_shape(shape_idx: int, amount: float, give_drops := true) -> Dictionary:
	return damage_instance(index_from_shape(shape_idx), amount, give_drops)


func damage_instance(i: int, amount: float, give_drops := true) -> Dictionary:
	var result := {"hit": false, "depleted": false, "drops": [], "name": data.display_name}
	if i < 0 or not is_alive(i) or amount <= 0.0:
		return result
	result["hit"] = true
	_hp[i] -= amount
	var s := [_hp[i], -1.0]
	if _hp[i] <= 0.0:
		_hp[i] = 0.0
		result["depleted"] = true
		s = [0.0, WorldState.time if data.respawn_time > 0.0 else -2.0]
		if give_drops:
			result["drops"] = _roll_drops()
		depleted.emit(self, i)
	_state[i] = s
	_apply_visual(i)
	return result


## Põe fogo numa instância inflamável (ex.: árvore). Queima até ser destruída, sem soltar itens.
func ignite_index(i: int) -> void:
	if not data.flammable or i < 0 or not is_alive(i) or _burning.has(i):
		return
	var fx := BurnEffect.new()
	fx.dps = 1.5
	fx.size = 1.6
	add_child(fx)
	fx.position = _xforms[i].origin + Vector3(0, data.height * 0.45, 0)
	_burning[i] = fx
	fx.tick.connect(func(amount: float) -> void:
		var r := damage_instance(i, amount, false)
		if r["depleted"] or not is_alive(i):
			_burning.erase(i)
			fx.queue_free())


func is_burning(i: int) -> bool:
	return _burning.has(i)


func _roll_drops() -> Array:
	var drops: Array = []
	if data.drop_item != null:
		drops.append({"item": data.drop_item, "count": randi_range(data.drop_min, data.drop_max)})
	if data.bonus_item != null and randf() < data.bonus_chance:
		drops.append({"item": data.bonus_item, "count": 1})
	return drops


func world_position_of(i: int) -> Vector3:
	return global_transform * _xforms[i].origin
