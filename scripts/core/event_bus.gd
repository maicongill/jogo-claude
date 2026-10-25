extends Node
## Eventos globais. Sistemas se comunicam por aqui em vez de se referenciarem diretamente.

# Jogador
signal player_spawned(player: Node3D)
signal player_health_changed(current: float, maximum: float)
signal player_hunger_changed(current: float, maximum: float)
signal player_died
signal player_respawned

# Mundo
signal world_ready
signal hint_requested(text: String)

# Mensagens e itens
signal message(text: String)
signal item_collected(item: ItemData, count: int)
signal hotbar_selected(slot: int)
