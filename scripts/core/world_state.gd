extends Node
## Estado dinâmico do mundo (o que o jogador modificou), guardado fora dos chunks
## para sobreviver ao carregar/descartar chunks.

## Relógio do mundo em segundos de jogo.
var time: float = 0.0

## Recursos modificados: "cx,cz,tipo" -> { índice: [vida, momento_em_que_esgotou] }.
## momento = -1 enquanto vivo; -2 = esgotado para sempre.
var resource_states: Dictionary = {}


func _process(delta: float) -> void:
	time += delta


func resource_state(key: String) -> Dictionary:
	if not resource_states.has(key):
		resource_states[key] = {}
	return resource_states[key]

## Inimigos já derrotados: "cx,cz" -> true.
var killed_enemies: Dictionary = {}

## Chunks cujo pet selvagem já foi adotado: "cx,cz" -> true.
var owned_pets: Dictionary = {}
