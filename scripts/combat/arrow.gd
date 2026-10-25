class_name Arrow
extends Node3D
## Flecha: projétil com física simples (gravidade) e varredura por raycast para não atravessar alvos.

var velocity := Vector3.ZERO
var damage := 18.0
var shooter: Node3D
var _life := 6.0
var _gravity := 14.0


static func launch(parent: Node, from: Vector3, dir: Vector3, speed: float, dmg: float, who: Node3D) -> Arrow:
	var a := Arrow.new()
	a.velocity = dir.normalized() * speed
	a.damage = dmg
	a.shooter = who
	parent.add_child(a)
	a.global_position = from
	return a


func _ready() -> void:
	_gravity = Config.f("combat.arrow_gravity", _gravity)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.7
	mi.mesh = cyl
	mi.rotation.x = PI / 2.0
	mi.material_override = MaterialFactory.solid(Color(0.85, 0.8, 0.65), MaterialFactory.Hull.NONE)
	add_child(mi)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= _gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8 | 16)
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c := hit["collider"] as Node
		if c != null and c.has_method("take_damage"):
			c.take_damage(damage, from, 4.0)
		queue_free()
		return
	global_position = to
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)
