extends Node
## Montar e desmontar o pet com a tecla F (evento de teclado de verdade), inclusive com o pet
## pousado do lado do jogador.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func press(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await get_tree().process_frame
	var pet: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + Vector3(3, 1, 0))
	pet.add_trust(100.0)
	pet.saddled = true
	pet._player = p
	pet.state = FlyingPet.State.FOLLOW
	# Espera o pet ir para o lugar dele (seguindo / pousado).
	await get_tree().create_timer(5.0).timeout
	print("  distância do pet: %.1f m" % pet.global_position.distance_to(p.global_position))
	# Jogador parado (mesmo girando a câmera): o pet fica pousado no mesmo lugar.
	var rest := pet.global_position
	(p.get_node("CameraPivot") as Node3D).rotate_y(1.5)
	await get_tree().create_timer(2.0).timeout
	check(pet.global_position.distance_to(rest) < 0.05, "pet pousado fica parado com o jogador parado (moveu %.2f m)" % pet.global_position.distance_to(rest))
	check(pet.global_position.y <= pet.height_fn.call(pet.global_position.x, pet.global_position.z) + 0.05, "pet está no chão")
	await press(KEY_F)
	check(p.mounted_pet == pet, "F monta no pet pousado ao lado")
	await get_tree().create_timer(0.5).timeout
	await press(KEY_F)
	check(p.mounted_pet == null, "F desmonta")
	check(not p.frozen, "jogador volta a andar depois de desmontar")
	# E com a mira um pouco ao lado do pet (ajuda de mira) monta; E de novo desmonta.
	await get_tree().create_timer(4.0).timeout
	var pivot := p.get_node("CameraPivot") as Node3D
	var arm := p.get_node("CameraPivot/SpringArm3D") as SpringArm3D
	for _i in 4:  # a câmera orbita, então converge em alguns passos
		var to_pet := pet.global_position + Vector3(0, 1.0, 0) - p.camera.global_position
		pivot.global_rotation.y = atan2(-to_pet.x, -to_pet.z)
		arm.rotation.x = atan2(to_pet.y, Vector2(to_pet.x, to_pet.z).length())
		await get_tree().physics_frame
		await get_tree().process_frame
	pivot.global_rotation.y += deg_to_rad(8.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	await press(KEY_E)
	check(p.mounted_pet == pet, "E com a mira 8° ao lado do pet monta")
	await get_tree().create_timer(0.5).timeout
	await press(KEY_E)
	check(p.mounted_pet == null, "E desmonta")
	# Longe demais: F não monta.
	pet.state = FlyingPet.State.PERCH
	pet.global_position = p.global_position + Vector3(20, 0, 0)
	await get_tree().create_timer(0.4).timeout
	await press(KEY_F)
	check(p.mounted_pet == null, "F com o pet a 20 m não monta")
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
