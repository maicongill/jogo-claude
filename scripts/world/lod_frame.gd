class_name LodFrame
extends RefCounted
## Enquadramento de um impostor: um quadrado de lado `size` (metros) com a base em `bottom`
## (altura local do modelo). Usado igual ao gerar as imagens e ao desenhá-las no mundo.

var size := 1.0
var bottom := 0.0


static func of(mesh: Mesh) -> LodFrame:
	var a := mesh.get_aabb()
	var f := LodFrame.new()
	f.size = maxf(a.size.y, maxf(a.size.x, a.size.z)) * 1.08
	f.bottom = a.position.y - f.size * 0.02
	return f
