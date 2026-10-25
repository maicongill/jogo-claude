extends Node
## Tira uma captura do jogo (precisa de janela/GPU). Uso:
## godot --path . res://tools/screenshot.tscn -- x z yaw_graus pitch_graus arquivo.png [segundos_extra] [inv]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var x := float(args[0]); var z := float(args[1])
	var yaw := float(args[2]); var pitch := float(args[3])
	var out := args[4]
	var extra := float(args[5]) if args.size() > 5 else 0.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var frames := 0
	while main.player.frozen and frames < 2000:
		await get_tree().process_frame
		frames += 1
	var p: Player = main.player
	p.global_position = Vector3(x, main.chunks.height_at(x, z) + 1.0, z)
	p.get_node("CameraPivot").rotation.y = deg_to_rad(yaw)
	p.get_node("CameraPivot/SpringArm3D").rotation.x = deg_to_rad(pitch)
	if args.size() > 6 and args[6] == "inv":
		main.hud._inventory_panel.toggle()
	await get_tree().create_timer(2.5 + extra).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("captura salva: ", out)
	get_tree().quit()
