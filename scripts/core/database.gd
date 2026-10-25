extends Node
## Registro de todo o conteúdo (itens, receitas, recursos do mundo, magias, pets, peças).
## Os objetos são montados a partir de config/game_config.json. Em F10 são atualizados no lugar
## (os mesmos objetos), então o que está no inventário também muda.

var items: Dictionary = {}              # StringName -> ItemData
var recipes: Array[RecipeData] = []
var resource_nodes: Array[ResourceNodeData] = []
var build_pieces: Array[BuildPieceData] = []
var magic: Dictionary = {}              # StringName -> MagicData
var scroll_recipes: Array[ScrollRecipeData] = []
var pets: Dictionary = {}               # StringName -> PetData


func _ready() -> void:
	reload()


func item(id: StringName) -> ItemData:
	return items.get(id) as ItemData


func spell(id: StringName) -> MagicData:
	return magic.get(id) as MagicData


func reload() -> void:
	var cfg := Config.data
	_build_items(cfg.get("items", {}))
	_build_resource_nodes(cfg.get("resource_nodes", {}))
	_build_recipes(cfg.get("recipes", {}))
	_build_magics(cfg.get("magics", {}))
	_build_scrolls(cfg.get("scroll_recipes", {}))
	_build_pets(cfg.get("pets", {}))
	_build_pieces(cfg.get("build_pieces", {}))


# ---------------------------------------------------------------- construtores

## Reaproveita o objeto existente (mantendo a identidade) copiando para ele os valores novos.
func _reuse(existing: Resource, fresh: Resource) -> Resource:
	if existing == null:
		return fresh
	for p in fresh.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v: Variant = fresh.get(p["name"])
			if v is Array:
				existing.get(p["name"]).assign(v)
			else:
				existing.set(p["name"], v)
	return existing


func _item_ref(id: Variant) -> ItemData:
	if id == null or String(id) == "":
		return null
	var it := item(StringName(String(id)))
	if it == null:
		push_error("game_config.json: item desconhecido \"%s\"" % id)
	return it


func _build_items(d: Dictionary) -> void:
	for key: String in d:
		var e: Dictionary = d[key]
		var it := ItemData.new()
		it.id = StringName(key)
		it.display_name = e.get("name", key)
		it.description = e.get("description", "")
		var kind: String = e.get("kind", "RESOURCE")
		it.kind = ItemData.Kind[kind] if ItemData.Kind.has(kind) else ItemData.Kind.RESOURCE
		it.stack_max = int(e.get("stack_max", 64))
		it.color = Config.to_color(e.get("color"))
		it.tool_kind = StringName(e.get("tool_kind", ""))
		it.tool_level = int(e.get("tool_level", 0))
		it.tool_power = float(e.get("tool_power", 1.0))
		it.damage = float(e.get("damage", 0.0))
		it.max_durability = int(e.get("max_durability", 0))
		it.food_value = float(e.get("food_value", 0.0))
		it.place_id = StringName(e.get("place_id", ""))
		it.magic_id = StringName(e.get("magic_id", ""))
		items[it.id] = _reuse(items.get(it.id), it)
	for id: StringName in items.keys():
		if not d.has(String(id)):
			items.erase(id)


func _build_resource_nodes(d: Dictionary) -> void:
	var old := {}
	for n in resource_nodes:
		old[n.id] = n
	resource_nodes.clear()
	for key: String in d:
		var e: Dictionary = d[key]
		var n := ResourceNodeData.new()
		n.id = StringName(key)
		n.display_name = e.get("name", key)
		n.mesh_id = StringName(e.get("mesh", "tree"))
		n.drop_item = _item_ref(e.get("drop"))
		n.drop_min = int(e.get("drop_min", 1))
		n.drop_max = int(e.get("drop_max", 1))
		n.bonus_item = _item_ref(e.get("bonus_item"))
		n.bonus_chance = float(e.get("bonus_chance", 0.0))
		n.hits = float(e.get("hits", 5.0))
		n.tool_kind = StringName(e.get("tool_kind", ""))
		n.min_tool_level = int(e.get("min_tool_level", 0))
		n.hand_damage = float(e.get("hand_damage", 1.0))
		n.respawn_time = float(e.get("respawn_time", 0.0))
		n.flammable = bool(e.get("flammable", false))
		n.density_plain = float(e.get("density_plain", 0.0))
		n.density_forest = float(e.get("density_forest", 0.0))
		n.radius = float(e.get("radius", 0.5))
		n.height = float(e.get("height", 2.0))
		n.scale_min = float(e.get("scale_min", 0.9))
		n.scale_max = float(e.get("scale_max", 1.2))
		resource_nodes.append(_reuse(old.get(n.id), n))


func _inputs(d: Dictionary, items_out: Array, counts_out: Array) -> void:
	items_out.clear()
	counts_out.clear()
	for id: String in d:
		var it := _item_ref(id)
		if it != null:
			items_out.append(it)
			counts_out.append(int(d[id]))


func _build_recipes(d: Dictionary) -> void:
	var old := {}
	for r in recipes:
		old[r.id] = r
	recipes.clear()
	for key: String in d:
		var e: Dictionary = d[key]
		var r := RecipeData.new()
		r.id = StringName(key)
		r.output = _item_ref(e.get("output"))
		r.output_count = int(e.get("count", 1))
		_inputs(e.get("inputs", {}), r.inputs, r.input_counts)
		recipes.append(_reuse(old.get(r.id), r))


func _build_magics(d: Dictionary) -> void:
	for key: String in d:
		var e: Dictionary = d[key]
		var m := MagicData.new()
		m.id = StringName(key)
		m.display_name = e.get("name", key)
		m.description = e.get("description", "")
		m.element = StringName(e.get("element", ""))
		m.effect = StringName(e.get("effect", ""))
		m.mana_cost = float(e.get("mana_cost", 20.0))
		m.cooldown = float(e.get("cooldown", 0.8))
		m.damage = float(e.get("damage", 0.0))
		m.radius = float(e.get("radius", 2.5))
		m.range = float(e.get("range", 25.0))
		m.color = Config.to_color(e.get("color"))
		m.learned_by_default = bool(e.get("learned_by_default", false))
		magic[m.id] = _reuse(magic.get(m.id), m)
	for id: StringName in magic.keys():
		if not d.has(String(id)):
			magic.erase(id)


func _build_scrolls(d: Dictionary) -> void:
	var old := {}
	for r in scroll_recipes:
		old[r.id] = r
	scroll_recipes.clear()
	for key: String in d:
		var e: Dictionary = d[key]
		var r := ScrollRecipeData.new()
		r.id = StringName(key)
		r.scroll = _item_ref(e.get("scroll"))
		_inputs(e.get("inputs", {}), r.inputs, r.input_counts)
		scroll_recipes.append(_reuse(old.get(r.id), r))


func _build_pets(d: Dictionary) -> void:
	for key: String in d:
		var e: Dictionary = d[key]
		var p := PetData.new()
		p.id = StringName(key)
		p.display_name = e.get("name", key)
		p.favorite_food = _item_ref(e.get("favorite_food"))
		p.favorite_biome = StringName(e.get("favorite_biome", "forest"))
		var th: Array[int] = []
		for v in e.get("trust_thresholds", [30, 60, 100]):
			th.append(int(v))
		p.trust_thresholds = th
		p.max_health = float(e.get("max_health", 60.0))
		p.max_stamina = float(e.get("max_stamina", 100.0))
		p.fly_speed = float(e.get("fly_speed", 9.0))
		p.fast_speed = float(e.get("fast_speed", 16.0))
		p.stamina_drain = float(e.get("stamina_drain", 22.0))
		p.stamina_regen = float(e.get("stamina_regen", 14.0))
		pets[p.id] = _reuse(pets.get(p.id), p)


func _build_pieces(d: Dictionary) -> void:
	var old := {}
	for b in build_pieces:
		old[b.id] = b
	build_pieces.clear()
	for key: String in d:
		var e: Dictionary = d[key]
		var b := BuildPieceData.new()
		b.id = StringName(key)
		b.display_name = e.get("name", key)
		_inputs(e.get("cost", {}), b.cost_items, b.cost_counts)
		b.flammable = bool(e.get("flammable", true))
		b.fire_hp = float(e.get("fire_hp", 40.0))
		build_pieces.append(_reuse(old.get(b.id), b))
