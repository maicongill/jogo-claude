class_name OptionsMenu
extends PanelContainer
## Menu de opções (Esc), em abas: "Geral" (perda de itens, mouse, contorno, distância, salvar) e
## "Teclas" (trocar a tecla de cada ação). Fome e durabilidade não podem ser desligadas.

var _box: VBoxContainer
var _tabs: TabContainer
var _key_buttons: Dictionary = {}  # ação -> Button
var _capturing: StringName = &""   # ação esperando a tecla nova
var _keys_info: Label


func setup() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)
	var title := Label.new()
	title.text = "Opções"
	title.add_theme_font_size_override("font_size", 22)
	outer.add_child(title)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(440, 400)
	outer.add_child(_tabs)
	_box = VBoxContainer.new()
	_box.name = "Geral"
	_box.add_theme_constant_override("separation", 10)
	_tabs.add_child(_box)
	_build_keys_tab()

	var lose := CheckBox.new()
	lose.text = "Perder itens ao morrer"
	lose.button_pressed = Game.lose_items_on_death
	lose.toggled.connect(func(on: bool) -> void: Game.lose_items_on_death = on)
	_box.add_child(lose)

	var sens_label := Label.new()
	sens_label.text = "Sensibilidade do mouse"
	_box.add_child(sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.001
	sens.max_value = 0.008
	sens.step = 0.0005
	sens.value = Game.mouse_sensitivity
	sens.value_changed.connect(func(v: float) -> void: Game.mouse_sensitivity = v)
	_box.add_child(sens)

	var outline := CheckBox.new()
	outline.text = "Contorno (outline)"
	outline.button_pressed = Visuals.outline_enabled
	outline.toggled.connect(func(on: bool) -> void: Visuals.outline_enabled = on)
	_box.add_child(outline)

	var thick_label := Label.new()
	thick_label.text = "Espessura do contorno"
	_box.add_child(thick_label)
	var thick := HSlider.new()
	thick.min_value = 0.004
	thick.max_value = 0.08
	thick.step = 0.002
	thick.value = Visuals.outline_thickness
	thick.value_changed.connect(func(v: float) -> void: Visuals.outline_thickness = v)
	_box.add_child(thick)

	var radius_label := Label.new()
	radius_label.text = "Distância de visão (chunks): %d" % Game.load_radius
	_box.add_child(radius_label)
	var radius := HSlider.new()
	radius.min_value = 3
	radius.max_value = 8
	radius.step = 1
	radius.value = Game.load_radius
	radius.value_changed.connect(func(v: float) -> void:
		Game.load_radius = int(v)
		radius_label.text = "Distância de visão (chunks): %d" % int(v))
	_box.add_child(radius)

	var save_row := HBoxContainer.new()
	var save := Button.new()
	save.text = "Salvar (F5)"
	save.pressed.connect(func() -> void: EventBus.save_requested.emit())
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save)
	var load_btn := Button.new()
	load_btn.text = "Carregar (F9)"
	load_btn.pressed.connect(func() -> void: EventBus.load_requested.emit())
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(load_btn)
	_box.add_child(save_row)

	var close := Button.new()
	close.text = "Continuar"
	close.pressed.connect(toggle)
	_box.add_child(close)

	var quit := Button.new()
	quit.text = "Sair do jogo"
	quit.pressed.connect(func() -> void: get_tree().quit())
	_box.add_child(quit)


## Aba "Teclas": uma linha por ação, com o botão mostrando a tecla atual. Clique e aperte a nova.
func _build_keys_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Teclas"
	tab.add_theme_constant_override("separation", 6)
	_tabs.add_child(tab)
	_keys_info = Label.new()
	_keys_info.text = "Clique numa ação e aperte a tecla (ou botão do mouse) nova. Esc cancela."
	_keys_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys_info.custom_minimum_size.x = 400
	tab.add_child(_keys_info)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for a in Keybinds.ACTIONS:
		var action: StringName = a[0]
		if not InputMap.has_action(action):
			continue
		var l := Label.new()
		l.text = a[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size.x = 150
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_start_capture.bind(action))
		grid.add_child(b)
		_key_buttons[action] = b
	var reset := Button.new()
	reset.text = "Restaurar teclas padrão"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		Keybinds.reset()
		_keys_info.text = "Teclas restauradas para o padrão.")
	tab.add_child(reset)
	EventBus.keybinds_changed.connect(_refresh_keys)
	_refresh_keys()


func _refresh_keys() -> void:
	for action: StringName in _key_buttons:
		_key_buttons[action].text = Keybinds.key_name(action)


func _start_capture(action: StringName) -> void:
	_capturing = action
	_key_buttons[action].text = "Aperte a tecla..."
	_keys_info.text = "Aperte a nova tecla (ou botão do mouse). Esc cancela."


## Enquanto espera a tecla nova, pega o evento antes de qualquer outra coisa (inclusive o Esc).
func _input(event: InputEvent) -> void:
	if _capturing == &"" or not visible:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var action := _capturing
	_capturing = &""
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_keys_info.text = "Troca cancelada."
		_refresh_keys()
		return
	var ev := Keybinds.clean(event)
	var swapped := Keybinds.rebind(action, ev)
	var action_name := ""
	for a in Keybinds.ACTIONS:
		if a[0] == action:
			action_name = a[1]
	_keys_info.text = "%s: %s." % [action_name, Keybinds.event_name(ev)]
	if swapped != "":
		_keys_info.text += " A tecla antiga foi para \"%s\"." % swapped
	_refresh_keys()


## Permite que outros marcos adicionem controles (raio de carregamento, salvar...).
func add_control(node: Control, index := -1) -> void:
	_box.add_child(node)
	if index >= 0:
		_box.move_child(node, index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		_capturing = &""
		_refresh_keys()
		visible = false
		Game.pop_ui()
	elif not Game.is_ui_open():
		visible = true
		Game.push_ui()
