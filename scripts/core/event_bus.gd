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

# Construção
signal piece_destroyed(piece: Node3D)
signal build_mode_changed(active: bool)

# Combate
signal player_hurt(amount: float)
signal enemy_killed(enemy: Node3D)

# Magia
signal mana_changed(current: float, maximum: float)
signal spell_selected(spell: MagicData)
signal spell_learned(spell: MagicData)
signal spell_cast(spell: MagicData)
signal magic_table_opened(table: Node3D)

# Pet
signal pet_mounted(pet: Node3D, mounted: bool)
signal pet_stamina_changed(current: float, maximum: float)

# Progresso e jogo
signal item_crafted(item: ItemData)
signal piece_placed(piece: Node3D)
signal pet_level_changed(pet: Node3D, level: int)
signal goal_completed(goal_id: StringName)
signal save_requested
signal load_requested
