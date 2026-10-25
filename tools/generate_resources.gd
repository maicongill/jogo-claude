extends SceneTree
## Gera os .tres de conteúdo em res://resources/. Rodar uma vez (e de novo ao mudar números aqui):
## godot --headless --path . --script res://tools/generate_resources.gd
## Depois disso os .tres são a fonte da verdade: dá para editar no inspetor.

var items: Dictionary = {}


func _init() -> void:
	_items()
	_resource_nodes()
	_recipes()
	_build_pieces()
	print("Recursos gerados.")
	quit()


func _item(id: String, display: String, kind: ItemData.Kind, color: Color, extra: Dictionary = {}) -> ItemData:
	var it := ItemData.new()
	it.id = StringName(id)
	it.display_name = display
	it.kind = kind
	it.color = color
	for k in extra:
		it.set(k, extra[k])
	items[id] = it
	_save(it, "res://resources/items/%s.tres" % id)
	return it


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Falha ao salvar %s (%d)" % [path, err])


func _items() -> void:
	_item("wood", "Madeira", ItemData.Kind.RESOURCE, Color(0.55, 0.38, 0.2), {"description": "Tronco cortado. Serve para quase tudo."})
	_item("stone", "Pedra", ItemData.Kind.RESOURCE, Color(0.6, 0.6, 0.64), {"description": "Pedra lascada."})
	_item("berries", "Frutinhas", ItemData.Kind.FOOD, Color(0.85, 0.15, 0.3), {"food_value": 15.0, "description": "Doces e frescas. Recuperam um pouco de fome."})
	_tool("wooden_axe", "Machado de madeira", "axe", 1, 2.0, 40, 6.0, Color(0.7, 0.5, 0.3))
	_tool("wooden_pickaxe", "Picareta de madeira", "pickaxe", 1, 2.0, 40, 5.0, Color(0.65, 0.48, 0.3))
	_tool("stone_axe", "Machado de pedra", "axe", 2, 3.5, 80, 9.0, Color(0.55, 0.55, 0.6))
	_tool("stone_pickaxe", "Picareta de pedra", "pickaxe", 2, 3.5, 80, 8.0, Color(0.5, 0.5, 0.56))
	_weapon("wooden_sword", "Espada de madeira", "sword", 1, 60, 14.0, Color(0.72, 0.52, 0.32))
	_weapon("stone_sword", "Espada de pedra", "sword", 2, 110, 22.0, Color(0.6, 0.6, 0.66))
	_weapon("bow", "Arco", "bow", 1, 90, 18.0, Color(0.6, 0.4, 0.25))
	_item("arrow", "Flecha", ItemData.Kind.AMMO, Color(0.85, 0.8, 0.7), {"description": "Munição para o arco.", "stack_max": 64})
	_item("meat", "Carne", ItemData.Kind.FOOD, Color(0.8, 0.35, 0.3), {"food_value": 30.0, "description": "Solta por criaturas da floresta."})
	_item("saddle", "Sela", ItemData.Kind.SADDLE, Color(0.5, 0.3, 0.2), {"stack_max": 1, "description": "Permite montar um pet domado."})
	_item("bed", "Cama", ItemData.Kind.PLACEABLE, Color(0.8, 0.4, 0.4), {"place_id": &"bed", "stack_max": 1, "description": "Você renasce nela quando morre."})
	_item("magic_table", "Mesa de magia", ItemData.Kind.PLACEABLE, Color(0.5, 0.35, 0.8), {"place_id": &"magic_table", "stack_max": 1, "description": "Combina itens para criar pergaminhos."})
	_item("stable", "Estábulo", ItemData.Kind.PLACEABLE, Color(0.55, 0.42, 0.28), {"place_id": &"stable", "stack_max": 1, "description": "Seu pet renasce aqui se morrer."})
	_item("sapling", "Muda", ItemData.Kind.SEED, Color(0.35, 0.75, 0.3), {"place_id": &"sapling", "description": "Plante no chão para crescer uma árvore."})


func _tool(id: String, display: String, kind: String, level: int, power: float, durability: int, damage: float, color: Color) -> void:
	_item(id, display, ItemData.Kind.TOOL, color, {"tool_kind": StringName(kind), "tool_level": level, "tool_power": power,
			"max_durability": durability, "damage": damage, "stack_max": 1})


func _weapon(id: String, display: String, kind: String, level: int, durability: int, damage: float, color: Color) -> void:
	_item(id, display, ItemData.Kind.WEAPON, color, {"tool_kind": StringName(kind), "tool_level": level,
			"max_durability": durability, "damage": damage, "stack_max": 1})


func _node(id: String, display: String, mesh: String, drop: String, d_min: int, d_max: int, extra: Dictionary) -> void:
	var n := ResourceNodeData.new()
	n.id = StringName(id)
	n.display_name = display
	n.mesh_id = StringName(mesh)
	n.drop_item = items[drop]
	n.drop_min = d_min
	n.drop_max = d_max
	for k in extra:
		n.set(k, extra[k])
	_save(n, "res://resources/resource_nodes/%s.tres" % id)


func _resource_nodes() -> void:
	_node("tree", "Árvore", "tree", "wood", 2, 3, {"hits": 6.0, "tool_kind": &"axe", "hand_damage": 1.0, "flammable": true,
			"bonus_item": items["sapling"], "bonus_chance": 0.4, "density_plain": 0.02, "density_forest": 0.38,
			"radius": 0.4, "height": 5.0, "scale_min": 0.9, "scale_max": 1.35})
	_node("rock", "Pedra", "rock", "stone", 2, 3, {"hits": 8.0, "tool_kind": &"pickaxe", "min_tool_level": 1, "hand_damage": 0.0,
			"density_plain": 0.04, "density_forest": 0.025, "radius": 0.85, "height": 1.0, "scale_min": 0.8, "scale_max": 1.3})
	_node("bush", "Arbusto de frutinhas", "bush", "berries", 2, 4, {"hits": 1.0, "hand_damage": 1.0, "respawn_time": 90.0,
			"density_plain": 0.05, "density_forest": 0.06, "radius": 0.55, "height": 1.0, "scale_min": 0.9, "scale_max": 1.2})


func _recipe(id: String, output: String, out_count: int, ingredients: Array) -> void:
	var r := RecipeData.new()
	r.id = StringName(id)
	r.output = items[output]
	r.output_count = out_count
	for pair: Array in ingredients:
		r.inputs.append(items[pair[0]])
		r.input_counts.append(pair[1])
	_save(r, "res://resources/recipes/%s.tres" % id)


func _piece(id: String, display: String, cost: Array, hp := 40.0) -> void:
	var d := BuildPieceData.new()
	d.id = StringName(id)
	d.display_name = display
	for pair: Array in cost:
		d.cost_items.append(items[pair[0]])
		d.cost_counts.append(pair[1])
	d.fire_hp = hp
	_save(d, "res://resources/build_pieces/%s.tres" % id)


func _build_pieces() -> void:
	_piece("floor", "Piso", [["wood", 5]])
	_piece("wall", "Parede", [["wood", 3]])
	_piece("door", "Porta", [["wood", 4]])
	_piece("roof", "Telhado", [["wood", 4]])
	_piece("stairs", "Escada", [["wood", 6]])


func _recipes() -> void:
	_recipe("wooden_axe", "wooden_axe", 1, [["wood", 3]])
	_recipe("wooden_pickaxe", "wooden_pickaxe", 1, [["wood", 3]])
	_recipe("stone_axe", "stone_axe", 1, [["wood", 2], ["stone", 3]])
	_recipe("stone_pickaxe", "stone_pickaxe", 1, [["wood", 2], ["stone", 3]])
	_recipe("wooden_sword", "wooden_sword", 1, [["wood", 4]])
	_recipe("stone_sword", "stone_sword", 1, [["wood", 2], ["stone", 3]])
	_recipe("bow", "bow", 1, [["wood", 5]])
	_recipe("arrow", "arrow", 4, [["wood", 1], ["stone", 1]])
	_recipe("saddle", "saddle", 1, [["wood", 10], ["stone", 6]])
	_recipe("bed", "bed", 1, [["wood", 8], ["berries", 2]])
	_recipe("magic_table", "magic_table", 1, [["wood", 8], ["stone", 6]])
	_recipe("stable", "stable", 1, [["wood", 14], ["stone", 4]])
