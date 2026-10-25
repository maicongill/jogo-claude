class_name MaterialFactory
extends RefCounted
## Fábrica central de materiais: tudo usa o shader toon, com contorno opcional.

enum Hull { NONE, NORMAL, BOX }

static var _toon: Shader = preload("res://shaders/toon.gdshader")
static var _outline: Shader = preload("res://shaders/toon_outline.gdshader")
static var _hulls: Dictionary = {}


static func toon(color: Color, use_vertex_color := false, hull := Hull.BOX) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_color", use_vertex_color)
	var h := hull_material(hull)
	if h != null:
		m.next_pass = h
	return m


## Cor chapada (formas de caixa usam o contorno em modo "box").
static func solid(color: Color, hull := Hull.BOX) -> ShaderMaterial:
	return toon(color, false, hull)


## Usa a cor por vértice da malha (terreno, árvores...).
static func vertex_color(hull := Hull.NORMAL) -> ShaderMaterial:
	return toon(Color.WHITE, true, hull)


static func hull_material(hull: Hull) -> ShaderMaterial:
	if hull == Hull.NONE:
		return null
	if not _hulls.has(hull):
		var m := ShaderMaterial.new()
		m.shader = _outline
		m.set_shader_parameter("box_mode", hull == Hull.BOX)
		_hulls[hull] = m
	return _hulls[hull]
