extends Node
## Gera as imagens (impostores) usadas para desenhar árvores, pedras e arbustos de longe, a partir
## dos próprios modelos 3D, com o mesmo visual cel-shaded do jogo. Também gera a silhueta das
## manchas de floresta distantes. Precisa de janela/GPU:
##   godot --path . --rendering-driver opengl3 res://tools/bake_impostors.tscn
## Saída: assets/impostors/{tree,rock,bush}.png, cluster.png e impostors.json (enquadramento).

const OUT := "res://assets/impostors/"
const RES := 256
const IDS: Array[StringName] = [&"tree", &"rock", &"bush"]


func _ready() -> void:
	var info := {}
	for id in IDS:
		var mesh := PrimitiveMeshes.get_mesh(id)
		var frame := LodFrame.of(mesh)
		var img := await _render(mesh, frame)
		img.save_png(ProjectSettings.globalize_path(OUT + String(id) + ".png"))
		info[String(id)] = {"size": frame.size, "bottom": frame.bottom}
		print("impostor: ", id, " ", frame.size, " m")
	_cluster_silhouette().save_png(ProjectSettings.globalize_path(OUT + "cluster.png"))
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


## Silhueta branca de várias copas juntas (a cor sólida vem de cada mancha, no jogo).
func _cluster_silhouette() -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var blobs := [[0.5, 0.42, 0.30], [0.30, 0.55, 0.22], [0.70, 0.55, 0.22], [0.42, 0.30, 0.20], [0.60, 0.28, 0.20], [0.5, 0.68, 0.24]]
	for y in RES:
		for x in RES:
			var u := (x + 0.5) / RES
			var v := (y + 0.5) / RES
			var inside := 0.0
			for b in blobs:
				var d: float = Vector2(u - b[0], v - b[1]).length() / b[2]
				inside = maxf(inside, 1.0 - smoothstep(0.92, 1.0, d))
			if inside > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, inside))
	return img
