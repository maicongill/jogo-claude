extends Node
## Marco 6: combate (espada com combo, arco, esquiva, vida e inimigo).

var failures := 0
var main: Node
var p: Player


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _enemy(offset: Vector3, passive := true) -> Enemy:
	var e := Enemy.new()
	main.add_child(e)
	e.global_position = p.global_position + offset
	if passive:
		e.sight_range = 0.0
	return e


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	p = main.player
	# Fica longe da floresta e das criaturas que nasceram sozinhas.
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	main.spawner.queue_free()
	await _sword()
	await _bow()
	await _dodge()
	await _ai()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _sword() -> void:
	var sword := Database.item(&"wooden_sword")
	p.inventory.add(sword)
	p.select_slot(0)
	check(p.held_item().id == &"wooden_sword", "espada na mão")
	var e := _enemy(Vector3(0, 0.2, -1.5))
	await get_tree().create_timer(0.6).timeout
	e.global_position = p.global_position + Vector3(0, 0.2, -1.4)
	e.velocity = Vector3.ZERO
	p.combat.attack(sword)
	await get_tree().create_timer(0.5).timeout
	check(e.health < e.max_health and absf(e.health - (40.0 - 14.0)) < 0.1, "1º golpe causa 14 de dano (vida %.0f)" % e.health)
	check(p.combat.combo == 0, "combo no passo 0")
	e.global_position = p.global_position + Vector3(0, 0.2, -1.4)
	e.velocity = Vector3.ZERO
	p.combat.attack(sword)
	await get_tree().create_timer(0.5).timeout
	check(p.combat.combo == 1 and absf(e.health - (26.0 - 14.0 * 1.1)) < 0.2, "2º golpe encadeado causa 15,4 (vida %.1f)" % e.health)
	e.global_position = p.global_position + Vector3(0, 0.2, -1.4)
	e.velocity = Vector3.ZERO
	p.combat.attack(sword)
	await get_tree().create_timer(0.5).timeout
	check(p.combat.combo == 2, "3º golpe do combo")
	check(e.state == Enemy.State.DEAD or e.health <= 0.0, "inimigo derrotado com a espada")
	check(p.inventory.get_stack(0).durability == 60 - 3, "espada perdeu 3 de durabilidade (%d)" % p.inventory.get_stack(0).durability)
	await get_tree().create_timer(0.8).timeout
	check(p.inventory.count_of(Database.item(&"meat")) >= 1, "o inimigo largou carne (%d)" % p.inventory.count_of(Database.item(&"meat")))
	# Sem combo se esperar demais
	var e2 := _enemy(Vector3(0, 0.2, -1.4))
	await get_tree().create_timer(1.0).timeout
	p.combat.attack(sword)
	await get_tree().create_timer(0.5).timeout
	check(p.combat.combo == 0, "esperar demais reinicia o combo")
	e2.queue_free()


func _bow() -> void:
	var bow := Database.item(&"bow")
	p.inventory.add(bow)
	p.inventory.add(Database.item(&"arrow"), 10)
	var slot := 0
	for i in p.inventory.size():
		if p.inventory.get_stack(i) != null and p.inventory.get_stack(i).item.id == &"bow":
			slot = i
	p.select_slot(slot if slot < 9 else 1)
	if p.held_item() == null or p.held_item().id != &"bow":
		p.inventory.set_stack(2, p.inventory.get_stack(slot))
		p.inventory.slots[slot] = null
		p.select_slot(2)
	var before := p.inventory.count_of(Database.item(&"arrow"))
	await get_tree().create_timer(0.7).timeout
	p.combat.attack(bow)
	await get_tree().physics_frame
	check(p.inventory.count_of(Database.item(&"arrow")) == before - 1, "atirar gasta 1 flecha")
	var arrows := 0
	for n in main.get_children():
		if n is Arrow:
			arrows += 1
	check(arrows == 1, "a flecha existe no mundo")
	var s := p.inventory.get_stack(p.selected_slot)
	check(s.durability == 89, "o arco perdeu 1 de durabilidade")
	var e := _enemy(Vector3(0, 0.2, -15.0))
	e.global_position.y = main.chunks.height_at(e.global_position.x, e.global_position.z) + 0.2
	await get_tree().create_timer(0.8).timeout
	var origin := p.global_position + Vector3(0, 1.35, 0)
	var aim := e.global_position + Vector3(0, 0.55 + 1.5, 0)  # sobe a mira para compensar a queda da flecha
	Arrow.launch(main, origin, (aim - origin).normalized(), 32.0, bow.damage, p)
	await get_tree().create_timer(1.2).timeout
	check(e.health < e.max_health, "a flecha acerta o inimigo a 15 m (vida %.0f)" % e.health)
	e.queue_free()
	# sem flechas
	p.inventory.remove(Database.item(&"arrow"), p.inventory.count_of(Database.item(&"arrow")))
	await get_tree().create_timer(0.7).timeout
	p.combat.attack(bow)
	check(p.combat._cooldown <= 0.31, "sem flechas não atira")


func _dodge() -> void:
	p.stats.health = 100.0
	p.stats.invulnerable_time = 0.0
	await get_tree().create_timer(1.0).timeout
	var start := p.global_position
	p.start_dodge(Vector3(1, 0, 0))
	check(p.stats.invulnerable_time > 0.3, "esquiva dá invulnerabilidade")
	var hurt := p.stats.hurt(30.0, &"teste")
	check(not hurt and p.stats.health == 100.0, "ataque durante a esquiva não causa dano")
	await get_tree().create_timer(0.35).timeout
	check(p.global_position.distance_to(start) > 1.5, "a esquiva desloca o personagem (%.1f m)" % p.global_position.distance_to(start))
	await get_tree().create_timer(0.4).timeout
	p.take_hit(15.0, p.global_position + Vector3(1, 0, 0))
	check(p.stats.health == 85.0, "depois da esquiva o dano volta a valer (vida %.0f)" % p.stats.health)


func _ai() -> void:
	p.stats.health = 100.0
	p.stats.invulnerable_time = 0.0
	await get_tree().create_timer(1.0).timeout
	var e := _enemy(Vector3(0, 0.2, -9.0), false)
	e.global_position.y = main.chunks.height_at(e.global_position.x, e.global_position.z) + 0.2
	await get_tree().create_timer(0.3).timeout
	check(e.state == Enemy.State.CHASE, "vê o jogador a 9 m e persegue")
	await get_tree().create_timer(5.0).timeout
	check(p.stats.health < 100.0, "ao alcançar, ataca e tira vida do jogador (vida %.0f)" % p.stats.health)
	e.queue_free()
	# Muito longe: não percebe.
	var far := _enemy(Vector3(0, 0.2, -30.0), false)
	await get_tree().create_timer(0.5).timeout
	check(far.state != Enemy.State.CHASE, "a 30 m não percebe o jogador")
	far.queue_free()
