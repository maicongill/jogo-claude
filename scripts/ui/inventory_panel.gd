class_name InventoryPanel
extends PanelContainer
## Inventário em grade (9 colunas). Clique esquerdo pega/solta a pilha, direito pega metade / solta um.

var player: Player
var inventory: Inventory

const BAG_OFFSET := 1000  # índices de slot >= isso são do alforje do pet

var _slots: Array[SlotUI] = []
var _cursor: ItemStack
## Alforje do pet perto (ou montado); null se não houver.
var _pet: FlyingPet
var _bag_box: VBoxContainer
var _bag_title: Label
var _bag_grid: GridContainer
var _bag_slots: Array[SlotUI] = []
var _cursor_ui: SlotUI
var _content: VBoxContainer


func setup(p: Player) -> void:
	player = p
	inventory = p.inventory
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	row.add_child(_content)
	var title := Label.new()
	title.text = "Inventário  (Tab para fechar)"
	title.add_theme_font_size_override("font_size", 18)
	_content.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)
	# Mochila em cima, hotbar embaixo.
	var order: Array[int] = []
	for i in range(Inventory.HOTBAR_SIZE, inventory.size()):
		order.append(i)
	for i in Inventory.HOTBAR_SIZE:
		order.append(i)
	_slots.resize(inventory.size())
	for i in order:
		var slot := SlotUI.new()
		slot.index = i
		slot.pressed.connect(_on_slot_pressed)
		grid.add_child(slot)
		_slots[i] = slot

	_bag_box = VBoxContainer.new()
	_bag_box.add_theme_constant_override("separation", 6)
	_bag_box.visible = false
	_content.add_child(_bag_box)
	_bag_title = Label.new()
	_bag_box.add_child(_bag_title)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 9
	_bag_grid.add_theme_constant_override("h_separation", 4)
	_bag_grid.add_theme_constant_override("v_separation", 4)
	_bag_box.add_child(_bag_grid)

	_cursor_ui = SlotUI.new()
	_cursor_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ui.top_level = true
	_cursor_ui.size = Vector2(54, 54)
	_cursor_ui.visible = false
	add_child(_cursor_ui)

	inventory.changed.connect(refresh)
	refresh()


## Painéis extras (receitas...) entram à direita do inventário.
func add_side_panel(node: Control) -> void:
	get_child(0).get_child(0).add_child(node)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		_close()
	elif not Game.is_ui_open():
		visible = true
		Game.push_ui()
		_attach_bag(_find_pet())
		refresh()


## Pet selado montado ou a poucos metros: o alforje dele aparece embaixo do inventário.
func _find_pet() -> FlyingPet:
	if player.mounted_pet != null:
		return player.mounted_pet
	var best: FlyingPet = null
	var best_d := Config.f("pet.bag_reach", 6.0)
	for p: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if not p.saddled or p.state == FlyingPet.State.DEAD or p.bag == null:
			continue
		var d := p.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _attach_bag(pet: FlyingPet) -> void:
	if _pet != null and is_instance_valid(_pet) and _pet.bag.changed.is_connected(refresh):
		_pet.bag.changed.disconnect(refresh)
	_pet = pet
	_bag_box.visible = pet != null
	if pet == null:
		return
	pet.bag.changed.connect(refresh)
	_bag_title.text = "Alforje de %s  (Shift + clique move a pilha)" % pet.data.display_name
	if _bag_slots.size() != pet.bag.size():
		for c in _bag_slots:
			c.queue_free()
		_bag_slots.clear()
		for i in pet.bag.size():
			var slot := SlotUI.new()
			slot.index = BAG_OFFSET + i
			slot.pressed.connect(_on_slot_pressed)
			_bag_grid.add_child(slot)
			_bag_slots.append(slot)


func _close() -> void:
	if _cursor != null:
		var left := inventory.add(_cursor.item, _cursor.count)
		_cursor = null
		if left > 0:
			EventBus.message.emit("Inventário cheio.")
	visible = false
	_cursor_ui.visible = false
	Game.pop_ui()


func _process(_delta: float) -> void:
	if _cursor_ui.visible:
		_cursor_ui.global_position = get_global_mouse_position() - _cursor_ui.size * 0.5


func refresh() -> void:
	for i in _slots.size():
		_slots[i].set_stack(inventory.get_stack(i))
		_slots[i].selected = i == player.selected_slot
	if _pet != null and is_instance_valid(_pet):
		for i in _bag_slots.size():
			_bag_slots[i].set_stack(_pet.bag.get_stack(i))
	_cursor_ui.set_stack(_cursor)
	_cursor_ui.visible = visible and _cursor != null


func _on_slot_pressed(index: int, button: int) -> void:
	var inv := inventory
	var i := index
	if index >= BAG_OFFSET:
		if _pet == null or not is_instance_valid(_pet):
			return
		inv = _pet.bag
		i = index - BAG_OFFSET
	if button == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT) and _cursor == null:
		_quick_move(inv, i)
		return
	var slot := inv.get_stack(i)
	if button == MOUSE_BUTTON_LEFT:
		if _cursor == null:
			_cursor = slot
			inv.slots[i] = null
		elif slot == null:
			inv.slots[i] = _cursor
			_cursor = null
		elif slot.item.id == _cursor.item.id and slot.item.is_stackable():
			var moved := mini(slot.item.stack_max - slot.count, _cursor.count)
			slot.count += moved
			_cursor.count -= moved
			if _cursor.count <= 0:
				_cursor = null
		else:
			inv.slots[i] = _cursor
			_cursor = slot
	elif button == MOUSE_BUTTON_RIGHT:
		if _cursor == null and slot != null and slot.count > 1:
			var half := slot.count / 2
			_cursor = ItemStack.new(slot.item, half)
			slot.count -= half
		elif _cursor == null and slot != null:
			_cursor = slot
			inv.slots[i] = null
		elif _cursor != null and slot == null:
			inv.slots[i] = ItemStack.new(_cursor.item, 1)
			inv.slots[i].durability = _cursor.durability
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
		elif _cursor != null and slot != null and slot.item.id == _cursor.item.id and slot.item.is_stackable() and slot.count < slot.item.stack_max:
			slot.count += 1
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
	inv.changed.emit()


## Shift + clique: leva a pilha inteira para a outra bolsa (inventário <-> alforje).
func _quick_move(from: Inventory, i: int) -> void:
	if _pet == null or not is_instance_valid(_pet):
		return
	var st := from.get_stack(i)
	if st == null:
		return
	var to := _pet.bag if from == inventory else inventory
	if st.item.is_stackable():
		var left := to.add(st.item, st.count)
		st.count = left
		if left <= 0:
			from.slots[i] = null
	else:
		for j in to.size():
			if to.slots[j] == null:
				to.slots[j] = st
				from.slots[i] = null
				break
	from.changed.emit()
	to.changed.emit()
