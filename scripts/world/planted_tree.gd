class_name PlantedTree
extends StaticBody3D
## Muda plantada pelo jogador. Depois de algum tempo vira uma árvore coletável.

@export var grow_time := 60.0

var data: ResourceNodeData
var grown := false
var planted_at := 0.0

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _hp := 0.0
var _fire: BurnEffect


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	planted_at = WorldState.time
	for d in Database.resource_nodes:
		if d.id == &"tree":
			data = d
	_mesh = MeshInstance3D.new()
	_mesh.mesh = PrimitiveMeshes.get_mesh(&"sapling")
	_mesh.material_override = MaterialFactory.vertex_color()
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 0.8
	_shape.shape = cyl
	_shape.position.y = 0.4
	add_child(_shape)


func _process(_delta: float) -> void:
	if grown:
		return
	var t := (WorldState.time - planted_at) / grow_time
	if t >= 1.0:
		_grow()
	else:
		_mesh.scale = Vector3.ONE * lerpf(0.7, 1.6, t)


func _grow() -> void:
	grown = true
	_hp = data.hits
	_mesh.mesh = PrimitiveMeshes.get_mesh(&"tree")
	_mesh.scale = Vector3.ONE
	var cyl := _shape.shape as CylinderShape3D
	cyl.radius = data.radius
	cyl.height = data.height
	_shape.position.y = data.height * 0.5


func power_for(tool: ItemData) -> float:
	if not grown:
		return 0.0
	var matches := tool != null and tool.tool_kind == data.tool_kind
	return maxf(data.hand_damage, tool.tool_power) if matches else data.hand_damage


func damage_shape(_shape_idx: int, amount: float, give_drops := true) -> Dictionary:
	var result := {"hit": false, "depleted": false, "drops": [], "name": data.display_name}
	if not grown or amount <= 0.0:
		return result
	result["hit"] = true
	_hp -= amount
	if _hp <= 0.0:
		result["depleted"] = true
		if give_drops:
			result["drops"] = [{"item": data.drop_item, "count": randi_range(data.drop_min, data.drop_max)}]
			if data.bonus_item != null and randf() < data.bonus_chance:
				result["drops"].append({"item": data.bonus_item, "count": 1})
		queue_free()
	return result


func ignite() -> void:
	if not grown or _fire != null:
		return
	_fire = BurnEffect.new()
	_fire.dps = 1.5
	_fire.size = 1.6
	add_child(_fire)
	_fire.position.y = data.height * 0.45
	_fire.tick.connect(func(amount: float) -> void: damage_shape(0, amount, false))
