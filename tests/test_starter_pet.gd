extends Node
## Pássaro inicial (game.start_with_tamed_pet) e as regras novas de estamina/planar.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	var tamed := 0
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if q.trust > 0.0:
			tamed += 1
	check(tamed == 0, "nos testes a opção não cria o pássaro inicial")
	# Chama a criação como num jogo novo (fingindo não ser teste).
	Game.start_with_tamed_pet = true
	main._starter_pet_done = false
	var scene_path := get_tree().current_scene.scene_file_path
	get_tree().current_scene.scene_file_path = "res://scenes/main.tscn"
	main._spawn_starter_pet()
	get_tree().current_scene.scene_file_path = scene_path
	var pet: FlyingPet = null
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if q.trust > 0.0:
			pet = q
	check(pet != null, "jogo novo começa com um pássaro")
	if pet == null:
		get_tree().quit(1)
		return
	check(pet.level == pet.data.trust_thresholds.size() and pet.trust >= 100.0, "com a confiança no máximo (nível %d)" % pet.level)
	check(pet.saddled, "e com a sela")
	check(main.goals.is_done(&"tame"), "conta como domado no objetivo")
	check(pet.global_position.distance_to(p.global_position) < 8.0, "ao lado do jogador")
	main._spawn_starter_pet()
	var count := 0
	for q: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if q.trust > 0.0:
			count += 1
	check(count == 1, "só cria um")

	# Estamina parado no ar.
	pet.mount(p)
	Input.action_press(&"jump")
	await get_tree().create_timer(2.0).timeout
	Input.action_release(&"jump")
	await get_tree().create_timer(0.5).timeout
	pet.stamina = 100.0
	await get_tree().create_timer(2.0).timeout
	check(pet.stamina < 100.0 and pet.stamina > 95.0, "parado no ar gasta um pouco de estamina (%.1f)" % pet.stamina)

	# Planar: W ou Espaço saem do planar.
	for action in [&"move_forward", &"jump"]:
		Input.action_press(&"dodge")
		await get_tree().physics_frame
		Input.action_release(&"dodge")
		await get_tree().create_timer(0.3).timeout
		check(pet.glide_on, "Q liga o planar")
		Input.action_press(action)
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(action)
		check(not pet.glide_on, "%s sai do planar" % ("W" if action == &"move_forward" else "Espaço"))
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
