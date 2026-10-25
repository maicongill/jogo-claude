class_name HUD
extends CanvasLayer
## Interface do jogo: mira, hotbar, mensagens e painéis. Montada por código.

var player: Player

var _hotbar_slots: Array[SlotUI] = []
var _messages: VBoxContainer
var _crosshair: Control
var _bars_box: VBoxContainer
var _inventory_panel: InventoryPanel
var options: OptionsMenu
var _death_overlay: ColorRect


func setup(p: Player) -> void:
	player = p
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		_crosshair.draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.85))
		_crosshair.draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5), 1.5))
	root.add_child(_crosshair)

	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation", 4)
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar.offset_top = -70
	hotbar.offset_bottom = -12
	root.add_child(hotbar)
	for i in Inventory.HOTBAR_SIZE:
		var slot := SlotUI.new()
		slot.index = i
		slot.show_key = str(i + 1)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar.add_child(slot)
		_hotbar_slots.append(slot)

	_messages = VBoxContainer.new()
	_messages.position = Vector2(16, 120)
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_messages)

	_bars_box = VBoxContainer.new()
	_bars_box.position = Vector2(16, 16)
	_bars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bars_box)

	_inventory_panel = InventoryPanel.new()
	_inventory_panel.setup(player)
	root.add_child(_inventory_panel)
	var crafting := CraftingPanel.new()
	crafting.setup(player.inventory)
	_inventory_panel.add_side_panel(crafting)

	options = OptionsMenu.new()
	options.setup()
	root.add_child(options)

	var health_bar := add_bar("Vida", Color(0.85, 0.2, 0.25))
	var hunger_bar := add_bar("Fome", Color(0.95, 0.65, 0.2))
	EventBus.player_health_changed.connect(func(c: float, m: float) -> void:
		health_bar.max_value = m
		health_bar.value = c)
	EventBus.player_hunger_changed.connect(func(c: float, m: float) -> void:
		hunger_bar.max_value = m
		hunger_bar.value = c)

	_death_overlay = ColorRect.new()
	_death_overlay.color = Color(0.4, 0, 0, 0.45)
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.visible = false
	var death_label := Label.new()
	death_label.text = "Você morreu"
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_overlay.add_child(death_label)
	root.add_child(_death_overlay)
	var hurt_flash := ColorRect.new()
	hurt_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_flash)
	EventBus.player_hurt.connect(func(_a: float) -> void:
		hurt_flash.color.a = 0.35
		create_tween().tween_property(hurt_flash, "color:a", 0.0, 0.4))
	EventBus.player_died.connect(func() -> void: _death_overlay.visible = true)
	EventBus.player_respawned.connect(func() -> void: _death_overlay.visible = false)

	player.inventory.changed.connect(_refresh_hotbar)
	player.inventory.item_broken.connect(func(item: ItemData) -> void: show_message("%s quebrou!" % item.display_name))
	EventBus.hotbar_selected.connect(func(_i: int) -> void: _refresh_hotbar())
	EventBus.message.connect(show_message)
	EventBus.item_collected.connect(func(item: ItemData, count: int) -> void: show_message("+%d %s" % [count, item.display_name]))
	_refresh_hotbar()


## Barras (vida, fome, mana...) entram por aqui nos próximos marcos.
func add_bar(label: String, color: Color) -> ProgressBar:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 64
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	box.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 16)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	_bars_box.add_child(box)
	return bar


func show_message(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_font_size_override("font_size", 18)
	_messages.add_child(l)
	if _messages.get_child_count() > 6:
		_messages.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func _refresh_hotbar() -> void:
	for i in _hotbar_slots.size():
		_hotbar_slots[i].set_stack(player.inventory.get_stack(i))
		_hotbar_slots[i].selected = i == player.selected_slot
		_hotbar_slots[i].queue_redraw()
