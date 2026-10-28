extends Node
## Aba "Teclas" do menu do Esc: trocar a tecla de uma ação (ex.: bola de fogo para K), troca entre
## ações quando a tecla já era usada, Esc cancela, salva em arquivo e restaura o padrão.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func key(code: Key, down := true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	await get_tree().process_frame


func tap(code: Key) -> void:
	await key(code, true)
	await key(code, false)
	await get_tree().process_frame


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	Keybinds.reset()
	check(Keybinds.path != "user://keybinds.json", "nos testes as teclas salvas vão para outro arquivo")
	var menu: OptionsMenu = main.hud.options
	menu.toggle()
	await get_tree().process_frame
	check(menu.visible and menu._tabs.get_tab_count() == 2, "menu do Esc tem 2 abas")
	check(menu._tabs.get_tab_title(1) == "Teclas", "aba \"Teclas\"")
	check(menu._key_buttons.has(&"spell_fire") and menu._key_buttons[&"spell_fire"].text == "Z", "bola de fogo começa no Z")

	# Bola de fogo -> K
	menu._start_capture(&"spell_fire")
	await tap(KEY_K)
	check(Keybinds.key_name(&"spell_fire") == "K" and menu._key_buttons[&"spell_fire"].text == "K", "bola de fogo agora é K")
	check(menu.visible, "a tecla nova não fecha nem mexe no menu")
	menu.toggle()
	await get_tree().process_frame
	p.magic.select(&"wind_gust")
	await tap(KEY_K)
	check(p.magic.selected == &"fireball", "no jogo, K escolhe a bola de fogo")
	p.magic.select(&"wind_gust")
	await tap(KEY_Z)
	check(p.magic.selected == &"wind_gust", "Z não escolhe mais a bola de fogo")

	# Tecla já usada: troca entre as ações (vento X -> K; fogo fica com o X).
	menu.toggle()
	await get_tree().process_frame
	menu._start_capture(&"spell_wind")
	await tap(KEY_K)
	check(Keybinds.key_name(&"spell_wind") == "K" and Keybinds.key_name(&"spell_fire") == "X", "tecla repetida: as duas ações trocam (vento K, fogo X)")

	# Esc cancela sem fechar o menu.
	menu._start_capture(&"jump")
	await tap(KEY_ESCAPE)
	check(Keybinds.key_name(&"jump") == "Espaço" and menu.visible, "Esc cancela a troca e o menu continua aberto")

	# Botão do mouse também vale.
	menu._start_capture(&"interact")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	mb.pressed = true
	Input.parse_input_event(mb)
	await get_tree().process_frame
	check(Keybinds.key_name(&"interact") == "Botão do meio", "dá para usar botão do mouse")

	# Salva em arquivo.
	var f := FileAccess.open(Keybinds.path, FileAccess.READ)
	var saved: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	check(saved is Dictionary and saved.has("spell_fire") and saved.has("spell_wind"), "as teclas trocadas ficam salvas")

	# Restaurar padrão.
	Keybinds.reset()
	await get_tree().process_frame
	check(Keybinds.key_name(&"spell_fire") == "Z" and Keybinds.key_name(&"spell_wind") == "X" and Keybinds.key_name(&"interact") == "E", "restaurar volta tudo ao padrão")
	check(menu._key_buttons[&"spell_fire"].text == "Z", "o botão mostra a tecla restaurada")
	menu.toggle()
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
