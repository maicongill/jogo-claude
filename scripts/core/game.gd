extends Node
## Estado global do jogo: opções, seed do mundo e controle de captura do mouse.

## Seed global: a mesma seed gera o mesmo mundo.
var world_seed: int = 12345
var mouse_sensitivity: float = 0.003

## Verdadeiro enquanto o modo de construção está ativo (a roda do mouse troca a peça, não a hotbar).
var build_mode := false

## Opção do jogador: perder os itens ao morrer (fome e durabilidade não têm opção).
var lose_items_on_death := true
## Ponto de renascimento (cama). Vector3.INF = ainda não há cama.
var spawn_point := Vector3.INF
## Ponto inicial do mundo, definido pela cena principal.
var default_spawn := Vector3(0, 3, 0)
## Posições dos estábulos construídos (onde o pet renasce).
var stables: Array[Vector3] = []
## Começa com ferramentas no inventário (útil para testar). Desligado quando o crafting existir.
var debug_starter_kit := false

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
