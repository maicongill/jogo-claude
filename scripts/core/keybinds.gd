class_name Keybinds
extends RefCounted
## Teclas das ações do jogo, trocáveis no menu (Esc > Teclas). A troca vale na hora e fica salva em
## user://keybinds.json (os padrões continuam no project.godot). Cada ação usa uma tecla ou um botão
## do mouse; se a tecla nova já era de outra ação, as duas trocam entre si.

## Arquivo das teclas salvas (nos testes é outro, para nunca mexer nas teclas do jogador).
static var path := "user://keybinds.json"

## Ações que aparecem no menu, na ordem, com o nome mostrado ao jogador.
const ACTIONS := [
	[&"move_forward", "Andar para frente"],
	[&"move_back", "Andar para trás"],
	[&"move_left", "Andar para a esquerda"],
	[&"move_right", "Andar para a direita"],
	[&"jump", "Pular / subir (voando)"],
	[&"sprint", "Correr / voo rápido"],
	[&"crouch", "Agachar / descer (voando)"],
	[&"dodge", "Esquivar / planar (voando)"],
	[&"interact", "Interagir / coletar"],
	[&"attack", "Atacar"],
	[&"secondary", "Lançar magia"],
	[&"spell_fire", "Magia: bola de fogo"],
	[&"spell_wind", "Magia: rajada de vento"],
	[&"spell_earth", "Magia: muralha de terra"],
	[&"spell_tame", "Magia: doma"],
	[&"mount", "Montar / desmontar"],
	[&"inventory", "Inventário"],
	[&"build_mode", "Modo construção"],
	[&"build_rotate", "Girar peça"],
	[&"build_grid", "Grade de construção"],
	[&"quick_save", "Salvar o jogo"],
	[&"quick_load", "Carregar o jogo"],
	[&"reload_config", "Recarregar configuração"],
]

static var _defaults: Dictionary = {}  # ação -> eventos do project.godot


## Guarda os padrões e aplica as teclas salvas (chamado uma vez, ao iniciar o jogo).
static func init() -> void:
	_defaults.clear()
	for a in ACTIONS:
		if InputMap.has_action(a[0]):
			_defaults[a[0]] = InputMap.action_get_events(a[0]).duplicate()
	if _running_test():
		path = "user://keybinds_test.json"
		return  # os testes começam sempre com as teclas padrão
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	for action: String in data:
		var ev := _decode(data[action])
		if ev != null and InputMap.has_action(action):
			_set_event(StringName(action), ev)


static func _running_test() -> bool:
	for a in OS.get_cmdline_args():
		if String(a).begins_with("res://tests/"):
			return true
	return false


## Troca a tecla da ação. Se outra ação usava essa tecla, ela fica com a tecla antiga desta.
## Devolve o nome da ação que trocou (ou "" se nenhuma).
static func rebind(action: StringName, ev: InputEvent) -> String:
	var old := primary(action)
	var swapped := ""
	for a in ACTIONS:
		var other: StringName = a[0]
		if other == action:
			continue
		for e in InputMap.action_get_events(other):
			if _same(e, ev):
				InputMap.action_erase_event(other, e)
				if old != null and InputMap.action_get_events(other).is_empty():
					InputMap.action_add_event(other, old.duplicate())
				swapped = a[1]
	_set_event(action, ev)
	save()
	EventBus.keybinds_changed.emit()
	return swapped


## Volta todas as teclas ao padrão.
static func reset() -> void:
	for action: StringName in _defaults:
		InputMap.action_erase_events(action)
		for e in _defaults[action]:
			InputMap.action_add_event(action, e.duplicate())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	EventBus.keybinds_changed.emit()


## A tecla principal da ação (a primeira).
static func primary(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var evs := InputMap.action_get_events(action)
	return evs[0] if not evs.is_empty() else null


## Nome da tecla para mostrar na tela (ex.: "K", "Shift", "Botão esquerdo").
static func key_name(action: StringName) -> String:
	return event_name(primary(action))


static func event_name(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		# Mostra a letra do layout do teclado do jogador (sem tela, como nos testes, usa o código direto).
		var shown := code
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(code)
		var s := OS.get_keycode_string(shown)
		return {"Space": "Espaço", "Shift": "Shift", "Escape": "Esc", "Up": "Seta para cima", "Down": "Seta para baixo",
				"Left": "Seta esquerda", "Right": "Seta direita", "Ctrl": "Ctrl"}.get(s, s)
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Botão esquerdo", MOUSE_BUTTON_RIGHT: "Botão direito", MOUSE_BUTTON_MIDDLE: "Botão do meio",
				MOUSE_BUTTON_WHEEL_UP: "Roda para cima", MOUSE_BUTTON_WHEEL_DOWN: "Roda para baixo",
				MOUSE_BUTTON_XBUTTON1: "Botão lateral 1", MOUSE_BUTTON_XBUTTON2: "Botão lateral 2"}.get((ev as InputEventMouseButton).button_index, "Mouse")
	return "—"


static func save() -> void:
	var data := {}
	for a in ACTIONS:
		var ev := primary(a[0])
		var defaults: Array = _defaults.get(a[0], [])
		if ev != null and (defaults.is_empty() or not _same(defaults[0], ev) or InputMap.action_get_events(a[0]).size() != defaults.size()):
			data[String(a[0])] = _encode(ev)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


static func _set_event(action: StringName, ev: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var ca := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var cb := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return ca == cb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Só a tecla/botão "puro" (sem pressionado, sem modificadores), do jeito que o InputMap usa.
static func clean(ev: InputEvent) -> InputEvent:
	if ev is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = (ev as InputEventKey).physical_keycode
		if k.physical_keycode == KEY_NONE:
			k.keycode = (ev as InputEventKey).keycode
		return k
	if ev is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (ev as InputEventMouseButton).button_index
		return m
	return null


static func _encode(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {"key": int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode), "physical": k.physical_keycode != KEY_NONE}
	if ev is InputEventMouseButton:
		return {"mouse": int((ev as InputEventMouseButton).button_index)}
	return {}


static func _decode(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	if d.has("key"):
		var k := InputEventKey.new()
		if d.get("physical", true):
			k.physical_keycode = int(d["key"]) as Key
		else:
			k.keycode = int(d["key"]) as Key
		return k
	if d.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d["mouse"]) as MouseButton
		return m
	return null
