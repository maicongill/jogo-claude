extends Node
## Captura do menu inicial com dois mundos de exemplo (numa pasta temporária, sem mexer nos mundos
## do jogador). godot --path . --rendering-driver opengl3 res://tools/menu_screenshot.tscn -- saida.png

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	Worlds.root = "user://worlds_screenshot/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Worlds.root))
	for w in Worlds.list():
		Worlds.delete(w["id"])
	Worlds.create("Floresta do Norte", "12345")
	Worlds.create("Ilha das Pedras", "")
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for _i in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("captura salva: ", out)
	for w in Worlds.list():
		Worlds.delete(w["id"])
	get_tree().quit()
