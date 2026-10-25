class_name SaveSystem
extends RefCounted
## Salvar e carregar em um único JSON (PROPOSTA do marco 10, ver docs/PROPOSTAS.md).
## Guarda o que o jogador mudou; o terreno vem da seed, então não é salvo.

const VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _from_v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func _xf(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _from_xf(a: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])), Vector3(a[9], a[10], a[11]))


static func serialize(world: Node3D) -> Dictionary:
	var p: Player = world.player
	var inv: Array = []
	for s in p.inventory.slots:
		inv.append(null if s == null else {"id": String(s.item.id), "count": s.count, "dur": s.durability})
	var resources: Array = []
	for key: String in WorldState.resource_states:
		var inner: Dictionary = WorldState.resource_states[key]
		for idx: int in inner:
			resources.append({"key": key, "idx": idx, "hp": inner[idx][0], "at": inner[idx][1]})
	var pieces: Array = []
	for n in world.get_children():
		if n is BuildPiece and n.is_in_group(&"build_piece"):
			pieces.append({"id": String(n.piece_id), "xf": _xf(n.global_transform)})
	var plants: Array = []
	for n in world.get_tree().get_nodes_in_group(&"planted"):
		plants.append({"pos": _v3(n.global_position), "at": n.planted_at})
	var placed: Array = []
	for group in [&"bed", &"magic_table", &"stable"]:
		for n in world.get_tree().get_nodes_in_group(group):
			placed.append({"kind": String(group), "xf": _xf(n.global_transform)})
	var pets: Array = []
	for n: FlyingPet in world.get_tree().get_nodes_in_group(&"pet"):
		if n.trust > 0.0:
			pets.append({"pos": _v3(n.global_position), "trust": n.trust, "level": n.level, "saddled": n.saddled,
					"food": n.knows_food, "biome": n.knows_biome, "health": n.health})
	return {
		"version": VERSION,
		"seed": Game.world_seed,
		"time": WorldState.time,
		"options": {"lose_items": Game.lose_items_on_death},
		"player": {
			"pos": _v3(p.global_position), "health": p.stats.health, "hunger": p.stats.hunger,
			"slot": p.selected_slot, "inventory": inv, "mana": p.magic.mana,
			"spells": p.magic.learned.map(func(s: StringName) -> String: return String(s)), "spell": String(p.magic.selected),
		},
		"spawn_point": null if Game.spawn_point == Vector3.INF else _v3(Game.spawn_point),
		"resources": resources,
		"killed": WorldState.killed_enemies.keys(),
		"owned_pets": WorldState.owned_pets.keys(),
		"pieces": pieces, "plants": plants, "placed": placed, "pets": pets,
		"goals": world.goals.done.keys().map(func(g: StringName) -> String: return String(g)),
	}


static func save_to(world: Node3D, path := DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(serialize(world)))
	return true


static func has_save(path := DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func load_from(world: Node3D, path := DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version", 0) != VERSION or int(data["seed"]) != Game.world_seed:
		return false
	apply(world, data)
	return true


static func apply(world: Node3D, d: Dictionary) -> void:
	var tree := world.get_tree()
	var p: Player = world.player
	# 1) Limpa tudo que o jogador cria/muda no mundo.
	if p.mounted_pet != null:
		p.mounted_pet.dismount()
	for group in [&"build_piece", &"planted", &"bed", &"magic_table", &"stable", &"pet", &"enemy"]:
		for n in tree.get_nodes_in_group(group):
			n.remove_from_group(group)
			n.queue_free()
	Game.stables.clear()
	Game.spawn_point = Vector3.INF
	if is_instance_valid(world.spawner):
		world.spawner.enemies.clear()
	if is_instance_valid(world.pet_spawner):
		world.pet_spawner.pets.clear()

	# 2) Estado do mundo.
	WorldState.time = d["time"]
	WorldState.resource_states.clear()
	for r: Dictionary in d["resources"]:
		var inner := WorldState.resource_state(r["key"])
		inner[int(r["idx"])] = [r["hp"], r["at"]]
	WorldState.killed_enemies.clear()
	for k in d["killed"]:
		WorldState.killed_enemies[k] = true
	WorldState.owned_pets.clear()
	for k in d["owned_pets"]:
		WorldState.owned_pets[k] = true
	world.chunks.reload_all()

	# 3) Jogador.
	Game.lose_items_on_death = d["options"]["lose_items"]
	var pd: Dictionary = d["player"]
	p.inventory.clear()
	for i in pd["inventory"].size():
		var e: Variant = pd["inventory"][i]
		if e != null and Database.item(StringName(e["id"])) != null:
			var st := ItemStack.new(Database.item(StringName(e["id"])), int(e["count"]))
			st.durability = int(e["dur"])
			p.inventory.slots[i] = st
	p.inventory.changed.emit()
	p.select_slot(int(pd["slot"]))
	p.stats.dead = false
	p.stats.health = pd["health"]
	p.stats.hunger = pd["hunger"]
	p.stats.hurt(0.0)
	p.magic.mana = pd["mana"]
	p.magic.learned.clear()
	for s in pd["spells"]:
		p.magic.learned.append(StringName(s))
	p.magic.selected = StringName(pd["spell"])
	EventBus.spell_selected.emit(p.magic.current())
	EventBus.mana_changed.emit(p.magic.mana, p.magic.max_mana)
	p.global_position = _from_v3(pd["pos"]) + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	p.frozen = true  # o mundo libera quando o chão sob o jogador carregar

	# 4) Construções, plantas e objetos.
	var build: BuildSystem = world.build
	for e: Dictionary in d["pieces"]:
		var data: BuildPieceData = null
		for pd2 in build.pieces_data:
			if pd2.id == StringName(e["id"]):
				data = pd2
		if data == null:
			continue
		var xf := _from_xf(e["xf"])
		var piece := BuildPiece.new()
		piece.setup(data)
		world.add_child(piece)
		piece.global_transform = xf
		piece.grounded = build.is_grounded(data.id, xf)
		for n in build.neighbors_for(data.id, xf):
			piece.links.append(n)
			n.links.append(piece)
	for e: Dictionary in d["plants"]:
		var tree_node := PlantedTree.new()
		tree_node.add_to_group(&"planted")
		world.add_child(tree_node)
		tree_node.global_position = _from_v3(e["pos"])
		tree_node.planted_at = e["at"]
	for e: Dictionary in d["placed"]:
		var node := Placeables.create(StringName(e["kind"]))
		if node != null:
			world.add_child(node)
			node.global_transform = _from_xf(e["xf"])
			if e["kind"] == "bed":
				Game.spawn_point = node.global_position + Vector3(0, 0.6, 0) + node.global_basis.x * 1.4
	if d["spawn_point"] != null:
		Game.spawn_point = _from_v3(d["spawn_point"])
	for e: Dictionary in d["pets"]:
		var pet: FlyingPet = world.pet_spawner.create_pet(Database.pets.values()[0], _from_v3(e["pos"]))
		pet.trust = e["trust"]
		pet.level = int(e["level"])
		pet.saddled = e["saddled"]
		pet.knows_food = e["food"]
		pet.knows_biome = e["biome"]
		pet.health = e["health"]
		pet.state = FlyingPet.State.FOLLOW if pet.level >= 2 else FlyingPet.State.PERCH
		pet._update_label()

	# 5) Objetivos.
	world.goals.done.clear()
	for g in d["goals"]:
		world.goals.done[StringName(g)] = true
	world.hud.refresh_goals()
	world.build.recompute_stability()
