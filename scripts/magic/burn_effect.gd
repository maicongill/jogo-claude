class_name BurnEffect
extends Node3D
## Chamas sobre algo inflamável. Emite `tick` com o dano a cada intervalo; quem é queimado decide o que fazer.

signal tick(amount: float)

var dps := 2.0
var interval := 0.5
## Segundos até apagar sozinho. <= 0 = queima até o alvo ser destruído.
var duration := -1.0
var size := 1.0

var _t := 0.0
var _life := 0.0


func _ready() -> void:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45 * size
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.1 * size
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.25, 1.0))
	ramp.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	p.color_ramp = ramp
	add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 5.0
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	_life += delta
	while _t >= interval:
		_t -= interval
		tick.emit(dps * interval)
	if duration > 0.0 and _life >= duration:
		queue_free()
