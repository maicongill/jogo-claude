class_name Placeables
extends RefCounted
## Fábrica dos objetos colocáveis (cama, mesa de magia, estábulo...).


static func create(place_id: StringName) -> Node3D:
	match place_id:
		&"bed":
			return Bed.new()
		&"magic_table":
			return MagicTable.new()
		&"stable":
			return Stable.new()
		&"flower_pot":
			return FlowerPot.new()
	return null


## Objetos que podem ficar em cima de qualquer superfície (pisos, mesas...), não só no terreno.
static func on_any_surface(place_id: StringName) -> bool:
	return place_id == &"flower_pot"


## Versão "fantasma" (só a aparência, translúcida, sem colisão nem efeito no jogo) para mostrar
## onde o objeto vai ser colocado. O chamador adiciona à cena e depois chama finish_ghost().
static func create_ghost(place_id: StringName) -> Node3D:
	var node := create(place_id)
	if node != null:
		node.set_meta(&"ghost", true)
	return node


static func finish_ghost(node: Node3D, material: Material) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
	for g in node.get_groups():
		node.remove_from_group(g)
	for c in node.find_children("*", "", true, false):
		if c is CollisionShape3D:
			c.queue_free()
		elif c is MeshInstance3D:
			(c as MeshInstance3D).material_override = material
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		frame.material_override = MaterialFactory.scenery(Color(0.5, 0.33, 0.2))
		add_child(frame)
		var mattress := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.9, 0.2, 1.9)
		mattress.mesh = mm
		mattress.position.y = 0.4
		mattress.material_override = MaterialFactory.scenery(Color(0.85, 0.4, 0.4))
		add_child(mattress)
		var pillow := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.7, 0.14, 0.4)
		pillow.mesh = pm
		pillow.position = Vector3(0, 0.55, 0.7)
		pillow.material_override = MaterialFactory.scenery(Color(0.95, 0.93, 0.85))
		add_child(pillow)

	func interact(player: Player) -> void:
		Game.spawn_point = global_position + Vector3(0, 0.6, 0) + global_basis.x * 1.4
		EventBus.message.emit("Cama definida como seu ponto de renascimento.")


class MagicTable extends StaticBody3D:
	func _ready() -> void:
		collision_layer = 16
		add_to_group(&"magic_table")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.4, 1.0, 1.0)
		shape.shape = box
		shape.position.y = 0.5
		add_child(shape)
		var top := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(1.4, 0.15, 1.0)
		top.mesh = tm
		top.position.y = 0.95
		top.material_override = MaterialFactory.scenery(Color(0.45, 0.3, 0.7))
		add_child(top)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var leg := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(0.14, 0.9, 0.14)
				leg.mesh = lm
				leg.position = Vector3(0.58 * sx, 0.45, 0.38 * sz)
				leg.material_override = MaterialFactory.scenery(Color(0.35, 0.25, 0.2))
				add_child(leg)
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.16
		om.height = 0.32
		orb.mesh = om
		orb.position.y = 1.2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.7, 0.55, 1.0)
		orb.material_override = mat
		add_child(orb)

	func interact(_player: Player) -> void:
		EventBus.magic_table_opened.emit(self)

	## Transforma os ingredientes em um pergaminho. Devolve false se faltar algo ou espaço.
	static func craft_scroll(inv: Inventory, recipe: ScrollRecipeData) -> bool:
		if not inv.has_items(recipe.inputs, recipe.input_counts):
			return false
		var snapshot: Array[ItemStack] = []
		for s in inv.slots:
			snapshot.append(s.duplicate_stack() if s != null else null)
		for i in recipe.inputs.size():
			inv.remove(recipe.inputs[i], recipe.input_counts[i])
		if not inv.can_add(recipe.scroll, 1):
			inv.slots.assign(snapshot)
			inv.changed.emit()
			return false
		inv.add(recipe.scroll, 1)
		return true


class Stable extends StaticBody3D:
	func _ready() -> void:
		collision_layer = 16
		add_to_group(&"stable")
		var wood := Color(0.62, 0.45, 0.28)
		var parts := [
			[Vector3(3.6, 0.15, 3.6), Vector3(0, 0.075, 0), wood.darkened(0.1)],       # piso
			[Vector3(3.6, 2.2, 0.2), Vector3(0, 1.1, -1.7), wood],                      # fundo
			[Vector3(0.2, 2.2, 3.4), Vector3(-1.7, 1.1, 0), wood],                      # lateral
			[Vector3(0.2, 2.2, 3.4), Vector3(1.7, 1.1, 0), wood],                       # lateral
			[Vector3(4.0, 0.2, 4.0), Vector3(0, 2.3, 0), Color(0.62, 0.3, 0.24)],       # telhado
		]
		for p in parts:
			var size: Vector3 = p[0]
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			shape.position = p[1]
			add_child(shape)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size
			mi.mesh = bm
			mi.position = p[1]
			mi.material_override = MaterialFactory.scenery(p[2])
			add_child(mi)
		# Registra depois de a posição ser definida pelo código que colocou o estábulo.
		await get_tree().process_frame
		if not has_meta(&"ghost"):
			Game.stables.append(global_position)

	func interact(_player: Player) -> void:
		EventBus.message.emit("Estábulo: seu pet renasce aqui se morrer.")


## Vaso de flores: decoração. Fica preso à peça onde foi colocado (some se ela cair).
class FlowerPot extends StaticBody3D:
	func _ready() -> void:
		collision_layer = 16
		add_to_group(&"flower_pot")
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.22
		cyl.height = 0.35
		shape.shape = cyl
		shape.position.y = 0.175
		add_child(shape)
		var pot := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.22
		pm.bottom_radius = 0.16
		pm.height = 0.35
		pm.radial_segments = 10
		pot.mesh = pm
		pot.position.y = 0.175
		pot.material_override = MaterialFactory.scenery(Color(0.72, 0.36, 0.22), MaterialFactory.Hull.NORMAL)
		add_child(pot)
		var leaves := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.2
		lm.height = 0.3
		lm.radial_segments = 8
		lm.rings = 4
		leaves.mesh = lm
		leaves.position.y = 0.42
		leaves.material_override = MaterialFactory.scenery(Color(0.25, 0.62, 0.25), MaterialFactory.Hull.NORMAL)
		add_child(leaves)
		var colors := [Color(0.95, 0.35, 0.45), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0)]
		for i in 3:
			var flower := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.07
			fm.height = 0.12
			fm.radial_segments = 6
			fm.rings = 3
			flower.mesh = fm
			var a := TAU * i / 3.0
			flower.position = Vector3(cos(a) * 0.11, 0.56, sin(a) * 0.11)
			flower.material_override = MaterialFactory.scenery(colors[i], MaterialFactory.Hull.NONE)
			add_child(flower)
