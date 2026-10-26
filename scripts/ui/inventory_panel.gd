class_name InventoryPanel
extends PanelContainer
## Inventário em grade (9 colunas). Clique esquerdo pega/solta a pilha, direito pega metade / solta um.

var player: Player
var inventory: Inventory

var _slots: Array[SlotUI] = []
var _cursor: ItemStack
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
		refresh()


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
	_cursor_ui.set_stack(_cursor)
	_cursor_ui.visible = visible and _cursor != null


func _on_slot_pressed(i: int, button: int) -> void:
	var slot := inventory.get_stack(i)
	if button == MOUSE_BUTTON_LEFT:
		if _cursor == null:
			_cursor = slot
			inventory.slots[i] = null
		elif slot == null:
			inventory.slots[i] = _cursor
			_cursor = null
		elif slot.item.id == _cursor.item.id and slot.item.is_stackable():
			var moved := mini(slot.item.stack_max - slot.count, _cursor.count)
			slot.count += moved
			_cursor.count -= moved
			if _cursor.count <= 0:
				_cursor = null
		else:
			inventory.slots[i] = _cursor
			_cursor = slot
	elif button == MOUSE_BUTTON_RIGHT:
		if _cursor == null and slot != null and slot.count > 1:
			var half := slot.count / 2
			_cursor = ItemStack.new(slot.item, half)
			slot.count -= half
		elif _cursor == null and slot != null:
			_cursor = slot
			inventory.slots[i] = null
		elif _cursor != null and slot == null:
			inventory.slots[i] = ItemStack.new(_cursor.item, 1)
			inventory.slots[i].durability = _cursor.durability
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
		elif _cursor != null and slot != null and slot.item.id == _cursor.item.id and slot.item.is_stackable() and slot.count < slot.item.stack_max:
			slot.count += 1
			_cursor.count -= 1
			if _cursor.count <= 0:
				_cursor = null
	inventory.changed.emit()
