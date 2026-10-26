class_name SpellbookPanel
extends PanelContainer
## Livro de magia (V): escolhe a magia ativa entre as aprendidas. O botão direito lança.

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
	box.custom_minimum_size.x = 360
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Livro de magia  (V para fechar)"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	var hint := Label.new()
	hint.text = "Botão direito do mouse lança a magia escolhida."
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)
	EventBus.spell_learned.connect(func(_s: MagicData) -> void: refresh())
	EventBus.spell_selected.connect(func(_s: MagicData) -> void: refresh())
	refresh()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if player.magic.learned.is_empty():
		var l := Label.new()
		l.text = "Você ainda não aprendeu nenhuma magia.\nCrie pergaminhos na mesa de magia e use-os."
		_list.add_child(l)
		return
	for id in player.magic.learned:
		var spell := Database.spell(id)
		var b := Button.new()
		b.text = "%s%s   (%d mana)\n  %s" % ["► " if id == player.magic.selected else "   ", spell.display_name, int(spell.mana_cost), spell.description]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 52
		b.pressed.connect(func() -> void: player.magic.select(id))
		_list.add_child(b)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"spellbook"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		visible = false
		Game.pop_ui()
	elif not Game.is_ui_open():
		visible = true
		Game.push_ui()
		refresh()
