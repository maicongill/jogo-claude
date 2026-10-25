extends Node
## Eventos globais. Sistemas se comunicam por aqui em vez de se referenciarem diretamente.

# Jogador
signal player_spawned(player: Node3D)
signal player_health_changed(current: float, maximum: float)
signal player_died
signal player_respawned

# Mundo
signal world_ready
signal hint_requested(text: String)
