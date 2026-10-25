extends Node
## Estado dinâmico do mundo (o que o jogador modificou), guardado fora dos chunks
## para sobreviver ao carregar/descartar chunks.

## Relógio do mundo em segundos de jogo.
var time: float = 0.0


func _process(delta: float) -> void:
	time += delta
