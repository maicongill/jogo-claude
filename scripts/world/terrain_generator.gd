class_name TerrainGenerator
extends RefCounted
## Funções de terreno determinísticas a partir da seed global: altura e bioma em qualquer ponto.

var spawn_flat_radius := 24.0
var spawn_plain_radius := 40.0
var height_amplitude := 13.0
var detail_amplitude := 0.35

var _height: FastNoiseLite
var _detail: FastNoiseLite
var _biome: FastNoiseLite
var _tint: FastNoiseLite


func _init(world_seed: int) -> void:
	var w := Config.section("world")
	spawn_flat_radius = w.get("spawn_flat_radius", spawn_flat_radius)
	spawn_plain_radius = w.get("spawn_plain_radius", spawn_plain_radius)
	height_amplitude = w.get("height_amplitude", height_amplitude)
	detail_amplitude = w.get("detail_amplitude", detail_amplitude)
	_height = _make_noise(world_seed, w.get("height_frequency", 0.0035), int(w.get("height_octaves", 3)), w.get("height_gain", 0.35))
	_detail = _make_noise(world_seed + 7, w.get("detail_frequency", 0.045), 2)
	_biome = _make_noise(world_seed + 101, w.get("biome_frequency", 0.00233), 1)
	_tint = _make_noise(world_seed + 202, 0.12, 1)


## gain = quanto cada oitava extra pesa (menor = relevo mais suave, sem ondinhas).
static func _make_noise(noise_seed: int, frequency: float, octaves: int, gain := 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed
	n.frequency = frequency
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
		n.fractal_gain = gain
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


func height_at(x: float, z: float) -> float:
	var h := _height.get_noise_2d(x, z) * height_amplitude + _detail.get_noise_2d(x, z) * detail_amplitude + 4.0
	var d := Vector2(x, z).length()
	var flat := smoothstep(spawn_flat_radius, spawn_flat_radius + 70.0, d)
	return lerpf(2.0, h, flat)


## 0 = planície, 1 = floresta. A área de início é sempre planície.
func forest_amount(x: float, z: float) -> float:
	var f := smoothstep(-0.05, 0.15, _biome.get_noise_2d(x, z))
	return f * smoothstep(spawn_plain_radius, spawn_plain_radius + 40.0, Vector2(x, z).length())


func is_forest(x: float, z: float) -> bool:
	return forest_amount(x, z) > 0.5


func tint_at(x: float, z: float) -> float:
	return _tint.get_noise_2d(x, z)
