extends Node
## Marco 8 (revisto na Etapa 6): mana, as 3 magias desde o início (seleção por tecla), magias e fogo no mundo.

var failures := 0
var main: Node
var p: Player


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _enemy(pos: Vector3) -> Enemy:
	var e := Enemy.new()
	main.add_child(e)
	e.global_position = pos
	e.sight_range = 0.0
	return e


func _find_tree() -> Array:
	var best: Array = []
	var best_d := 1e9
	for chunk: Chunk in main.chunks._chunks.values():
		for f in chunk.fields:
			if f.data.id != &"tree":
				continue
			for i in f._xforms.size():
				if f.is_alive(i) and f.world_position_of(i).distance_to(p.global_position) < best_d:
					best_d = f.world_position_of(i).distance_to(p.global_position)
					best = [f, i]
	return best


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
	await _scrolls_and_book()
	await _casting()
	await _fire_world()
	await _wind_and_earth()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)


func _scrolls_and_book() -> void:
	# Etapa 6 / Ajuste 4: sem mesa de magia nem pergaminhos; as 3 magias (e a doma) desde o início.
	check(Database.magic.size() == 4, "3 magias de combate + doma")
	for id in [&"fireball", &"wind_gust", &"earth_wall", &"tame"]:
		check(p.magic.knows(id), "%s disponível desde o início" % Database.spell(id).display_name)
	check(Database.item(&"magic_table") == null and Database.item(&"scroll_fire") == null, "não existem mais mesa de magia nem pergaminhos")
	check(Placeables.create(&"magic_table") == null, "a mesa de magia não pode ser colocada")
	for r in Database.recipes:
		check(r.output.kind != ItemData.Kind.PLACEABLE or r.output.place_id != &"magic_table", "nenhuma receita de magia")
	# Seleção por tecla.
	for pair in [[KEY_X, &"wind_gust"], [KEY_V, &"earth_wall"], [KEY_T, &"tame"], [KEY_Z, &"fireball"]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = pair[0]
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
		ev = ev.duplicate()
		ev.pressed = false
		Input.parse_input_event(ev)
		await get_tree().process_frame
		check(p.magic.selected == pair[1], "tecla seleciona %s" % Database.spell(pair[1]).display_name)


func _casting() -> void:
	p.magic.mana = 100.0
	p.magic._cooldowns.clear()
	var spell := Database.spell(&"fireball")
	var before := p.magic.mana
	check(p.magic.cast(), "lança a bola de fogo")
	check(absf(p.magic.mana - (before - spell.mana_cost)) < 0.01, "gasta 20 de mana (%.0f)" % p.magic.mana)
	var balls := 0
	for n in main.get_children():
		if n is Fireball:
			balls += 1
	check(balls == 1, "a bola de fogo existe no mundo")
	await get_tree().create_timer(2.8).timeout
	check(p.magic.mana > before - spell.mana_cost + 3.0, "a mana regenera depois de uma pausa (%.0f)" % p.magic.mana)
	p.magic.mana = 5.0
	p.magic._cooldowns.clear()
	check(not p.magic.cast(), "mana insuficiente impede o lançamento")
	p.magic.mana = 100.0


func _fire_world() -> void:
	# Bola de fogo em um inimigo
	p.magic._cooldowns.clear()
	var ray: Dictionary = p.get_node("Interaction").aim_ray(1)
	var target: Vector3 = ray["position"] if not ray.is_empty() else p.global_position + Vector3(0, 0, -8)
	var e := _enemy(target + Vector3(0, 0.3, 0))
	await get_tree().create_timer(0.3).timeout
	var hp := e.health
	p.magic.cast()
	await get_tree().create_timer(1.5).timeout
	check(e.health < hp - 20.0, "a explosão fere o inimigo (vida %.0f -> %.0f)" % [hp, e.health])
	check(e._fire != null or e.state == Enemy.State.DEAD, "o inimigo pega fogo")
	e.queue_free()

	# Árvore pega fogo e é destruída sem soltar madeira
	var t := _find_tree()
	var field: ResourceField = t[0]
	var wood_before := p.inventory.count_of(Database.item(&"wood"))
	field.ignite_index(t[1])
	check(field.is_burning(t[1]), "a árvore pega fogo")
	await get_tree().create_timer(5.5).timeout
	check(not field.is_alive(t[1]), "o fogo destrói a árvore depois de um tempo")
	check(p.inventory.count_of(Database.item(&"wood")) == wood_before, "a árvore queimada não solta madeira")

	# Estrutura de madeira queima
	var b: BuildSystem = main.build
	p.inventory.add(Database.item(&"wood"), 50)
	var h: float = main.chunks.height_at(30, 30)
	var piece := b.place(b.pieces_data[0], b.compute_target(Vector3(30, h, 30), 0))
	piece.hp = 12.0
	piece.ignite()
	check(piece._fire != null, "o piso de madeira pega fogo")
	await get_tree().create_timer(3.0).timeout
	check(not is_instance_valid(piece) or piece.is_queued_for_deletion(), "a estrutura queimada é destruída")


func _wind_and_earth() -> void:
	p.magic.learn(&"wind_gust")
	p.magic.learn(&"earth_wall")
	p.magic.select(&"wind_gust")
	p.magic._cooldowns.clear()
	p.magic.mana = 100.0
	var cam_flat := Vector3(p.camera_forward().x, 0, p.camera_forward().z).normalized()
	var e := _enemy(p.global_position + cam_flat * 4.0 + Vector3(0, 0.2, 0))
	await get_tree().create_timer(0.3).timeout
	var pos0 := e.global_position
	check(p.magic.cast(), "lança a rajada de vento")
	await get_tree().create_timer(0.5).timeout
	check(e.health <= e.max_health - 9.0, "o vento fere o inimigo (vida %.0f)" % e.health)
	check(e.global_position.distance_to(pos0) > 1.0, "o vento empurra o inimigo (%.1f m)" % e.global_position.distance_to(pos0))
	e.queue_free()

	p.magic.select(&"earth_wall")
	p.magic._cooldowns.clear()
	p.magic.mana = 100.0
	check(p.magic.cast(), "lança a muralha de terra")
	await get_tree().create_timer(0.6).timeout
	var wall: StaticBody3D = null
	for n in main.get_children():
		if n is StaticBody3D and n.has_meta(&"lifetime"):
			wall = n
	check(wall != null and wall.collision_layer == 16, "a muralha existe e bloqueia")
	if wall:
		wall.queue_free()
