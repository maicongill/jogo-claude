extends Node
## Marco 4: crafting, durabilidade, fome, morte e cama.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _recipe(id: StringName) -> RecipeData:
	for r in Database.recipes:
		if r.id == id:
			return r
	return null


func _ready() -> void:
	_test_crafting()
	await _test_survival()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _test_crafting() -> void:
	var wood := Database.item(&"wood")
	var stone := Database.item(&"stone")
	check(Database.recipes.size() >= 10, "receitas carregadas (%d)" % Database.recipes.size())
	var inv := Inventory.new(9)
	inv.add(wood, 2)
	check(not Crafting.can_craft(inv, _recipe(&"wooden_axe")), "2 madeiras não bastam para o machado")
	inv.add(wood, 1)
	check(Crafting.craft(inv, _recipe(&"wooden_axe")), "crafta machado de madeira com 3 madeiras")
	check(inv.count_of(wood) == 0 and inv.count_of(Database.item(&"wooden_axe")) == 1, "ingredientes consumidos e item entregue")
	check(inv.get_stack(0).durability == 40, "ferramenta nova tem durabilidade cheia")
	inv.add(wood, 4)
	inv.add(stone, 4)
	check(Crafting.craft(inv, _recipe(&"arrow")) and inv.count_of(Database.item(&"arrow")) == 4, "flecha: 1 madeira + 1 pedra = 4 flechas")
	var full := Inventory.new(2)
	full.add(wood, 64)
	full.add(stone, 64)
	check(not Crafting.craft(full, _recipe(&"arrow")) and full.count_of(wood) == 64, "sem espaço: não crafta e não perde ingredientes")


func _aim_ground(main: Node) -> void:
	var p: Player = main.player
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	for deg in range(5, 40, 2):
		arm.rotation.x = deg_to_rad(-deg)
		await get_tree().physics_frame
		var hit: Dictionary = p.get_node("Interaction").aim_ray(1)
		if not hit.is_empty() and hit["position"].distance_to(p.global_position) < 4.0:
			return


func _test_survival() -> void:
	Game.debug_starter_kit = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var p: Player = main.player
	var inter: PlayerInteraction = p.get_node("Interaction")
	check(p.inventory.count_of(Database.item(&"wooden_axe")) == 0, "sem kit de teste: começa de mãos vazias")

	# Fome
	p.stats.seconds_to_starve = 10.0
	var h0 := p.stats.hunger
	await get_tree().create_timer(1.0).timeout
	check(p.stats.hunger < h0 - 5.0, "a fome diminui com o tempo (%.1f -> %.1f)" % [h0, p.stats.hunger])
	p.stats.seconds_to_starve = 600.0
	p.stats.hunger = 0.0
	var hp := p.stats.health
	await get_tree().create_timer(2.3).timeout
	check(p.stats.health < hp, "fome zerada causa dano (%.0f -> %.0f)" % [hp, p.stats.health])
	p.stats.health = 100.0
	p.stats.hunger = 40.0
	p.inventory.add(Database.item(&"berries"), 2)
	p.select_slot(0)
	await _aim_ground(main)
	inter._cooldown = 0.0
	inter.primary_action()
	check(p.stats.hunger > 50.0 and p.inventory.count_of(Database.item(&"berries")) == 1, "comer frutinhas recupera fome (%.0f)" % p.stats.hunger)

	# Cama
	p.inventory.add(Database.item(&"bed"), 1)
	p.select_slot(1)
	check(p.held_item().id == &"bed", "cama na hotbar")
	await _aim_ground(main)
	inter._cooldown = 0.0
	inter.primary_action()
	check(get_tree().get_nodes_in_group(&"bed").size() == 1, "cama colocada no mundo")
	check(Game.spawn_point != Vector3.INF, "cama define o ponto de renascimento")
	var bed_pos := Game.spawn_point

	# Morte perde itens e renasce na cama
	p.global_position += Vector3(12, 0, 12)
	p.inventory.add(Database.item(&"wood"), 5)
	check(p.inventory.count_of(Database.item(&"wood")) == 5, "tem 5 madeiras")
	Game.lose_items_on_death = true
	p.stats.hurt(1000.0)
	check(p.stats.dead and p.frozen, "morreu")
	check(p.inventory.count_of(Database.item(&"wood")) == 0, "perdeu os itens ao morrer")
	await get_tree().create_timer(2.8).timeout
	check(not p.stats.dead and not p.frozen, "renasceu")
	check(p.global_position.distance_to(bed_pos) < 1.5, "renasceu perto da cama")
	check(p.stats.health >= p.stats.max_health - 1.0, "vida cheia ao renascer")

	# Opção de não perder itens
	Game.lose_items_on_death = false
	p.inventory.add(Database.item(&"wood"), 7)
	p.stats.hurt(1000.0, &"", true)
	await get_tree().create_timer(2.8).timeout
	check(p.inventory.count_of(Database.item(&"wood")) == 7, "com a opção desligada os itens são mantidos")
	Game.lose_items_on_death = true
