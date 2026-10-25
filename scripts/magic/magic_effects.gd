class_name MagicEffects
extends RefCounted
## Efeitos das magias sobre o mundo: explosão de fogo, rajada de vento e muralha de terra.


## Explosão: dano em inimigos e fogo em tudo que for inflamável dentro do raio.
static func blast(tree: SceneTree, world: World3D, at: Vector3, radius: float, damage: float, source: Node3D) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = 4 | 8 | 16
	var seen: Dictionary = {}
	for r in world.direct_space_state.intersect_shape(q, 64):
		var c := r["collider"] as Node
		if c == null:
			continue
		if c is Enemy:
			if not seen.has(c):
				seen[c] = true
				(c as Enemy).take_damage(damage, at, 7.0)
				(c as Enemy).burn(Config.f("magic.burn_enemy_seconds", 3.0))
		elif c is ResourceField:
			var f := c as ResourceField
			var i := f.index_from_shape(r["shape"])
			if i >= 0:
				f.ignite_index(i)
		elif c is PlantedTree:
			(c as PlantedTree).ignite()
		else:
			var n: Node = c
			while n != null and not n is BuildPiece:
				n = n.get_parent()
			if n != null and not seen.has(n):
				seen[n] = true
				(n as BuildPiece).ignite()


## Rajada de vento: empurra e fere inimigos num cone à frente.
static func wind_gust(tree: SceneTree, origin: Vector3, forward: Vector3, reach: float, damage: float) -> int:
	var hit := 0
	var flat := Vector3(forward.x, 0, forward.z).normalized()
	for e: Enemy in tree.get_nodes_in_group(&"enemy"):
		var d := e.global_position - origin
		d.y = 0.0
		if d.length() > reach or d.length() < 0.01:
			continue
		if flat.dot(d.normalized()) < cos(deg_to_rad(50.0)):
			continue
		e.take_damage(damage, origin, Config.f("magic.wind_knockback", 15.0))
		hit += 1
	return hit


static func wind_visual(parent: Node, origin: Vector3, forward: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = 0.5
	p.direction = forward
	p.spread = 28.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector3.ZERO
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.15)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(0.85, 0.95, 1.0, 0.7)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = pm
	p.mesh = quad
	parent.add_child(p)
	p.global_position = origin
	p.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Muralha de terra: surge do chão à frente e some depois de alguns segundos.
static func earth_wall(parent: Node, pos: Vector3, yaw: float, lifetime := 15.0) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 16
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 2.6, 0.9)
	shape.shape = box
	shape.position.y = 1.3
	wall.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 2.6, 0.9)
	mi.mesh = bm
	mi.position.y = 1.3
	mi.material_override = MaterialFactory.solid(Color(0.5, 0.4, 0.3))
	wall.add_child(mi)
	parent.add_child(wall)
	wall.global_position = pos + Vector3(0, -2.6, 0)
	wall.rotation.y = yaw
	var tw := wall.create_tween()
	tw.tween_property(wall, "global_position:y", pos.y - 0.2, 0.35)
	tw.tween_interval(lifetime)
	tw.tween_property(wall, "global_position:y", pos.y - 3.0, 0.6)
	tw.tween_callback(wall.queue_free)
	wall.set_meta(&"lifetime", lifetime)
	return wall
