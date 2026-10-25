extends Node
## Marco 9: pet voador (selvagem, preferências, doma, sela, montaria, estamina, estábulo).

var failures := 0
var main: Node
var p: Player
var pet: FlyingPet


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	p = main.player
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	main.spawner.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await get_tree().process_frame
	await _wild_and_observe()
	await _taming()
	await _saddle_and_mount()
	await _stamina()
	await _death_and_stable()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _flat_forward() -> Vector3:
	return Vector3(p.camera_forward().x, 0, p.camera_forward().z).normalized()


func _wild_and_observe() -> void:
	var data := Database.pets[&"aerolho"] as PetData
	check(data != null and data.trust_thresholds == [30, 60, 100], "PetData carregado com os 3 níveis")
	check(Database.spell(&"tame") != null and p.magic.knows(&"tame"), "a magia de doma já é conhecida")
	var pos := p.global_position + _flat_forward() * 10.0
	pet = main.pet_spawner.create_pet(data, Vector3(pos.x, main.chunks.height_at(pos.x, pos.z), pos.z))
	await get_tree().create_timer(0.5).timeout
	check(pet.state == FlyingPet.State.PERCH, "pet selvagem começa pousado")
	check(not pet.knows_food and not pet.knows_biome, "preferências desconhecidas no início")
	# Observação (olhando para ele)
	pet._timer = 1000.0
	await _aim_at_pet(10.5)
	await get_tree().create_timer(3.6).timeout
	check(pet.knows_food, "observar por 3 s revela a comida favorita")
	await get_tree().create_timer(3.0).timeout
	check(pet.knows_biome, "observar por 6 s revela o bioma favorito")
	# Foge se chegar perto
	var d0 := pet.global_position.distance_to(p.global_position)
	p.global_position = pet.global_position + Vector3(4, 0, 0)
	p.global_position.y = main.chunks.height_at(p.global_position.x, p.global_position.z) + 0.3
	await get_tree().create_timer(1.5).timeout
	check(pet.state == FlyingPet.State.FLEE or pet.global_position.distance_to(p.global_position) > 6.0, "pet sem confiança foge de quem se aproxima")
	await get_tree().create_timer(3.5).timeout


func _aim_at_pet(dist := 6.0) -> void:
	# Põe o jogador a `dist` metros do pet, olhando para ele.
	var base := pet.global_position
	var from := base + Vector3(dist, 0, 0)
	from.y = main.chunks.height_at(from.x, from.z) + 0.3
	p.global_position = from
	p.velocity = Vector3.ZERO
	var d := base + Vector3(0, 1.0, 0) - p.camera.global_position
	var pivot := p.get_node("CameraPivot") as Node3D
	var flat := Vector3(base.x - from.x, 0, base.z - from.z).normalized()
	pivot.rotation.y = atan2(-flat.x, -flat.z)
	await get_tree().physics_frame
	var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
	var best := 0.0
	var best_dot := -1.0
	for deg in range(-40, 40, 2):
		arm.rotation.x = deg_to_rad(deg)
		await get_tree().physics_frame
		var dd := (pet.global_position + Vector3(0, 1.0, 0) - p.camera.global_position).normalized()
		if p.camera_forward().dot(dd) > best_dot:
			best_dot = p.camera_forward().dot(dd)
			best = deg
	arm.rotation.x = deg_to_rad(best)
	await get_tree().physics_frame


func _taming() -> void:
	pet.trust = 0.0
	pet.level = 0
	pet.global_position = Vector3(pet.global_position.x, main.chunks.height_at(pet.global_position.x, pet.global_position.z), pet.global_position.z)
	pet._enter_perch()
	pet._timer = 1000.0
	pet.state = FlyingPet.State.PERCH
	await _aim_at_pet()
	p.magic.select(&"tame")
	var mana0 := p.magic.mana
	pet._food_buff = 0.0
	check(p.magic.cast(), "a magia de doma encontra o pet na mira")
	check(pet.trust > 0.0 and p.magic.mana < mana0, "a doma dá confiança e gasta mana (%.1f)" % pet.trust)
	# Comida favorita acelera
	var t0 := pet.trust
	p._dash_cooldown = 0.0
	p.inventory.add(Database.item(&"berries"), 3)
	for i in 9:
		if p.inventory.get_stack(i) != null and p.inventory.get_stack(i).item.id == &"berries":
			p.select_slot(i)
	pet.interact(p)
	check(pet.trust >= t0 + 14.0 and pet._food_buff > 0.0, "oferecer a comida favorita dá +15 e um bônus temporário (%.0f)" % pet.trust)
	p.select_slot(8)
	# Doma repetida com bônus
	p.magic._cooldowns.clear()
	p.magic.mana = 100.0
	var before := pet.trust
	p.magic.cast()
	var gain := pet.trust - before
	check(gain >= 8.0 * 2.0, "com a comida favorita a doma rende mais (+%.0f contra 8 base)" % gain)
	while pet.level < 3 and p.magic.mana > 15.0:
		p.magic._cooldowns.clear()
		if not p.magic.cast():
			break
	for i in 12:
		if pet.level >= 3:
			break
		p.magic._cooldowns.clear()
		p.magic.mana = 100.0
		p.magic.cast()
	check(pet.level == 3 and pet.trust >= 100.0, "chega ao nível 3 de confiança (%d)" % int(pet.trust))
	# Nível 1/2: comportamentos
	pet.trust = 35.0
	pet.level = 1
	pet.state = FlyingPet.State.PERCH
	p.global_position = pet.global_position + Vector3(3, 0, 0)
	p.global_position.y = main.chunks.height_at(p.global_position.x, p.global_position.z) + 0.3
	await get_tree().create_timer(1.0).timeout
	check(pet.state != FlyingPet.State.FLEE, "no nível 1 o pet tolera o jogador por perto")
	pet.trust = 65.0
	pet.level = 2
	pet.state = FlyingPet.State.PERCH
	pet._timer = 0.0
	p.global_position += Vector3(30, 0, 0)
	p.global_position.y = main.chunks.height_at(p.global_position.x, p.global_position.z) + 0.3
	await get_tree().create_timer(6.0).timeout
	check(pet.global_position.distance_to(p.global_position) < 12.0, "no nível 2 o pet segue o jogador (%.1f m)" % pet.global_position.distance_to(p.global_position))
	pet.trust = 100.0
	pet.level = 3


func _saddle_and_mount() -> void:
	p.inventory.add(Database.item(&"saddle"), 1)
	for i in 9:
		if p.inventory.get_stack(i) != null and p.inventory.get_stack(i).item.id == &"saddle":
			p.select_slot(i)
	p.global_position = pet.global_position + Vector3(2, 0, 0)
	pet.state = FlyingPet.State.PERCH
	pet._timer = 1000.0
	pet.interact(p)
	check(pet.saddled and p.inventory.count_of(Database.item(&"saddle")) == 0, "a sela é colocada no pet de nível 3")
	p.select_slot(8)
	pet.mount(p)
	check(p.mounted_pet == pet and p.frozen and pet.state == FlyingPet.State.MOUNTED, "montou no pet")
	Input.action_press(&"jump")
	Input.action_press(&"move_forward")
	var y0 := pet.global_position.y
	var p0 := pet.global_position
	await get_tree().create_timer(2.0).timeout
	Input.action_release(&"jump")
	check(pet.global_position.y > y0 + 5.0, "voa para cima (%.1f m)" % (pet.global_position.y - y0))
	check(pet.global_position.distance_to(p0) > 5.0, "voa para a frente")
	check(p.global_position.distance_to(pet.global_position) < 3.0, "o jogador acompanha o pet")
	Input.action_release(&"move_forward")
	# Combate montado: magia
	p.magic.learn(&"fireball")
	p.magic.select(&"fireball")
	p.magic._cooldowns.clear()
	p.magic.mana = 100.0
	check(p.magic.cast(), "lança magia enquanto monta")
	# Dano vai para o pet, não para o cavaleiro
	var hp := p.stats.health
	var php := pet.health
	p.take_hit(10.0, pet.global_position + Vector3(1, 0, 0))
	check(pet.health == php - 10.0 and p.stats.health == hp, "o golpe atinge o pet e não o cavaleiro")


func _stamina() -> void:
	pet.stamina = 30.0
	Input.action_press(&"sprint")
	Input.action_press(&"move_forward")
	await get_tree().create_timer(2.2).timeout
	Input.action_release(&"sprint")
	check(pet.stamina < 30.0, "voar rápido gasta estamina (%.0f)" % pet.stamina)
	check(pet.exhausted, "estamina zerada deixa o pet exausto")
	var h0 := pet.global_position.y
	Input.action_press(&"jump")
	await get_tree().create_timer(1.5).timeout
	check(pet.global_position.y < h0 - 2.0 or pet.global_position.y <= main.chunks.height_at(pet.global_position.x, pet.global_position.z) + 0.5,
			"exausto, ele planeia perdendo altitude (%.1f -> %.1f)" % [h0, pet.global_position.y])
	Input.action_release(&"move_forward")
	await get_tree().create_timer(3.5).timeout
	var ground: float = main.chunks.height_at(pet.global_position.x, pet.global_position.z)
	check(pet.global_position.y <= ground + 0.6, "pousa no chão")
	var y_ground := pet.global_position.y
	await get_tree().create_timer(0.8).timeout
	check(pet.global_position.y < y_ground + 1.0 or pet.exhausted, "no chão e exausto não consegue decolar")
	Input.action_release(&"jump")
	await get_tree().create_timer(4.5).timeout
	check(not pet.exhausted, "a estamina volta com o descanso (%.0f)" % pet.stamina)
	pet.dismount()
	check(p.mounted_pet == null and not p.frozen, "desmontou")


func _death_and_stable() -> void:
	pet.respawn_delay = 0.5
	pet.health = 5.0
	pet.take_damage(10.0)
	check(pet.state == FlyingPet.State.DEAD, "sem estábulo, o pet morre")
	await get_tree().create_timer(0.3).timeout
	check(not is_instance_valid(pet) or pet.is_queued_for_deletion(), "sem estábulo o pet se perde")
	# Com estábulo
	var data := Database.pets[&"aerolho"] as PetData
	pet = main.pet_spawner.create_pet(data, p.global_position + Vector3(5, 0, 0))
	pet.respawn_delay = 0.5
	pet.trust = 100.0
	pet.level = 3
	pet.saddled = true
	var stable := Placeables.create(&"stable")
	main.add_child(stable)
	stable.global_position = p.global_position + Vector3(-12, 0, 0)
	await get_tree().create_timer(0.3).timeout
	check(Game.stables.size() == 1, "estábulo registrado")
	pet.take_damage(1000.0)
	check(pet.state == FlyingPet.State.DEAD and not pet.visible, "o pet morre")
	await get_tree().create_timer(0.62).timeout
	check(pet.visible and pet.state != FlyingPet.State.DEAD and pet.health == data.max_health, "o pet renasce")
	check(pet.global_position.distance_to(stable.global_position) < 4.0, "renasceu no estábulo")
	check(pet.saddled and pet.level == 3, "mantém a sela e a confiança")
