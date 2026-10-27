extends Node
## Ajuste 3 (Etapa 6): inimigos vivos (vagam, percebem, avisam, reagem), 3 tipos e golpes novos.

var failures := 0
var main: Node
var p: Player


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func spawn(type_id: StringName, offset: Vector3) -> Enemy:
	var e := Enemy.new()
	e.type_id = type_id
	main.add_child(e)
	var pos := p.global_position + offset
	pos.y = main.chunks.height_at(pos.x, pos.z) + 0.5
	e.global_position = pos
	e._home = pos
	return e


func fwd() -> Vector3:
	var f := p.camera_forward()
	f.y = 0.0
	return f.normalized()


func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group(&"enemy"):
		e.queue_free()
	for q in get_tree().get_nodes_in_group(&"enemy_projectile"):
		q.queue_free()
	await get_tree().process_frame


## Inimigo parado no lugar (sem IA de movimento), para medir só o efeito do golpe.
func dummy(type_id: StringName, dist: float) -> Enemy:
	p.velocity = Vector3.ZERO
	await get_tree().create_timer(0.3).timeout
	var e := spawn(type_id, fwd() * dist)
	e.sight_range = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	e.set_physics_process(false)
	return e


func swing(item: ItemData, hold: float) -> void:
	p.combat._cooldown = 0.0
	p.combat.begin_charge(item)
	await get_tree().create_timer(hold).timeout
	p.combat.release_charge()
	await get_tree().create_timer(0.45).timeout


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	p = main.player
	while p.frozen:
		await get_tree().process_frame
	main.spawner.queue_free()
	for q in get_tree().get_nodes_in_group(&"pet"):
		q.queue_free()
	await clear_enemies()
	p.stats.max_health = 10000.0
	p.stats.health = 10000.0

	# --- 3 tipos com papéis diferentes
	var types: Dictionary = Config.section("enemy_types")
	check(types.size() >= 3, "pelo menos 3 tipos de inimigo (%d)" % types.size())
	var fast := spawn(&"saltilho", Vector3(40, 0, 0))
	var tank := spawn(&"musgolho", Vector3(-40, 0, 0))
	var spit := spawn(&"cuspidor", Vector3(0, 0, 40))
	await get_tree().process_frame
	check(fast.chase_speed > tank.chase_speed * 2.0 and fast.max_health < tank.max_health / 3.0, "saltilho é rápido e fraco; musgolho é lento e forte")
	check(tank.attack_damage > fast.attack_damage * 3.0 and tank.windup_time > fast.windup_time * 2.0, "musgolho bate forte, mas avisa por mais tempo")
	check(spit.ranged and spit.attack_range > 10.0, "cuspidor ataca à distância")
	check(fast.display_name != tank.display_name and tank.display_name != spit.display_name, "cada tipo tem nome próprio")
	var plain_types := {}
	for i in 200:
		plain_types[EnemySpawner.pick_type("plain", i / 200.0)] = true
	check(not plain_types.has(&"musgolho") and plain_types.has(&"saltilho"), "na planície não aparece musgolho")

	# --- vagam pelo mapa (jogador longe)
	var start := fast.global_position
	var max_d := 0.0
	for _i in 12:
		await get_tree().create_timer(1.0).timeout
		max_d = maxf(max_d, fast.global_position.distance_to(start))
	check(max_d > 5.0, "inimigo vaga pelo mapa (%.1f m)" % max_d)
	await clear_enemies()

	# --- percebe: "!" e depois persegue
	var e := spawn(&"saltilho", fwd() * 10.0)
	var saw_alert := false
	var chased := false
	for _i in 60:
		await get_tree().physics_frame
		saw_alert = saw_alert or (e.state == Enemy.State.ALERT and e._alert.visible)
		chased = chased or e.state == Enemy.State.CHASE
	check(saw_alert, "percebe o jogador e mostra \"!\"")
	check(chased, "depois do alerta, persegue")
	await clear_enemies()

	# --- aviso antes do ataque (musgolho)
	var t := spawn(&"musgolho", fwd() * 2.0)
	var hp0 := p.stats.health
	var warned_before_hit := false
	var hit := false
	for _i in 300:
		await get_tree().physics_frame
		if t.state == Enemy.State.WINDUP and p.stats.health == hp0:
			warned_before_hit = true
		if p.stats.health < hp0:
			hit = true
			break
	check(warned_before_hit and hit, "musgolho avisa (cresce/fica vermelho) e depois acerta")
	await clear_enemies()

	# --- reação aos golpes: recuo + atordoamento + flash; resistência do musgolho
	var sword := Database.item(&"wooden_sword")
	p.inventory.slots[0] = ItemStack.new(sword, 1)
	p.inventory.slots[1] = ItemStack.new(Database.item(&"bow"), 1)
	p.inventory.add(Database.item(&"arrow"), 64)
	p.inventory.changed.emit()
	p.select_slot(0)
	var s := await dummy(&"saltilho", 1.6)
	await swing(sword, 0.05)
	check(s.state == Enemy.State.STAGGER or s.state == Enemy.State.DEAD or s.health < s.max_health, "saltilho leva o golpe")
	await clear_enemies()
	var m := await dummy(&"musgolho", 1.8)
	var m_hp := m.health
	p.combat._last_swing = -10.0
	await swing(sword, 0.05)
	var normal_dmg := m_hp - m.health
	check(normal_dmg > 0.0 and m.state != Enemy.State.STAGGER, "golpe normal não atordoa o musgolho (resistência) — dano %.0f" % normal_dmg)
	await get_tree().create_timer(0.8).timeout
	p.velocity = Vector3.ZERO
	m.global_position = p.global_position + fwd() * 1.8
	m.state = Enemy.State.IDLE
	m_hp = m.health
	await swing(sword, 0.7)
	var heavy_dmg := m_hp - m.health
	check(m.state == Enemy.State.STAGGER, "golpe carregado atordoa o musgolho")
	check(heavy_dmg > normal_dmg * 1.6, "golpe carregado causa mais dano (%.0f vs %.0f)" % [heavy_dmg, normal_dmg])
	await clear_enemies()

	# --- crítico no ar
	var c := spawn(&"musgolho", fwd() * 1.8)
	c.sight_range = 0.0
	await get_tree().physics_frame
	p.velocity.y = 6.0  # pula
	await get_tree().create_timer(0.12).timeout
	check(not p.is_on_floor(), "jogador no ar")
	var c_hp := c.health
	p.combat._last_swing = -10.0
	await swing(sword, 0.02)
	var crit_dmg := c_hp - c.health
	check(crit_dmg > normal_dmg * 1.3, "golpe no ar é crítico (%.0f vs %.0f)" % [crit_dmg, normal_dmg])
	await clear_enemies()
	await get_tree().create_timer(0.6).timeout

	# --- arco: tiro rápido vs carregado
	p.select_slot(1)
	var bow := Database.item(&"bow")
	var b1 := spawn(&"musgolho", fwd() * 6.0)
	b1.sight_range = 0.0
	(p.get_node("CameraPivot/SpringArm3D") as Node3D).rotation.x = deg_to_rad(-6)
	await get_tree().physics_frame
	var aim_at := func(target: Enemy) -> void:
		var to: Vector3 = target.global_position + Vector3(0, 0.8, 0) - p.camera.global_position
		var arm := p.get_node("CameraPivot/SpringArm3D") as Node3D
		arm.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	aim_at.call(b1)
	await get_tree().physics_frame
	var b_hp := b1.health
	await swing(bow, 0.05)
	await get_tree().create_timer(0.6).timeout
	var quick := b_hp - b1.health
	b_hp = b1.health
	await get_tree().create_timer(0.4).timeout
	await swing(bow, 1.1)
	await get_tree().create_timer(0.6).timeout
	var full := b_hp - b1.health
	check(quick > 0.0 and full > quick * 2.0, "tiro carregado é bem mais forte (%.0f vs %.0f)" % [full, quick])
	await clear_enemies()

	# --- cuspidor: mantém distância e cospe
	var sp := spawn(&"cuspidor", fwd() * 11.0)
	var hp1 := p.stats.health
	var saw_projectile := false
	for _i in 360:
		await get_tree().physics_frame
		saw_projectile = saw_projectile or not get_tree().get_nodes_in_group(&"enemy_projectile").is_empty()
		if p.stats.health < hp1:
			break
	check(saw_projectile, "cuspidor cospe projéteis")
	check(p.stats.health < hp1, "o cuspe acerta o jogador")
	sp.global_position = p.global_position + fwd() * 3.0
	await get_tree().create_timer(1.5).timeout
	check(sp.global_position.distance_to(p.global_position) > 4.5, "cuspidor recua quando o jogador chega perto (%.1f m)" % sp.global_position.distance_to(p.global_position))
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
