class_name TerrainGenerator
extends RefCounted
## Funções de terreno determinísticas a partir da seed global: altura e bioma em qualquer ponto.

const SPAWN_FLAT_RADIUS := 24.0
const SPAWN_PLAIN_RADIUS := 40.0

var _height: FastNoiseLite
var _detail: FastNoiseLite
var _biome: FastNoiseLite
var _tint: FastNoiseLite


func _init(world_seed: int) -> void:
	_height = _make_noise(world_seed, 0.006, 4)
	_detail = _make_noise(world_seed + 7, 0.045, 2)
	_biome = _make_noise(world_seed + 101, 0.007, 1)
	_tint = _make_noise(world_seed + 202, 0.12, 1)


static func _make_noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed
	n.frequency = frequency
	if octaves > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = octaves
	else:
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
	return n


func height_at(x: float, z: float) -> float:
	var h := _height.get_noise_2d(x, z) * 18.0 + _detail.get_noise_2d(x, z) * 1.1 + 4.0
	var d := Vector2(x, z).length()
	var flat := smoothstep(SPAWN_FLAT_RADIUS, SPAWN_FLAT_RADIUS + 70.0, d)
	return lerpf(2.0, h, flat)


## 0 = planície, 1 = floresta. A área de início é sempre planície.
func forest_amount(x: float, z: float) -> float:
	var f := smoothstep(-0.05, 0.15, _biome.get_noise_2d(x, z))
	return f * smoothstep(SPAWN_PLAIN_RADIUS, SPAWN_PLAIN_RADIUS + 40.0, Vector2(x, z).length())


func is_forest(x: float, z: float) -> bool:
	return forest_amount(x, z) > 0.5


func tint_at(x: float, z: float) -> float:
	return _tint.get_noise_2d(x, z)
