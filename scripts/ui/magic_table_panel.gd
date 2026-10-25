class_name MagicTablePanel
extends PanelContainer
## Mesa de magia: combina itens (receitas fixas em Resources) para criar pergaminhos.

var player: Player
var _list: VBoxContainer


func setup(p: Player) -> void:
	player = p
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 400
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Mesa de magia  (Esc para fechar)"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	player.inventory.changed.connect(refresh)
	EventBus.magic_table_opened.connect(func(_t: Node3D) -> void: open())
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for r in Database.scroll_recipes:
		var needs: PackedStringArray = []
		for i in r.inputs.size():
			needs.append("%d %s (%d)" % [r.input_counts[i], r.inputs[i].display_name, player.inventory.count_of(r.inputs[i])])
		var b := Button.new()
		b.text = "%s\n  %s" % [r.scroll.display_name, ", ".join(needs)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 50
		b.disabled = not player.inventory.has_items(r.inputs, r.input_counts)
		b.pressed.connect(func() -> void:
			if Placeables.MagicTable.craft_scroll(player.inventory, r):
				EventBus.message.emit("Criou %s." % r.scroll.display_name)
			else:
				EventBus.message.emit("Faltam materiais ou espaço no inventário."))
		_list.add_child(b)


func open() -> void:
	if visible or Game.is_ui_open():
		return
	visible = true
	Game.push_ui()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		visible = false
		Game.pop_ui()
		get_viewport().set_input_as_handled()
