class_name SpellBar
extends HBoxContainer
## Barra de magias acima da hotbar: as magias que o jogador já tem desde o início, com a tecla de
## cada uma (Z, X, V, T), o custo de mana e a recarga. A destacada é a que o botão direito lança.

var player: Player
var _slots: Array[Control] = []


func setup(p: Player) -> void:
	player = p
	add_theme_constant_override("separation", 6)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_top = -128
	offset_bottom = -76
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()
	EventBus.spell_selected.connect(func(_s: MagicData) -> void: _redraw())
	EventBus.spell_learned.connect(func(_s: MagicData) -> void: rebuild())
	EventBus.mana_changed.connect(func(_c: float, _m: float) -> void: _redraw())
	EventBus.build_mode_changed.connect(func(on: bool) -> void: visible = not on)
	EventBus.keybinds_changed.connect(_redraw)
	Config.reloaded.connect(rebuild)


func rebuild() -> void:
	for c in _slots:
		c.queue_free()
	_slots.clear()
	for id: StringName in player.magic.learned:
		var spell := Database.spell(id)
		if spell == null:
			continue
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(150, 50)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_meta(&"spell", id)
		slot.draw.connect(_draw_slot.bind(slot))
		add_child(slot)
		_slots.append(slot)
	_center.call_deferred()


## Centraliza acima da hotbar (a largura depende de quantas magias existem).
func _center() -> void:
	var w := get_combined_minimum_size().x
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = -128
	offset_bottom = -76


func _process(_delta: float) -> void:
	# Só redesenha enquanto alguma magia está recarregando.
	for id: StringName in player.magic.learned:
		if player.magic.cooldown_left(id) > 0.0:
			_redraw()
			return


func _redraw() -> void:
	for s in _slots:
		s.queue_redraw()


func _draw_slot(slot: Control) -> void:
	var id: StringName = slot.get_meta(&"spell")
	var spell := Database.spell(id)
	if spell == null:
		return
	var r := Rect2(Vector2.ZERO, slot.size)
	var selected := id == player.magic.selected
	var can_pay := player.magic.mana >= spell.mana_cost
	slot.draw_rect(r, Color(0.08, 0.09, 0.12, 0.8))
	slot.draw_rect(r, Color(1, 0.85, 0.3) if selected else Color(0.4, 0.45, 0.55), false, 3.0 if selected else 1.5)
	var col := spell.color if can_pay else spell.color.darkened(0.6)
	slot.draw_circle(Vector2(20, 25), 13.0, col)
	slot.draw_arc(Vector2(20, 25), 13.0, 0.0, TAU, 20, Color(0, 0, 0, 0.6), 1.5)
	var font := ThemeDB.fallback_font
	slot.draw_string(font, Vector2(4, 13), _key_for(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
	var name_col := Color.WHITE if can_pay else Color(1, 1, 1, 0.45)
	slot.draw_string(font, Vector2(38, 22), spell.display_name, HORIZONTAL_ALIGNMENT_LEFT, slot.size.x - 40, 12, name_col)
	slot.draw_string(font, Vector2(38, 40), "%d mana" % int(spell.mana_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.75, 1.0) if can_pay else Color(1, 0.4, 0.35))
	var cd := player.magic.cooldown_left(id)
	if cd > 0.0 and spell.cooldown > 0.0:
		var frac := cd / spell.cooldown
		slot.draw_rect(Rect2(Vector2(0, slot.size.y * (1.0 - frac)), Vector2(slot.size.x, slot.size.y * frac)), Color(0, 0, 0, 0.5))


## Tecla atual que escolhe a magia (pode ter sido trocada no menu).
func _key_for(id: StringName) -> String:
	for action: StringName in PlayerMagic.SELECT_ACTIONS:
		if PlayerMagic.SELECT_ACTIONS[action] == id:
			return Keybinds.key_name(action)
	return ""
