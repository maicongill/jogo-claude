extends Node
## Ajuste 1 (Etapa 6): voo suave, manobras (mergulho, subida em arco, planar), pouso suave e alforje.

var failures := 0
var p: Player
var pet: FlyingPet


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func hold(actions: Array, secs: float) -> void:
	for a in actions:
		Input.action_press(a)
	await get_tree().create_timer(secs).timeout
	for a in actions:
		Input.action_release(a)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	p = main.player
	while p.frozen:
		await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await get_tree().process_frame
	pet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + Vector3(2, 0, 0))
	pet.add_trust(100.0)
	pet.saddled = true
	pet._player = p
	pet.mount(p)
	await get_tree().process_frame

	# Decolagem suave: sobe sem pulo brusco.
	var y0 := pet.global_position.y
	Input.action_press(&"jump")
	await get_tree().physics_frame
	await get_tree().process_frame
	var first_step := pet.global_position.y - y0
	await get_tree().create_timer(2.5).timeout
	Input.action_release(&"jump")
	check(first_step < 0.2, "decolagem começa suave (%.2f m no 1º quadro)" % first_step)
	check(pet.global_position.y - y0 > 6.0, "sobe (%.1f m)" % (pet.global_position.y - y0))

	# Aceleração gradual.
	Input.action_press(&"move_forward")
	await get_tree().create_timer(0.25).timeout
	var s_early := pet.air_speed
	await get_tree().create_timer(1.5).timeout
	var s_late := pet.air_speed
	check(s_early < s_late * 0.6 and s_late > pet.data.fly_speed * 0.9, "acelera aos poucos (%.1f -> %.1f m/s)" % [s_early, s_late])

	# Curva: o pet inclina (banking).
	var pivot := p.get_node("CameraPivot") as Node3D
	pivot.rotate_y(1.2)
	var max_bank := 0.0
	for _i in 40:
		await get_tree().process_frame
		max_bank = maxf(max_bank, absf(pet._body.rotation.z))
	check(max_bank > 0.15, "inclina ao curvar (%.2f rad)" % max_bank)

	# Mergulho: ganha velocidade além do voo rápido, sem gastar estamina.
	await hold([&"jump"], 2.0)  # ganha altura
	var st0 := pet.stamina
	var fov0 := p.camera.fov
	Input.action_press(&"crouch")
	await get_tree().create_timer(2.0).timeout
	Input.action_release(&"crouch")
	var dive_speed := pet.air_speed
	check(dive_speed > pet.data.fast_speed, "mergulho ganha velocidade (%.1f m/s > %.1f)" % [dive_speed, pet.data.fast_speed])
	check(pet.stamina >= st0 - 0.01, "mergulho não gasta estamina")
	check(p.camera.fov > fov0 + 4.0, "campo de visão abre com a velocidade (%.0f -> %.0f)" % [fov0, p.camera.fov])

	# Subida em arco: logo depois do mergulho, Espaço troca embalo por altura (mais rápido que a subida normal).
	var ya := pet.global_position.y
	await hold([&"jump"], 1.0)
	var arc_gain := pet.global_position.y - ya
	check(pet.air_speed < dive_speed - 2.0, "subida em arco gasta o embalo (%.1f -> %.1f m/s)" % [dive_speed, pet.air_speed])
	var yb := pet.global_position.y
	await hold([&"jump"], 1.0)
	var normal_gain := pet.global_position.y - yb
	check(arc_gain > normal_gain * 1.2, "subida em arco sobe mais que a normal (%.1f m vs %.1f m)" % [arc_gain, normal_gain])

	# Planar: desce devagar e recupera estamina.
	pet.stamina = 50.0
	await hold([&"jump"], 1.5)
	pet.stamina = 30.0
	Input.action_press(&"dodge")
	await get_tree().create_timer(1.5).timeout
	var glide_vy := pet.velocity.y
	var stam_glide := pet.stamina
	await get_tree().create_timer(1.0).timeout
	Input.action_release(&"dodge")
	check(glide_vy < -0.3 and glide_vy > -2.5, "planar desce devagar (%.1f m/s)" % glide_vy)
	check(pet.stamina > stam_glide, "planar recupera estamina")
	Input.action_release(&"move_forward")

	# Pouso suave: perto do chão a descida freia.
	Input.action_press(&"crouch")
	var min_vy_near_ground := 0.0
	for _i in 600:
		await get_tree().physics_frame
		var h: float = pet.global_position.y - pet._ground_y()
		if h < 0.6:
			min_vy_near_ground = minf(min_vy_near_ground, pet.velocity.y)
		if h <= 0.36:
			break
	Input.action_release(&"crouch")
	check(pet.global_position.y - pet._ground_y() < 0.5, "pousou")
	check(min_vy_near_ground > -2.0, "toca o chão devagar (%.1f m/s)" % min_vy_near_ground)

	# Alforje: 10 espaços, carga deixa o pet mais lento, conteúdo vai no save.
	check(pet.bag.size() == 10, "alforje com 10 espaços")
	for i in 10:
		pet.bag.add(Database.item(&"stone"), 64)
	check(is_equal_approx(pet.load_fraction(), 1.0), "alforje cheio")
	await hold([&"jump"], 2.0)
	await hold([&"move_forward", &"jump"], 0.3)
	await hold([&"move_forward"], 2.5)
	Input.action_press(&"move_forward")
	await get_tree().create_timer(0.3).timeout
	var loaded_speed := pet.air_speed
	Input.action_release(&"move_forward")
	check(loaded_speed < pet.data.fly_speed * 0.85, "carga reduz a velocidade (%.1f m/s)" % loaded_speed)
	var d := SaveSystem.serialize(main)
	var saved_bag: Array = d["pets"][0]["bag"]
	check(saved_bag.size() == 10 and saved_bag[0] != null and saved_bag[0]["id"] == "stone", "alforje é salvo")

	# Interface: o alforje aparece no inventário quando montado.
	var panel: InventoryPanel = main.hud._inventory_panel
	panel.toggle()
	await get_tree().process_frame
	check(panel._bag_box.visible and panel._bag_slots.size() == 10, "alforje aparece no inventário")
	# Shift + clique leva uma pilha do inventário para o alforje (que está cheio -> não move).
	pet.bag.clear()
	p.inventory.slots[20] = ItemStack.new(Database.item(&"wood"), 30)
	p.inventory.changed.emit()
	panel._quick_move(p.inventory, 20)
	check(pet.bag.count_of(Database.item(&"wood")) == 30 and p.inventory.slots[20] == null, "move a pilha para o alforje")
	panel.toggle()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
