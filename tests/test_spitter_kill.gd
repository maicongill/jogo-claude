extends Node
## Regressão: o cuspidor (roxo) precisa poder ser morto em jogo, com a IA ligada.

var failures := 0
var main: Node
var p: Player


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	p = main.player
	while p.frozen:
		await get_tree().process_frame
	main.spawner.queue_free()
	for q in get_tree().get_nodes_in_group(&"enemy"):
		q.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	p.stats.max_health = 10000.0
	p.stats.health = 10000.0
	var e := Enemy.new()
	e.type_id = &"cuspidor"
	main.add_child(e)
	var pos := p.global_position + Vector3(0, 0, -9)
	pos.y = main.chunks.height_at(pos.x, pos.z) + 0.5
	e.global_position = pos
	for _k in 5:
		await get_tree().physics_frame
	print("  cuspidor: vida %.0f/%.0f, camada %d, escala %s" % [e.health, e.max_health, e.collision_layer, e.scale])
	check(e.health > 0.0 and e.max_health > 0.0, "cuspidor nasce com vida")
	# Atinge direto: dano chega?
	var h0 := e.health
	e.take_damage(5.0, p.global_position, 0.0)
	check(e.health < h0, "take_damage tira vida (%.0f -> %.0f)" % [h0, e.health])
	# Raio da mira acerta o corpo dele?
	var q := PhysicsRayQueryParameters3D.create(e.global_position + Vector3(0, 0.5, 3), e.global_position + Vector3(0, 0.5, -3), 4)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and hit["collider"] == e, "o corpo dele tem colisão na camada de inimigos")
	# Persegue com espada como um jogador: corre até ele e ataca.
	var sword := Database.item(&"wooden_sword")
	p.inventory.slots[0] = ItemStack.new(sword, 1)
	p.inventory.changed.emit()
	p.select_slot(0)
	var pivot := p.get_node("CameraPivot") as Node3D
	var hits := 0
	var last_h := e.health
	Input.action_press(&"move_forward")
	# Sem correr (caso difícil): o cuspidor recua mais devagar e depois para.
	for i in 240:
		if not is_instance_valid(e) or e.state == Enemy.State.DEAD:
			break
		var to := e.global_position - p.camera.global_position
		pivot.rotation.y = atan2(-to.x, -to.z)
		if p.global_position.distance_to(e.global_position) < 2.2:
			p.combat._cooldown = 0.0
			p.combat.attack(sword)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(e) and e.health < last_h:
			hits += 1
			last_h = e.health
	Input.action_release(&"move_forward")
	print("  golpes que acertaram: %d" % hits)
	check(hits >= 1, "a vida aparece/cai com os golpes")
	check(not is_instance_valid(e) or e.state == Enemy.State.DEAD, "o cuspidor morre com a espada (vida %.0f)" % (e.health if is_instance_valid(e) else 0.0))
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
