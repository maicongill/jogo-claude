extends Node
## Gera as imagens (impostores) usadas para desenhar árvores, pedras e arbustos de longe, a partir
## dos próprios modelos 3D, com o mesmo visual cel-shaded do jogo. Precisa de janela/GPU:
##   godot --path . --rendering-driver opengl3 res://tools/bake_impostors.tscn
## Saída: assets/impostors/{tree,rock,bush}.png, atlas.png (as três lado a lado, para desenhar
## tudo de uma vez) e impostors.json (enquadramento e coluna de cada uma no atlas).

const OUT := "res://assets/impostors/"
const RES := 256
const IDS: Array[StringName] = [&"tree", &"rock", &"bush"]


func _ready() -> void:
	var info := {}
	var atlas := Image.create(RES * IDS.size(), RES, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for k in IDS.size():
		var id := IDS[k]
		var mesh := PrimitiveMeshes.get_mesh(id)
		var frame := LodFrame.of(mesh)
		var img := await _render(mesh, frame)
		img.save_png(ProjectSettings.globalize_path(OUT + String(id) + ".png"))
		atlas.blit_rect(img, Rect2i(0, 0, RES, RES), Vector2i(k * RES, 0))
		info[String(id)] = {"size": frame.size, "bottom": frame.bottom, "column": k}
		print("impostor: ", id, " ", frame.size, " m")
	atlas.save_png(ProjectSettings.globalize_path(OUT + "atlas.png"))
	info["_columns"] = IDS.size()
	var f := FileAccess.open(OUT + "impostors.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t"))
	f.close()
	print("impostores gerados em ", OUT)
	get_tree().quit()


func _render(mesh: Mesh, frame: LodFrame) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(RES, RES)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.95)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(4, 6, 6), Vector3.ZERO)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MaterialFactory.vertex_color(MaterialFactory.Hull.NORMAL)
	vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = frame.size
	cam.position = Vector3(0, frame.bottom + frame.size * 0.5, 20)
	vp.add_child(cam)
	cam.current = true
	for _i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img
