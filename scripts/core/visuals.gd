extends Node
## Parâmetros globais do visual cel-shaded (shader toon + contorno). Tudo ajustável em tempo de execução.

var outline_enabled := true:
	set(v):
		outline_enabled = v
		_apply_outline()

var outline_thickness := 0.03:
	set(v):
		outline_thickness = v
		_apply_outline()

var outline_color := Color(0.09, 0.08, 0.14):
	set(v):
		outline_color = v
		RenderingServer.global_shader_parameter_set(&"toon_outline_color", v)

## Cores das faixas de luz: multiplicam a cor do material.
var shadow_tint := Color(0.45, 0.48, 0.68):
	set(v):
		shadow_tint = v
		RenderingServer.global_shader_parameter_set(&"toon_shadow_tint", v)

var mid_tint := Color(0.78, 0.80, 0.92):
	set(v):
		mid_tint = v
		RenderingServer.global_shader_parameter_set(&"toon_mid_tint", v)

## Onde começa a faixa mais clara (0 a 1) e quão dura é a borda entre faixas.
var band_light := 0.45:
	set(v):
		band_light = v
		RenderingServer.global_shader_parameter_set(&"toon_band_light", v)

var softness := 0.03:
	set(v):
		softness = v
		RenderingServer.global_shader_parameter_set(&"toon_softness", v)

## Raio (m) do "buraco" aberto nos objetos que tampam o personagem.
var camera_fade_enabled := true
var camera_fade_radius := 1.3


func _enter_tree() -> void:
	# Os globais precisam existir antes de qualquer shader que os usa ser carregado.
	_add(&"toon_outline_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, outline_color)
	_add(&"toon_outline_thickness", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, outline_thickness)
	_add(&"toon_shadow_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, shadow_tint)
	_add(&"toon_mid_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, mid_tint)
	_add(&"toon_band_light", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, band_light)
	_add(&"toon_softness", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, softness)
	_add(&"cam_fade_from", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	_add(&"cam_fade_to", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	_add(&"cam_fade_radius", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	for n in [&"lod_near_start", &"lod_near_end", &"lod_far_start", &"lod_far_end"]:
		_add(n, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	apply_config()
	Config.reloaded.connect(apply_config)


## Lê a seção "visual" de config/game_config.json.
func apply_config() -> void:
	var v := Config.section("visual")
	outline_enabled = v.get("outline_enabled", outline_enabled)
	outline_thickness = v.get("outline_thickness", outline_thickness)
	outline_color = Config.to_color(v.get("outline_color"), outline_color)
	shadow_tint = Config.to_color(v.get("shadow_tint"), shadow_tint)
	mid_tint = Config.to_color(v.get("mid_tint"), mid_tint)
	band_light = v.get("band_light", band_light)
	softness = v.get("softness", softness)
	camera_fade_enabled = v.get("camera_fade_enabled", camera_fade_enabled)
	camera_fade_radius = v.get("camera_fade_radius", camera_fade_radius)
	# Faixas de troca de detalhe (seção "lod"). Desligado = 0 (nada some por distância).
	var lod := Config.section("lod")
	var on: bool = lod.get("enabled", true)
	RenderingServer.global_shader_parameter_set(&"lod_near_start", lod.get("near_fade_start", 130.0) if on else 0.0)
	RenderingServer.global_shader_parameter_set(&"lod_near_end", lod.get("near_fade_end", 160.0) if on else 0.0)
	RenderingServer.global_shader_parameter_set(&"lod_far_start", lod.get("far_fade_start", 500.0) if on else 1e9)
	RenderingServer.global_shader_parameter_set(&"lod_far_end", lod.get("far_fade_end", 580.0) if on else 1e9)


## Chamado pelo jogador a cada quadro: objetos de cenário entre esses dois pontos ficam pontilhados.
func set_camera_fade(camera_pos: Vector3, target_pos: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(&"cam_fade_from", camera_pos)
	RenderingServer.global_shader_parameter_set(&"cam_fade_to", target_pos)
	RenderingServer.global_shader_parameter_set(&"cam_fade_radius", camera_fade_radius if camera_fade_enabled else 0.0)


func _add(name: StringName, type: RenderingServer.GlobalShaderParameterType, value: Variant) -> void:
	RenderingServer.global_shader_parameter_add(name, type, value)


func _apply_outline() -> void:
	RenderingServer.global_shader_parameter_set(&"toon_outline_thickness", outline_thickness if outline_enabled else 0.0)
