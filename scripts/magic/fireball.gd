class_name Fireball
extends Node3D
## Bola de fogo: voa em linha quase reta e explode ao tocar em algo, queimando o que for inflamável.

var velocity := Vector3.ZERO
var damage := 25.0
var radius := 2.5
var shooter: Node3D
var _life := 4.0


static func launch(parent: Node, from: Vector3, dir: Vector3, speed: float, dmg: float, blast_radius: float, who: Node3D) -> Fireball:
	var f := Fireball.new()
	f.velocity = dir.normalized() * speed
	f.damage = dmg
	f.radius = blast_radius
	f.shooter = who
	parent.add_child(f)
	f.global_position = from
	return f


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.28
	s.height = 0.56
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.15)
	mi.material_override = m
	add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 6.0
	add_child(light)
	var trail := CPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.4
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(1.0, 0.45, 0.1, 0.8)
	quad.material = pm
	trail.mesh = quad
	add_child(trail)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= 2.0 * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		explode(hit["position"])
		return
	global_position = to


func explode(at: Vector3) -> void:
	MagicEffects.blast(get_tree(), get_world_3d(), at, radius, damage, shooter)
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 40
	burst.lifetime = 0.6
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 6.0
	burst.spread = 180.0
	burst.gravity = Vector3(0, -2, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.albedo_color = Color(1.0, 0.55, 0.15)
	quad.material = pm
	burst.mesh = quad
	get_parent().add_child(burst)
	burst.global_position = at
	burst.emitting = true
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	queue_free()
