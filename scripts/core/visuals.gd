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


func _enter_tree() -> void:
	# Os globais precisam existir antes de qualquer shader que os usa ser carregado.
	_add(&"toon_outline_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, outline_color)
	_add(&"toon_outline_thickness", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, outline_thickness)
	_add(&"toon_shadow_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, shadow_tint)
	_add(&"toon_mid_tint", RenderingServer.GLOBAL_VAR_TYPE_COLOR, mid_tint)
	_add(&"toon_band_light", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, band_light)
	_add(&"toon_softness", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, softness)
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


func _add(name: StringName, type: RenderingServer.GlobalShaderParameterType, value: Variant) -> void:
	RenderingServer.global_shader_parameter_add(name, type, value)


func _apply_outline() -> void:
	RenderingServer.global_shader_parameter_set(&"toon_outline_thickness", outline_thickness if outline_enabled else 0.0)
