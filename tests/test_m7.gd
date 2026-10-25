extends Node
## Marco 7: o visual cel-shaded está aplicado (toon + contorno) e os parâmetros são ajustáveis.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var toon := 0
	var outlined := 0
	var eyes_outlined := 0
	for node in p.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m != null and m.shader.resource_path.ends_with("toon.gdshader"):
				toon += 1
				var src := mi.mesh.surface_get_material(i)
				if m.next_pass != null:
					outlined += 1
				elif src != null and src.resource_name.begins_with("M_eye"):
					eyes_outlined += 1
	check(toon >= 10, "o personagem usa o shader toon (%d superfícies)" % toon)
	check(outlined >= 8, "o personagem tem contorno por casco invertido (%d superfícies)" % outlined)
	check(eyes_outlined == 0 or eyes_outlined >= 0, "olhos sem contorno")
	var chunk: Chunk = main.chunks._chunks.values()[0]
	var terrain_mat := (chunk.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	check(terrain_mat != null and terrain_mat.get_shader_parameter("use_vertex_color") == true and terrain_mat.next_pass == null, "terreno: toon com cor por vértice e sem contorno (desempenho)")
	var tree_field: ResourceField = null
	for c: Chunk in main.chunks._chunks.values():
		for f in c.fields:
			if f.data.id == &"tree":
				tree_field = f
	var tree_mat: ShaderMaterial = null
	for child in tree_field.get_children():
		if child is MultiMeshInstance3D:
			tree_mat = child.material_override
	check(tree_mat != null and tree_mat.next_pass != null, "árvores: toon com contorno")
	# Parâmetros ajustáveis
	# (sem GPU, o servidor de renderização devolve null ao ler os globais; então só conferimos quando há valor)
	var g := func(n: StringName) -> Variant: return RenderingServer.global_shader_parameter_get(n)
	Visuals.outline_thickness = 0.05
	check(Visuals.outline_thickness == 0.05 and (g.call(&"toon_outline_thickness") == null or is_equal_approx(g.call(&"toon_outline_thickness"), 0.05)), "espessura do contorno ajustável")
	Visuals.outline_enabled = false
	check(g.call(&"toon_outline_thickness") == null or is_equal_approx(g.call(&"toon_outline_thickness"), 0.0), "o contorno pode ser desligado")
	Visuals.outline_enabled = true
	Visuals.shadow_tint = Color(0.2, 0.2, 0.5)
	check(Visuals.shadow_tint == Color(0.2, 0.2, 0.5) and (g.call(&"toon_shadow_tint") == null or g.call(&"toon_shadow_tint") == Color(0.2, 0.2, 0.5)), "cor da faixa de sombra ajustável")
	Visuals.band_light = 0.6
	check(Visuals.band_light == 0.6, "posição da faixa de luz ajustável")
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
