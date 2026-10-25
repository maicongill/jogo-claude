class_name OptionsMenu
extends PanelContainer
## Menu de opções (Esc). Fome e durabilidade não podem ser desligadas, só a perda de itens.

var _box: VBoxContainer


func setup() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_box.custom_minimum_size.x = 340
	margin.add_child(_box)

	var title := Label.new()
	title.text = "Opções"
	title.add_theme_font_size_override("font_size", 22)
	_box.add_child(title)

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
		visible = false
		Game.pop_ui()
	elif not Game.is_ui_open():
		visible = true
		Game.push_ui()
