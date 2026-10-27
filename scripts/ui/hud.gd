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
var _spell_label: Label
var goals: GoalTracker
var _goals_box: VBoxContainer
var _hint_label: Label
var _hint_tween: Tween


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

	# Objetivos (canto superior direito) e dica atual (centro, no topo).
	_goals_box = VBoxContainer.new()
	_goals_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_goals_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_goals_box.offset_left = -330
	_goals_box.offset_right = -16
	_goals_box.offset_top = 16
	_goals_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_goals_box)
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.offset_top = 14
	_hint_label.custom_minimum_size.x = 520
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 17)
	_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.modulate.a = 0.0
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_label)
	EventBus.hint_requested.connect(show_hint)
	EventBus.goal_completed.connect(func(_id: StringName) -> void: refresh_goals())

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

	var spellbook := SpellbookPanel.new()
	spellbook.setup(player)
	root.add_child(spellbook)
	var table_panel := MagicTablePanel.new()
	table_panel.setup(player)
	root.add_child(table_panel)

	options = OptionsMenu.new()
	options.setup()
	root.add_child(options)

	var health_bar := add_bar("Vida", Color(0.85, 0.2, 0.25))
	var hunger_bar := add_bar("Fome", Color(0.95, 0.65, 0.2))
	var mana_bar := add_bar("Mana", Color(0.25, 0.5, 0.95))
	var stamina_bar := add_bar("Estamina", Color(0.4, 0.85, 0.4))
	stamina_bar.get_parent().visible = false
	EventBus.pet_stamina_changed.connect(func(c: float, m: float) -> void:
		stamina_bar.max_value = m
		stamina_bar.value = c)
	var ride_hint := Label.new()
	ride_hint.text = "Voando: Espaço sobe · C desce (rápido = mergulho) · Espaço após mergulho = subida em arco\nQ planar · Shift acelera · Tab abre o alforje · F ou E desmonta"
	ride_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	ride_hint.add_theme_constant_override("outline_size", 4)
	ride_hint.visible = false
	_bars_box.add_child(ride_hint)
	EventBus.pet_mounted.connect(func(_pet: Node3D, on: bool) -> void:
		stamina_bar.get_parent().visible = on
		ride_hint.visible = on)
	_spell_label = Label.new()
	_spell_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_spell_label.add_theme_constant_override("outline_size", 4)
	_bars_box.add_child(_spell_label)
	EventBus.mana_changed.connect(func(c: float, m: float) -> void:
		mana_bar.max_value = m
		mana_bar.value = c)
	var update_spell := func(_s: Variant = null) -> void:
		var spell := player.magic.current()
		_spell_label.text = "Magia: %s  (botão direito)" % spell.display_name if spell != null else "Magia: nenhuma  (V)"
	EventBus.spell_selected.connect(update_spell)
	EventBus.spell_learned.connect(update_spell)
	update_spell.call()
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


func set_goals(tracker: GoalTracker) -> void:
	goals = tracker
	refresh_goals()


func refresh_goals() -> void:
	if goals == null:
		return
	for c in _goals_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Objetivos"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	_goals_box.add_child(title)
	for g in GoalTracker.GOALS:
		var l := Label.new()
		var ok := goals.is_done(g["id"])
		l.text = "%s %s" % ["[x]" if ok else "[  ]", g["text"]]
		l.modulate = Color(0.6, 1.0, 0.6) if ok else Color.WHITE
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		_goals_box.add_child(l)


## Dica grande no topo da tela; some sozinha.
func show_hint(text: String) -> void:
	_hint_label.text = text
	if _hint_tween != null:
		_hint_tween.kill()
	_hint_label.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(9.0)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 1.0)


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
