class_name PlayerInteraction
extends Node
## Interação do jogador com o mundo: coletar (E ou clique), plantar, trocar de item na hotbar.

const REACH := 3.6
const PLACE_REACH := 6.0
const SWING_COOLDOWN := 0.45
## Camadas físicas: 1 terreno, 4 recursos, 5 construções.
const RAY_MASK := 1 | 8 | 16

var player: Player
var _cooldown := 0.0


func _ready() -> void:
	player = get_parent() as Player


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if Game.is_ui_open():
		return
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			player.select_slot(i)
			return
	if not Game.build_mode:
		if event.is_action_pressed(&"build_next"):
			player.select_slot(player.selected_slot + 1)
			return
		if event.is_action_pressed(&"build_prev"):
			player.select_slot(player.selected_slot - 1)
			return
	if event.is_action_pressed(&"attack") and Game.build_mode:
		return  # o modo de construção usa o clique
	if event.is_action_pressed(&"interact"):
		primary_action()
	elif event.is_action_pressed(&"attack"):
		primary_action(true)


## Raio que sai do centro da tela. Devolve o resultado do raycast (vazio se nada foi atingido).
func aim_ray(mask: int = RAY_MASK, length := 14.0) -> Dictionary:
	var cam := player.camera
	var from := cam.global_position
	var to := from + player.camera_forward() * length
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)


func primary_action(from_attack := false) -> void:
	if _cooldown > 0.0 or player.stats.dead:
		return
	var held := player.held_item()
	if from_attack and held != null and held.kind == ItemData.Kind.WEAPON:
		player.combat.attack(held)
		return
	var hit := aim_ray()
	var collider: Object = hit["collider"] if not hit.is_empty() else null
	var in_reach := collider != null and _within_reach(hit["position"], REACH)
	if in_reach and collider.has_method("interact"):
		_cooldown = 0.3
		collider.interact(player)
		return
	if in_reach and collider.has_method("damage_shape"):
		_harvest(held, hit)
		return
	if from_attack and (held == null or held.kind == ItemData.Kind.TOOL):
		player.combat.attack(held)  # sem alvo para coletar: usa como arma (ou soco)
		return
	if held == null:
		return
	match held.kind:
		ItemData.Kind.SEED:
			_plant(held)
		ItemData.Kind.PLACEABLE:
			_place(held)
		ItemData.Kind.FOOD:
			_eat(held)
		ItemData.Kind.SCROLL:
			_read_scroll(held)
		_:
			if collider != null and collider.has_method("damage_shape"):
				EventBus.message.emit("Muito longe.")


func _within_reach(point: Vector3, reach: float) -> bool:
	return point.distance_to(player.global_position + Vector3(0, 1.0, 0)) <= reach


func _harvest(tool_item: ItemData, hit: Dictionary) -> void:
	var collider := hit["collider"] as Object
	var held_tool := tool_item if tool_item != null and tool_item.kind == ItemData.Kind.TOOL else null
	var power: float = collider.power_for(held_tool)
	_cooldown = SWING_COOLDOWN
	_swing(hit["position"])
	if power <= 0.0:
		EventBus.message.emit(_needs_tool_text(collider))
		return
	var result: Dictionary = collider.damage_shape(hit["shape"], power)
	if not result["hit"]:
		return
	if held_tool != null and held_tool.tool_kind == collider.data.tool_kind:
		player.inventory.use_durability(player.selected_slot, 1)
	for drop: Dictionary in result["drops"]:
		collect(drop["item"], drop["count"])


func _eat(food: ItemData) -> void:
	if player.stats.hunger >= player.stats.max_hunger - 1.0:
		EventBus.message.emit("Você não está com fome.")
		return
	player.stats.eat(food.food_value)
	player.inventory.remove_from_slot(player.selected_slot, 1)
	_cooldown = 0.4
	EventBus.message.emit("Comeu %s." % food.display_name)


func _read_scroll(scroll: ItemData) -> void:
	var spell := Database.spell(scroll.magic_id)
	if spell == null:
		return
	if player.magic.learn(spell.id):
		player.inventory.remove_from_slot(player.selected_slot, 1)
		EventBus.message.emit("Você aprendeu: %s! (V abre o livro de magia)" % spell.display_name)
	else:
		EventBus.message.emit("Você já conhece essa magia.")
	_cooldown = 0.4


func _place(item: ItemData) -> void:
	var hit := aim_ray(1, PLACE_REACH + player.camera.global_position.distance_to(player.global_position))
	if hit.is_empty() or not _within_reach(hit["position"], PLACE_REACH):
		EventBus.message.emit("Mire no chão perto de você.")
		return
	var node := Placeables.create(item.place_id)
	if node == null:
		return
	player.get_parent().add_child(node)
	node.global_position = hit["position"]
	node.rotation.y = player.camera.global_rotation.y
	player.inventory.remove_from_slot(player.selected_slot, 1)
	_cooldown = 0.4
	EventBus.message.emit("%s colocado." % item.display_name)
	if node.has_method("interact") and item.place_id == &"bed":
		node.interact(player)


func _needs_tool_text(collider: Object) -> String:
	var kind: StringName = collider.data.tool_kind
	var name := "ferramenta"
	if kind == &"pickaxe":
		name = "picareta"
	elif kind == &"axe":
		name = "machado"
	return "Precisa de uma %s melhor." % name


## Guarda o item no inventário e avisa o jogador.
func collect(item: ItemData, count: int) -> void:
	var left := player.inventory.add(item, count)
	if left < count:
		EventBus.item_collected.emit(item, count - left)
	if left > 0:
		EventBus.message.emit("Inventário cheio: perdeu %d %s." % [left, item.display_name])


func _plant(seed_item: ItemData) -> void:
	var hit := aim_ray(1, PLACE_REACH + player.camera.global_position.distance_to(player.global_position))
	if hit.is_empty() or not _within_reach(hit["position"], PLACE_REACH):
		EventBus.message.emit("Mire no chão perto de você para plantar.")
		return
	for node in get_tree().get_nodes_in_group(&"planted"):
		if (node as Node3D).global_position.distance_to(hit["position"]) < 1.5:
			EventBus.message.emit("Muito perto de outra muda.")
			return
	var tree := PlantedTree.new()
	tree.add_to_group(&"planted")
	player.get_parent().add_child(tree)
	tree.global_position = hit["position"]
	player.inventory.remove_from_slot(player.selected_slot, 1)
	_cooldown = SWING_COOLDOWN
	_swing(hit["position"])
	EventBus.message.emit("Muda plantada. Ela vai crescer com o tempo.")


## Pequena "pancada" visual: o personagem vira para o alvo e dá um impulso.
func _swing(target: Vector3) -> void:
	var dir := target - player.global_position
	dir.y = 0.0
	if dir.length() > 0.1:
		player.face_direction(dir.normalized())
	var model := player.get_node("Model") as Node3D
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.0, 0.94, 1.0), 0.08)
	tw.tween_property(model, "scale", Vector3.ONE, 0.12)
