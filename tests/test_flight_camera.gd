extends Node
## Câmera montada sem tranco: voando para a frente e subindo, a posição do personagem em relação à
## câmera não pode "voltar" de um quadro para o outro. Também: Shift acelera a subida.

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
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await get_tree().process_frame
	var pet: FlyingPet = main.pet_spawner.create_pet(Database.pets[&"aerolho"], p.global_position + Vector3(2, 0, 0))
	pet.add_trust(100.0)
	pet.saddled = true
	pet._player = p
	pet.mount(p)
	# Vários quadros de tela por passo de física (como num monitor rápido).
	Engine.max_fps = 0
	Input.action_press(&"jump")
	Input.action_press(&"move_forward")
	await get_tree().create_timer(2.0).timeout
	var worst := 0.0
	var prev := -1.0
	var frames := 0
	var t_end := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		# Quanto o personagem está à frente da câmera, na direção do voo.
		var fwd := -pet.global_basis.z
		var ahead := (p.global_position - p.camera.global_position).dot(fwd)
		if prev >= 0.0:
			worst = maxf(worst, prev - ahead)  # recuo do personagem na tela entre dois quadros
		prev = ahead
		frames += 1
	print("    %d quadros, maior recuo entre quadros: %.3f m" % [frames, worst])
	check(worst < 0.05, "sem tranco para trás voando para a frente e subindo (%.3f m)" % worst)
	Input.action_release(&"move_forward")
	Input.action_release(&"jump")
	await get_tree().create_timer(1.0).timeout

	# Shift acelera a subida (gastando estamina).
	pet.stamina = pet.data.max_stamina
	var y0 := pet.global_position.y
	Input.action_press(&"jump")
	await get_tree().create_timer(1.5).timeout
	var normal := pet.global_position.y - y0
	Input.action_release(&"jump")
	await get_tree().create_timer(1.0).timeout
	var st0 := pet.stamina
	y0 = pet.global_position.y
	Input.action_press(&"jump")
	Input.action_press(&"sprint")
	await get_tree().create_timer(1.5).timeout
	var fast := pet.global_position.y - y0
	Input.action_release(&"jump")
	Input.action_release(&"sprint")
	check(fast > normal * 1.4, "Shift sobe mais rápido (%.1f m vs %.1f m em 1,5 s)" % [fast, normal])
	check(pet.stamina < st0 - 5.0, "subir rápido gasta estamina (%.0f -> %.0f)" % [st0, pet.stamina])
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
