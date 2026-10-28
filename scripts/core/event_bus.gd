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

# Pet
signal pet_mounted(pet: Node3D, mounted: bool)
signal pet_stamina_changed(current: float, maximum: float)

# Progresso e jogo
signal item_crafted(item: ItemData)
signal piece_placed(piece: Node3D)
signal pet_level_changed(pet: Node3D, level: int)
## Manobra de voo feita montado: &"dive" (mergulho) ou &"glide" (planar).
signal pet_maneuver(name: StringName)
signal goal_completed(goal_id: StringName)
signal save_requested
signal load_requested
## Alguma tecla foi trocada no menu (para atualizar as dicas na tela).
signal keybinds_changed
## Mudou entre sobrevivência (false) e criativo (true).
signal game_mode_changed(creative: bool)


## Remove as ligações que sobraram do mundo anterior. Funções anônimas (lambdas) ligadas aos sinais
## dos autoloads não se desligam sozinhas quando o nó que as criou morre (se a lambda não usa `self`,
## o Godot a registra no script, não no nó); ao trocar de mundo ou voltar ao menu elas seriam chamadas
## com tudo já apagado. Chamado no começo de cada mundo e do menu, quando nenhum nó de cena existe
## ainda: sai tudo que não é dos próprios autoloads.
func purge_dead_connections() -> int:
	var autoload_scripts := {}
	for a in [Config, Visuals, self, Game, WorldState, Database]:
		if a.get_script() != null:
			autoload_scripts[a.get_script().resource_path] = true
	var removed := 0
	for source: Object in [self, Config]:
		for sig in source.get_signal_list():
			for c in source.get_signal_connection_list(sig["name"]):
				var callable: Callable = c["callable"]
				var obj := callable.get_object()
				var dead := obj == null or not is_instance_valid(obj)
				if not dead and obj is Script:
					dead = not autoload_scripts.has((obj as Script).resource_path)  # lambda de um script de cena
				elif not dead and obj is Node:
					dead = (obj as Node).is_queued_for_deletion() or not (obj as Node).is_inside_tree() and not obj in [Config, Visuals, self, Game, WorldState, Database]
				if dead:
					source.disconnect(sig["name"], callable)
					removed += 1
	return removed
