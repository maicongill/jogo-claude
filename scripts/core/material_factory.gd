class_name MaterialFactory
extends RefCounted
## Fábrica central de materiais: tudo usa o shader toon, com contorno opcional.

enum Hull { NONE, NORMAL, BOX }

static var _toon: Shader = preload("res://shaders/toon.gdshader")
static var _outline: Shader = preload("res://shaders/toon_outline.gdshader")
static var _hulls: Dictionary = {}


static func toon(color: Color, use_vertex_color := false, hull := Hull.BOX, occluder := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_color", use_vertex_color)
	m.set_shader_parameter("fade_occluder", occluder)
	var h := hull_material(hull, occluder)
	if h != null:
		m.next_pass = h
	return m


## Cor chapada (formas de caixa usam o contorno em modo "box").
static func solid(color: Color, hull := Hull.BOX, occluder := false) -> ShaderMaterial:
	return toon(color, false, hull, occluder)


## Usa a cor por vértice da malha (terreno, árvores...).
static func vertex_color(hull := Hull.NORMAL, occluder := false) -> ShaderMaterial:
	return toon(Color.WHITE, true, hull, occluder)


## Objetos de cenário (árvores, pedras, móveis...) ficam pontilhados quando tampam o personagem.
static func scenery(color: Color, hull := Hull.BOX) -> ShaderMaterial:
	return toon(color, false, hull, true)


static func hull_material(hull: Hull, occluder := false) -> ShaderMaterial:
	if hull == Hull.NONE:
		return null
	var key := Vector2i(hull, int(occluder))
	if not _hulls.has(key):
		var m := ShaderMaterial.new()
		m.shader = _outline
		m.set_shader_parameter("box_mode", hull == Hull.BOX)
		m.set_shader_parameter("fade_occluder", occluder)
		_hulls[key] = m
	return _hulls[key]
