extends Control
## Menu inicial: lista os mundos do jogador (jogar / excluir) e cria mundos novos (nome e seed).
## Entrar num mundo existente carrega o último save dele; o jogo salva ao voltar ao menu, ao sair
## e ao fechar a janela.

var _list: VBoxContainer
var _name_edit: LineEdit
var _seed_edit: LineEdit
var _confirm: ConfirmationDialog
var _to_delete := ""
var _empty_label: Label


func _ready() -> void:
	EventBus.purge_dead_connections()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.36, 0.58, 0.86)
	add_child(bg)
	var ground := ColorRect.new()
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -180
	ground.color = Color(0.30, 0.62, 0.30)
	add_child(ground)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(620, 0)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Jogo Claude"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	col.add_child(title)

	var worlds_title := Label.new()
	worlds_title.text = "Seus mundos"
	worlds_title.add_theme_font_size_override("font_size", 20)
	col.add_child(worlds_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_empty_label = Label.new()
	_empty_label.text = "Nenhum mundo ainda. Crie um abaixo."
	_empty_label.modulate = Color(1, 1, 1, 0.7)

	col.add_child(HSeparator.new())
	var new_title := Label.new()
	new_title.text = "Novo mundo"
	new_title.add_theme_font_size_override("font_size", 20)
	col.add_child(new_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome do mundo"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "Seed (vazio = aleatória)"
	_seed_edit.custom_minimum_size.x = 200
	row.add_child(_seed_edit)
	var create := Button.new()
	create.text = "Criar e jogar"
	create.pressed.connect(_on_create)
	row.add_child(create)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_create())

	var quit := Button.new()
	quit.text = "Sair do jogo"
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Excluir mundo"
	_confirm.ok_button_text = "Excluir"
	_confirm.cancel_button_text = "Cancelar"
	_confirm.confirmed.connect(func() -> void:
		Worlds.delete(_to_delete)
		_to_delete = ""
		refresh())
	add_child(_confirm)
	refresh()


## Monta a lista de mundos (o jogado por último em cima).
func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		if c != _empty_label:
			c.queue_free()
	var worlds := Worlds.list()
	if worlds.is_empty():
		_list.add_child(_empty_label)
		return
	for w in worlds:
		_list.add_child(_world_row(w))


func _world_row(w: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "World_" + String(w["id"])
	row.add_theme_constant_override("separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = String(w["name"])
	name_label.add_theme_font_size_override("font_size", 18)
	info.add_child(name_label)
	var detail := Label.new()
	var when := Time.get_datetime_string_from_unix_time(int(w.get("played", 0)) + _tz_offset(), true)
	detail.text = "Seed %s · %s · %s" % [str(int(w["seed"])), "jogado em " + when.replace("T", " ").left(16) if w["has_save"] else "ainda sem progresso salvo", ""]
	detail.text = detail.text.trim_suffix(" · ")
	detail.modulate = Color(1, 1, 1, 0.7)
	info.add_child(detail)
	var play := Button.new()
	play.text = "Continuar" if w["has_save"] else "Jogar"
	play.custom_minimum_size.x = 110
	play.pressed.connect(func() -> void: Game.start_world(String(w["id"])))
	row.add_child(play)
	var del := Button.new()
	del.text = "Excluir"
	del.pressed.connect(func() -> void: ask_delete(String(w["id"]), String(w["name"])))
	row.add_child(del)
	return row


func ask_delete(id: String, world_name: String) -> void:
	_to_delete = id
	_confirm.dialog_text = "Excluir o mundo \"%s\"?\nTudo o que foi construído e salvo nele será apagado." % world_name
	_confirm.popup_centered()


func _on_create() -> void:
	var w := Worlds.create(_name_edit.text, _seed_edit.text)
	Game.start_world(String(w["id"]))


static func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
