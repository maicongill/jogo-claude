class_name HitEffect
extends CPUParticles3D
## Lascas que saltam de um recurso (árvore, pedra...) quando ele leva um golpe ou quebra.


static func spawn(parent: Node, pos: Vector3, color: Color, big: bool) -> void:
	var fx := HitEffect.new()
	parent.add_child(fx)
	fx.position = pos
	fx.setup(color, big)


func setup(color: Color, big: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (0.12 if big else 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	self.mesh = mesh
	one_shot = true
	explosiveness = 1.0
	amount = Config.i("visual.hit_fx_chips_break", 22) if big else Config.i("visual.hit_fx_chips", 8)
	lifetime = 0.8 if big else 0.55
	direction = Vector3.UP
	spread = 70.0
	initial_velocity_min = 2.0
	initial_velocity_max = 5.5 if big else 4.0
	gravity = Vector3(0, -14, 0)
	angular_velocity_min = -400.0
	angular_velocity_max = 400.0
	scale_amount_min = 0.6
	scale_amount_max = 1.3
	emitting = true
	finished.connect(queue_free)
