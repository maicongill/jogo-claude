class_name BuildSystem
extends Node
## Modo de construção: peça "fantasma", encaixe por sockets, grade opcional, estabilidade e demolição.

const ORDER: Array[StringName] = [&"floor", &"wall", &"door", &"roof", &"stairs"]

# Padrões; config/game_config.json (seção "building") sobrescreve em apply_config().
static var stab_min := 0.3
var snap_distance := 3.0
var build_reach := 14.0
var refund_fraction := 0.5

var player: Player
var world_root: Node3D
var height_fn: Callable  # (x, z) -> altura do terreno

var active := false
var grid_enabled := true
var selected := 0
var rot_steps := 0

var pieces_data: Array[BuildPieceData] = []
var target: Dictionary = {}

var _ghost: Node3D
var _ghost_mats: Array[StandardMaterial3D] = []
var _label: Label
var _layer: CanvasLayer


static func apply_config() -> void:
	var c := Config.section("building")
	stab_min = c.get("stability_min", stab_min)
	PieceGeometry.decay_slab = c.get("decay_slab_to_slab", PieceGeometry.decay_slab)
	PieceGeometry.decay_stairs = c.get("decay_stairs", PieceGeometry.decay_stairs)
	PieceGeometry.decay_other = c.get("decay_other", PieceGeometry.decay_other)


func _reload_local() -> void:
	apply_config()
	var c := Config.section("building")
	snap_distance = c.get("snap_distance", snap_distance)
	build_reach = c.get("build_reach", build_reach)
	refund_fraction = c.get("refund_fraction", refund_fraction)


func setup(p: Player, root: Node3D, height_function: Callable) -> void:
	_reload_local()
	Config.reloaded.connect(_reload_local)
	player = p
	world_root = root
	height_fn = height_function
	for id in ORDER:
		for d in Database.build_pieces:
			if d.id == id:
				pieces_data.append(d)
	_layer = CanvasLayer.new()
	_layer.layer = 9
	add_child(_layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_top = -150
	_label.offset_bottom = -80
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.visible = false
	_layer.add_child(_label)
	EventBus.piece_destroyed.connect(_on_piece_destroyed)


func current_data() -> BuildPieceData:
	return pieces_data[selected]


func set_active(on: bool) -> void:
	active = on
	Game.build_mode = on
	_label.visible = on
	if on:
		_rebuild_ghost()
	elif _ghost != null:
		_ghost.queue_free()
		_ghost = null
	EventBus.build_mode_changed.emit(on)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"build_mode") and (active or not Game.is_ui_open()):
		set_active(not active)
		return
	if not active or Game.is_ui_open():
		return
	if event.is_action_pressed(&"build_next"):
		select(selected + 1)
	elif event.is_action_pressed(&"build_prev"):
		select(selected - 1)
	elif event.is_action_pressed(&"build_rotate"):
		rot_steps += 1
	elif event.is_action_pressed(&"build_grid"):
		grid_enabled = not grid_enabled
	elif event.is_action_pressed(&"attack"):
		try_place()
	elif event.is_action_pressed(&"secondary"):
		demolish_aimed()


func select(i: int) -> void:
	selected = posmod(i, pieces_data.size())
	_rebuild_ghost()


func _rebuild_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = Node3D.new()
	_ghost_mats.clear()
	for v in PieceGeometry.make_visuals(current_data().id):
		var mi := v as MeshInstance3D
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		_ghost_mats.append(m)
		_ghost.add_child(mi)
	world_root.add_child(_ghost)


func _process(_delta: float) -> void:
	if not active or player == null:
		return
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + player.camera_forward() * 30.0, 1 | 16)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	var d := current_data()
	if hit.is_empty() or hit["position"].distance_to(player.global_position) > build_reach:
		target = {"valid": false, "reason": "Mire em um lugar próximo."}
		_ghost.visible = false
	else:
		target = compute_target(hit["position"])
		_ghost.visible = target.has("xf")
		if target.has("xf"):
			_ghost.global_transform = target["xf"]
	var color := Color(0.3, 1.0, 0.4, 0.45) if target.get("valid", false) else Color(1.0, 0.3, 0.25, 0.45)
	for m in _ghost_mats:
		m.albedo_color = color
	var cost := _cost_text(d)
	_label.text = "CONSTRUIR: %s   (%s)\nRoda do mouse: trocar peça | R: girar | G: grade %s | Clique esq.: construir | Clique dir.: demolir | B: sair\n%s" % [
			d.display_name, cost, "LIGADA" if grid_enabled else "desligada", "" if target.get("valid", false) else target.get("reason", "")]


func _cost_text(d: BuildPieceData) -> String:
	var parts: PackedStringArray = []
	for i in d.cost_items.size():
		parts.append("%d %s" % [d.cost_counts[i], d.cost_items[i].display_name])
	return ", ".join(parts)


# ---------------------------------------------------------------- alvo e validação

func compute_target(hit_pos: Vector3, piece_index := -1) -> Dictionary:
	var d := pieces_data[selected if piece_index < 0 else piece_index]
	var id := d.id
	var best: Dictionary = {}
	var best_dist := snap_distance
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		if p.global_position.distance_to(hit_pos) > build_reach + 6.0 or not PieceGeometry.accepts(p.piece_id, id):
			continue
		for off: Dictionary in PieceGeometry.offers(p.piece_id, p.global_transform):
			if off["id"] != id:
				continue
			var xf: Transform3D = off["xf"]
			var dist := _anchor(id, xf).distance_to(hit_pos)
			if dist < best_dist and not is_occupied(id, xf):
				best_dist = dist
				best = {"xf": xf}
	if best.is_empty():
		if id != &"floor":
			return {"valid": false, "reason": "Encaixe esta peça em outra já construída."}
		best = {"xf": _free_floor_transform(hit_pos)}
		if is_occupied(id, best["xf"]):
			return {"valid": false, "xf": best["xf"], "reason": "Já existe uma peça aqui."}
	var xf: Transform3D = best["xf"]
	var result := {"xf": xf, "valid": true, "reason": ""}
	var inv := player.inventory
	if not inv.has_items(d.cost_items, d.cost_counts):
		result["valid"] = false
		result["reason"] = "Faltam materiais: %s" % _cost_text(d)
		return result
	var neighbors := neighbors_for(id, xf)
	var grounded := is_grounded(id, xf)
	var stab := 1.0 if grounded else 0.0
	for n in neighbors:
		stab = maxf(stab, n.stability - PieceGeometry.decay(n.piece_id, id))
	result["neighbors"] = neighbors
	result["grounded"] = grounded
	result["stability"] = stab
	if stab < stab_min:
		result["valid"] = false
		result["reason"] = "Sem apoio suficiente (estabilidade %d%%)." % int(stab * 100)
	elif id == &"stairs":
		var low := xf.origin + xf.basis.z * PieceGeometry.STAIRS_RUN + Vector3(0, -PieceGeometry.STAIRS_RISE, 0)
		if absf(height_fn.call(low.x, low.z) - low.y) > 1.5:
			result["valid"] = false
			result["reason"] = "A escada precisa chegar ao chão."
	elif id == &"floor" and neighbors.is_empty():
		var low_gap := xf.origin.y - _min_ground(xf)
		if low_gap > 1.3:
			result["valid"] = false
			result["reason"] = "Terreno muito irregular aqui."
	return result


func _anchor(id: StringName, xf: Transform3D) -> Vector3:
	if PieceGeometry.family(id) == &"slab":
		return xf.origin
	return xf.origin + Vector3(0, 1.2, 0)


func _free_floor_transform(hit_pos: Vector3) -> Transform3D:
	var step := 90.0 if grid_enabled else 15.0
	var basis := Basis(Vector3.UP, deg_to_rad(step * rot_steps))
	var pos := hit_pos
	if grid_enabled:
		pos.x = roundf(pos.x / PieceGeometry.CELL) * PieceGeometry.CELL
		pos.z = roundf(pos.z / PieceGeometry.CELL) * PieceGeometry.CELL
	pos.y = _max_ground(Transform3D(basis, pos))
	return Transform3D(basis, pos)


func _footprint(xf: Transform3D) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var h := PieceGeometry.CELL * 0.5
	for p in [Vector3.ZERO, Vector3(h, 0, h), Vector3(-h, 0, h), Vector3(h, 0, -h), Vector3(-h, 0, -h)]:
		pts.append(xf.origin + xf.basis * p)
	return pts


func _max_ground(xf: Transform3D) -> float:
	var m := -INF
	for p in _footprint(xf):
		m = maxf(m, height_fn.call(p.x, p.z))
	return m


func _min_ground(xf: Transform3D) -> float:
	var m := INF
	for p in _footprint(xf):
		m = minf(m, height_fn.call(p.x, p.z))
	return m


func is_grounded(id: StringName, xf: Transform3D) -> bool:
	match PieceGeometry.family(id):
		&"slab":
			return _max_ground(xf) >= xf.origin.y - 0.4
		&"wall":
			var h: float = height_fn.call(xf.origin.x, xf.origin.z)
			return h >= xf.origin.y - 0.4 and h <= xf.origin.y + 1.0
	var low := xf.origin + xf.basis.z * PieceGeometry.STAIRS_RUN + Vector3(0, -PieceGeometry.STAIRS_RISE, 0)
	return height_fn.call(low.x, low.z) >= low.y - 0.4


## Já existe uma peça ocupando este lugar?
func is_occupied(id: StringName, xf: Transform3D) -> bool:
	var fam := PieceGeometry.family(id)
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		if PieceGeometry.family(p.piece_id) != fam:
			continue
		if p.global_position.distance_to(xf.origin) > 0.35:
			continue
		if fam == &"slab" or absf(p.global_basis.z.dot(xf.basis.z)) > 0.9:
			return true
	return false


## Peças existentes que se conectam a uma peça colocada neste lugar.
func neighbors_for(id: StringName, xf: Transform3D) -> Array[BuildPiece]:
	var out: Array[BuildPiece] = []
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		if p.global_position.distance_to(xf.origin) > 12.0 or not PieceGeometry.accepts(p.piece_id, id):
			continue
		for off: Dictionary in PieceGeometry.offers(p.piece_id, p.global_transform):
			var oxf: Transform3D = off["xf"]
			if off["id"] == id and oxf.origin.distance_to(xf.origin) < 0.3 and \
					(PieceGeometry.family(id) == &"slab" or absf(oxf.basis.z.dot(xf.basis.z)) > 0.9):
				out.append(p)
				break
	# Peças que ficam por cima/ao lado e que esta nova peça passa a sustentar (ex.: parede sob um telhado).
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		if p in out or p.global_position.distance_to(xf.origin) > 12.0 or not PieceGeometry.accepts(id, p.piece_id):
			continue
		for off: Dictionary in PieceGeometry.offers(id, xf):
			var oxf: Transform3D = off["xf"]
			if off["id"] == p.piece_id and oxf.origin.distance_to(p.global_position) < 0.3 and \
					(PieceGeometry.family(p.piece_id) == &"slab" or absf(oxf.basis.z.dot(p.global_basis.z)) > 0.9):
				out.append(p)
				break
	return out


# ---------------------------------------------------------------- construir / demolir

func try_place() -> BuildPiece:
	if target.is_empty() or not target.get("valid", false):
		if target.has("reason") and target["reason"] != "":
			EventBus.message.emit(target["reason"])
		return null
	return place(current_data(), target)


func place(d: BuildPieceData, t: Dictionary) -> BuildPiece:
	var inv := player.inventory
	for i in d.cost_items.size():
		inv.remove(d.cost_items[i], d.cost_counts[i])
	var piece := BuildPiece.new()
	piece.setup(d)
	world_root.add_child(piece)
	piece.global_transform = t["xf"]
	piece.grounded = t["grounded"]
	for n: BuildPiece in t["neighbors"]:
		piece.links.append(n)
		n.links.append(piece)
	recompute_stability()
	EventBus.piece_placed.emit(piece)
	return piece


func demolish_aimed() -> void:
	var cam := player.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + player.camera_forward() * 30.0, 16)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit["position"].distance_to(player.global_position) > build_reach:
		return
	var node := hit["collider"] as Node
	while node != null and not node is BuildPiece:
		node = node.get_parent()
	if node != null:
		demolish(node as BuildPiece)


## Remove a peça devolvendo metade do custo e faz desabar o que perdeu o apoio.
func demolish(piece: BuildPiece) -> void:
	var d := piece.data
	for i in d.cost_items.size():
		var back := int(d.cost_counts[i] * refund_fraction)
		if back > 0:
			player.inventory.add(d.cost_items[i], back)
	EventBus.message.emit("%s demolido." % d.display_name)
	piece.unlink_all()
	piece.remove_from_group(&"build_piece")
	piece.queue_free()
	recompute_stability()


func _on_piece_destroyed(piece: Node3D) -> void:
	var bp := piece as BuildPiece
	if bp == null or not bp.is_inside_tree():
		return
	bp.unlink_all()
	bp.remove_from_group(&"build_piece")
	bp.queue_free()
	recompute_stability()


## Recalcula a estabilidade de todas as peças e derruba as que ficaram sem apoio.
## Devolve quantas desabaram.
func recompute_stability() -> int:
	var collapsed := 0
	while true:
		var pieces: Array[BuildPiece] = []
		for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
			if not p.is_queued_for_deletion():
				pieces.append(p)
				p.stability = 1.0 if p.grounded else 0.0
		var changed := true
		var guard := 0
		while changed and guard < 200:
			changed = false
			guard += 1
			for p in pieces:
				for n in p.links:
					var cand := n.stability - PieceGeometry.decay(n.piece_id, p.piece_id)
					if cand > p.stability + 0.0001:
						p.stability = cand
						changed = true
		var fallen := false
		for p in pieces:
			if p.stability < stab_min:
				p.collapse()
				collapsed += 1
				fallen = true
		if not fallen:
			break
	if collapsed > 0:
		EventBus.message.emit("Parte da construção desabou!")
	return collapsed
