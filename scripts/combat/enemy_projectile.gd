class_name EnemyProjectile
extends Node3D
## Cuspe do cuspidor: bola lenta que voa reto (com um pouco de gravidade) e fere o jogador ou o pet.

var velocity := Vector3.ZERO
var damage := 10.0
var knockback := 5.0
var shooter: Node3D
var _life := 4.0


static func launch(parent: Node, from: Vector3, dir: Vector3, speed: float, dmg: float, kb: float, who: Node3D) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	p.velocity = dir.normalized() * speed
	p.damage = dmg
	p.knockback = kb
	p.shooter = who
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	add_to_group(&"enemy_projectile")
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.95, 0.35)
	mi.material_override = mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= 2.0 * delta
	var from := global_position
	var to := from + velocity * delta
	# Terreno, jogador, construções e pet (o inimigo que cuspiu não conta).
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 16 | 64)
	if shooter is CollisionObject3D and is_instance_valid(shooter):
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c := hit["collider"] as Node
		if c != null and c.has_method("take_hit"):
			c.take_hit(damage, from, knockback)
		elif c != null and c is FlyingPet:
			c.take_damage(damage, from, knockback)
		queue_free()
		return
	global_position = to
