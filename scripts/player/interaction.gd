class_name PlayerInteraction
extends Node
## Interação do jogador com o mundo: coletar (E ou clique), plantar, trocar de item na hotbar.

const PLACE_REACH := 6.0

var reach := 3.6
var swing_cooldown := 0.45
## Camadas físicas: 1 terreno, 4 recursos, 5 construções.
const RAY_MASK := 1 | 8 | 16 | 64

var player: Player
var _cooldown := 0.0
## Prévia translúcida do objeto colocável na mão (cama, mesa de magia, estábulo).
var _ghost: Node3D
var _ghost_id: StringName
var _ghost_mat: StandardMaterial3D


func _apply_config() -> void:
	reach = Config.f("player.reach", reach)
	swing_cooldown = Config.f("player.swing_cooldown", swing_cooldown)


func _ready() -> void:
	player = get_parent() as Player
	_apply_config()
	Config.reloaded.connect(_apply_config)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_place_ghost()


func _update_place_ghost() -> void:
	var held := player.held_item()
	var show := held != null and held.kind == ItemData.Kind.PLACEABLE and not Game.is_ui_open() \
			and not Game.build_mode and player.mounted_pet == null and not player.stats.dead
	if not show:
		_clear_ghost()
		return
	if _ghost == null or _ghost_id != held.place_id:
		_clear_ghost()
		_ghost = Placeables.create_ghost(held.place_id)
		if _ghost == null:
			return
		_ghost_id = held.place_id
		if _ghost_mat == null:
			_ghost_mat = StandardMaterial3D.new()
			_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		player.get_parent().add_child(_ghost)
		Placeables.finish_ghost(_ghost, _ghost_mat)
	var spot := _place_spot(held.place_id)
	_ghost.visible = spot.has("pos")
	if spot.has("pos"):
		_ghost.global_position = spot["pos"]
		_ghost.rotation = Vector3(0, spot["yaw"], 0)
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.4, 0.45) if spot.get("valid", false) else Color(1.0, 0.3, 0.25, 0.45)


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
		_ghost_id = &""


## Onde o objeto colocável iria parar: {pos, yaw, valid, on}. Vazio se a mira não acerta onde pode.
## Alguns objetos (vaso) podem ir sobre qualquer superfície de cima: pisos, mesas, terreno.
func _place_spot(place_id: StringName = &"") -> Dictionary:
	var any_surface := Placeables.on_any_surface(place_id)
	var mask := 1 | 16 if any_surface else 1
	var q := PhysicsRayQueryParameters3D.create(player.camera.global_position,
			player.camera.global_position + player.camera_forward() * (PLACE_REACH + player.camera.global_position.distance_to(player.global_position)), mask)
	q.exclude = [player.get_rid()]
	if _ghost != null and _ghost is CollisionObject3D:
		q.exclude.append((_ghost as CollisionObject3D).get_rid())
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit["normal"]
	var valid := _within_reach(hit["position"], PLACE_REACH) and (not any_surface or n.y > 0.7)
	return {"pos": hit["position"], "yaw": player.camera.global_rotation.y, "valid": valid, "on": hit["collider"]}


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
	elif event.is_action_released(&"attack"):
		player.combat.release_charge()  # espada/arco: solta o golpe (carregado se segurou)


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
	if player.mounted_pet != null and not from_attack:
		_cooldown = 0.3
		player.mounted_pet.dismount()  # E também desmonta
		return
	var held := player.held_item()
	if from_attack and held != null and held.kind == ItemData.Kind.WEAPON:
		player.combat.begin_charge(held)
		return
	var hit := aim_ray()
	var collider: Object = hit["collider"] if not hit.is_empty() else null
	var in_reach := collider != null and _within_reach(hit["position"], reach)
	if in_reach and collider.has_method("interact"):
		_cooldown = 0.3
		collider.interact(player)
		return
	# Ajuda de mira para o pet: não precisa acertar em cheio, basta ele estar perto do centro da tela.
	var pet := _aimed_pet(collider)
	if pet != null and not (in_reach and collider.has_method("damage_shape")):
		_cooldown = 0.3
		pet.interact(player)
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
		_:
			if collider != null and collider.has_method("damage_shape"):
				EventBus.message.emit("Muito longe.")


## Pet mais próximo do centro da tela, dentro do alcance de pet. Ignora pets escondidos atrás de algo.
func _aimed_pet(collider: Object) -> FlyingPet:
	var pet_reach := Config.f("pet.interact_reach", 6.5)
	var min_dot := cos(deg_to_rad(Config.f("pet.aim_assist_degrees", 14.0)))
	var cam_pos := player.camera.global_position
	var fwd := player.camera_forward()
	var best: FlyingPet = null
	for p: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if p.state == FlyingPet.State.DEAD or p.rider != null:
			continue
		var center := p.global_position + Vector3(0, 1.0, 0)
		if center.distance_to(player.global_position + Vector3(0, 1.0, 0)) > pet_reach:
			continue
		var to_pet := center - cam_pos
		if p == collider:
			return p
		var dot := fwd.dot(to_pet.normalized())
		if dot > min_dot and not _blocked(cam_pos, center):
			min_dot = dot
			best = p
	return best


## Algo sólido (terreno, árvore, parede) entre os dois pontos?
func _blocked(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 16)
	q.exclude = [player.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _within_reach(point: Vector3, max_dist: float) -> bool:
	return point.distance_to(player.global_position + Vector3(0, 1.0, 0)) <= max_dist


func _harvest(tool_item: ItemData, hit: Dictionary) -> void:
	var collider := hit["collider"] as Object
	var held_tool := tool_item if tool_item != null and tool_item.kind == ItemData.Kind.TOOL else null
	var power: float = collider.power_for(held_tool)
	_cooldown = swing_cooldown
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


func _place(item: ItemData) -> void:
	var spot := _place_spot(item.place_id)
	if not spot.get("valid", false):
		EventBus.message.emit("Mire em uma superfície plana perto de você." if Placeables.on_any_surface(item.place_id) else "Mire no chão perto de você.")
		return
	var node := Placeables.create(item.place_id)
	if node == null:
		return
	# Sobre uma peça de construção, o objeto vira filho dela (cai/some junto se ela desabar).
	var parent: Node = player.get_parent()
	var on: Object = spot.get("on")
	var host := on as Node
	while host != null and not host is BuildPiece:
		host = host.get_parent()
	if host != null and Placeables.on_any_surface(item.place_id):
		parent = host
	parent.add_child(node)
	node.global_position = spot["pos"]
	node.global_rotation = Vector3(0, spot["yaw"], 0)
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
	_cooldown = swing_cooldown
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
