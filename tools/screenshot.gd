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
	if args.size() > 6 and args[6] == "house":
		p.inventory.add(Database.item(&"wood"), 200)
		var b: BuildSystem = main.build
		var fl := b.place(b.pieces_data[0], b.compute_target(Vector3(x + 6, 0, z + 2) + Vector3(0, main.chunks.height_at(x + 6, z + 2), 0)))
		var fp := fl.global_position
		for i in 4:
			var d: Vector3 = [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)][i]
			var idx := 2 if i == 3 else 1
			b.place(b.pieces_data[idx], b.compute_target(fp + d + Vector3(0, 1.4, 0), idx))
		b.place(b.pieces_data[3], b.compute_target(fp + Vector3(0, 3.2, 0), 3))
		b.set_active(true)
	if args.size() > 6 and args[6] == "house2":
		# Casa com porta, janelas, vigas nos cantos, telhado e vasos de flores no peitoril.
		p.inventory.add(Database.item(&"wood"), 64)
		p.inventory.add(Database.item(&"wood"), 64)
		p.inventory.add(Database.item(&"stone"), 64)
		var b2: BuildSystem = main.build
		var ids := {}
		for i in b2.pieces_data.size():
			ids[b2.pieces_data[i].id] = i
		var put := func(id: StringName, at: Vector3) -> BuildPiece:
			b2.select(ids[id])
			var t := b2.compute_target(at)
			return b2.place(b2.pieces_data[ids[id]], t) if t.get("valid", false) else null
		var c := Vector3(x + 7, 0, z - 1)
		c.y = main.chunks.height_at(c.x, c.z)
		var fl2: BuildPiece = put.call(&"floor", c)
		var fp2 := fl2.global_position
		put.call(&"window", fp2 + Vector3(-2, 1.4, 0))
		put.call(&"door", fp2 + Vector3(0, 1.4, 2))
		put.call(&"window", fp2 + Vector3(0, 1.4, -2))
		put.call(&"wall", fp2 + Vector3(2, 1.4, 0))
		for cc in [Vector3(2, 0, 2), Vector3(-2, 0, 2), Vector3(2, 0, -2), Vector3(-2, 0, -2)]:
			put.call(&"beam", fp2 + cc + Vector3(0, 1.4, 0))
		put.call(&"roof", fp2 + Vector3(0, 3.2, 0))
		for k in 2:
			var pot := Placeables.create(&"flower_pot")
			fl2.add_child(pot)
			pot.global_position = fp2 + Vector3(-1.4, PieceGeometry.SLAB_THICKNESS, -1.0 + k * 2.0)
		b2.select(0)
	if args.size() > 6 and args[6] in ["sword", "bow", "axe"]:
		var item_id: StringName = {"sword": &"wooden_sword", "bow": &"bow", "axe": &"wooden_axe"}[args[6]]
		p.inventory.add(Database.item(item_id))
		p.select_slot(0)
		p.face_direction(Vector3(1, 0, 0.2))
		var e := Enemy.new()
		main.add_child(e)
		e.global_position = p.global_position + Vector3(3, 0.3, 1.0)
		e.sight_range = 0.0
	if args.size() > 6 and args[6] == "fire":
		var best_d := 1e9
		var best_f: ResourceField
		var best_i := 0
		for chunk: Chunk in main.chunks._chunks.values():
			for f in chunk.fields:
				if f.data.id != &"tree":
					continue
				for i in f._xforms.size():
					var d: float = f.world_position_of(i).distance_to(p.global_position + p.get_node("CameraPivot").global_basis.z * -6.0)
					if f.is_alive(i) and d < best_d:
						best_d = d
						best_f = f
						best_i = i
		best_f.ignite_index(best_i)
		p.magic.learn(&"fireball")
		p.magic.cast()
	if args.size() > 6 and args[6] == "pet":
		var pet: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + p.get_node("CameraPivot").global_basis.z * -5.0)
		pet.trust = 20.0
		pet.knows_food = true
		pet._update_label()
		pet._timer = 100000.0
	if args.size() > 6 and (args[6] == "follow" or args[6] == "ride"):
		# Pet domado, começando bem atrás do jogador (entre ele e a câmera).
		var pet2: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + p.get_node("CameraPivot").global_basis.z * 2.5 + Vector3.UP * 1.5)
		pet2.add_trust(100.0)
		pet2.saddled = true
		pet2._player = p
		if args[6] == "ride":
			pet2.mount(p)
		else:
			pet2.state = FlyingPet.State.FOLLOW
	if args.size() > 6 and args[6] == "ghost":
		# Cama na mão, olhando para o chão: mostra o fantasma.
		p.inventory.slots[0] = ItemStack.new(Database.item(&"bed"), 1)
		p.inventory.changed.emit()
		p.select_slot(0)
	if args.size() > 6 and args[6] == "spitter":
		# Um inimigo de cada tipo na frente do jogador, já feridos (mostra a vida sobre a cabeça).
		var fwd: Vector3 = -(p.get_node("CameraPivot") as Node3D).global_basis.z
		var k := 0
		for t in [&"saltilho", &"cuspidor", &"musgolho"]:
			var en := Enemy.new()
			en.type_id = t
			main.add_child(en)
			var at: Vector3 = p.global_position + fwd * 6.0 + p.get_node("CameraPivot").global_basis.x * (k - 1) * 3.0
			at.y = main.chunks.height_at(at.x, at.z) + 0.5
			en.global_position = at
			en.sight_range = 0.0
			en.take_damage(5.0, p.global_position, 0.0)
			k += 1
	if args.size() > 6 and args[6] == "sky":
		# Montado no pássaro bem alto, para ver a distância de renderização.
		var sky_pet: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + Vector3(2, 0, 0))
		sky_pet.add_trust(100.0)
		sky_pet.saddled = true
		sky_pet._player = p
		sky_pet.mount(p)
		sky_pet.global_position.y += 70.0
		await get_tree().create_timer(extra).timeout
		print("blocos médios: ", main.far_world.tile_count(false), " longes: ", main.far_world.tile_count(true))
	if args.size() > 6 and args[6] == "inv":
		main.hud._inventory_panel.toggle()
	await get_tree().create_timer(2.5 + extra).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("captura salva: ", out)
	get_tree().quit()
