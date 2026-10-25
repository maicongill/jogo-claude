class_name MaterialFactory
extends RefCounted
## Fábrica central de materiais. No marco 7 passa a devolver materiais toon.


static func vertex_color(roughness := 1.0) -> Material:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = roughness
	return m


static func solid(color: Color) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
