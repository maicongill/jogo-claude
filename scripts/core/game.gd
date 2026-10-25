extends Node
## Estado global do jogo: opções, seed do mundo e controle de captura do mouse.

## Seed global: a mesma seed gera o mesmo mundo.
var world_seed: int = 12345
var mouse_sensitivity: float = 0.003

var _ui_open_count := 0


func is_ui_open() -> bool:
	return _ui_open_count > 0


## Chamado por qualquer painel que precise do cursor (inventário, menu...).
func push_ui() -> void:
	_ui_open_count += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func pop_ui() -> void:
	_ui_open_count = maxi(_ui_open_count - 1, 0)
	if _ui_open_count == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
