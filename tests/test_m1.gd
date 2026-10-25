extends Node
## Marco 1: o personagem anda, corre, pula e agacha. Rodar:
## godot --headless --path . res://tests/test_m1.tscn

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
	await _frames(30)
	var p: Player = main.player
	var start := p.global_position
	check(p.is_on_floor(), "personagem apoiado no chão")

	Input.action_press(&"move_forward")
	await _frames(60)
	var walked := p.global_position.distance_to(start)
	check(walked > 1.5, "anda para frente (%.1f m em 1 s)" % walked)
	check(p._model.current() == &"walk", "animação walk (%s)" % p._model.current())

	var before := p.global_position
	Input.action_press(&"sprint")
	await _frames(60)
	var ran := p.global_position.distance_to(before)
	check(ran > walked * 1.5, "corre mais rápido que anda (%.1f m)" % ran)
	check(p._model.current() == &"run", "animação run (%s)" % p._model.current())
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _frames(40)

	var y0 := p.global_position.y
	Input.action_press(&"jump")
	await _frames(8)
	Input.action_release(&"jump")
	await _frames(10)
	check(p.global_position.y > y0 + 0.3, "pula (altura +%.2f m)" % (p.global_position.y - y0))
	await _frames(90)
	check(p.is_on_floor(), "aterrissa")

	Input.action_press(&"crouch")
	await _frames(20)
	check(p.crouching, "agacha")
	check(p._model.current() == &"crouch", "animação crouch (%s)" % p._model.current())
	Input.action_release(&"crouch")
	await _frames(20)
	check(not p.crouching, "levanta")

	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
