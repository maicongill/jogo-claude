extends Node3D
## Cena principal: monta o terreno por chunks e coloca o jogador.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var player: Player
var chunks: ChunkManager
var hud: HUD
var build: BuildSystem
var spawner: EnemySpawner
var pet_spawner: PetSpawner
var _starter_pet_done := false
## Mundo distante (imagens e manchas além dos chunks de perto).
var far_world: FarWorld
var goals: GoalTracker


func _ready() -> void:
	EventBus.purge_dead_connections()  # ligações do mundo anterior (lambdas) não podem sobrar
	chunks = ChunkManager.new()
	chunks.name = "Terrain"
	add_child(chunks)
	chunks.setup(Game.world_seed, Database.resource_nodes)
	far_world = FarWorld.new()
	add_child(far_world)

	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.frozen = true  # só começa a cair/andar quando o chão sob ele existir
	player.global_position = Vector3(0, chunks.height_at(0, 0) + 1.0, 0)
	chunks.target = player
	far_world.setup(chunks, player)
	Game.default_spawn = player.global_position + Vector3(0, 0.5, 0)

	spawner = EnemySpawner.new()
	spawner.name = "EnemySpawner"
	add_child(spawner)
	spawner.setup(chunks, self)

	pet_spawner = PetSpawner.new()
	pet_spawner.name = "PetSpawner"
	add_child(pet_spawner)
	pet_spawner.setup(chunks, self)

	build = BuildSystem.new()
	build.name = "BuildSystem"
	add_child(build)
	build.setup(player, self, chunks.height_at)

	goals = GoalTracker.new()
	goals.name = "Goals"
	add_child(goals)
	goals.setup(player)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player)
	hud.set_goals(goals)
	EventBus.save_requested.connect(save_game)
	EventBus.load_requested.connect(load_game)


func save_game() -> bool:
	var ok := SaveSystem.save_to(self, Game.save_path())
	EventBus.message.emit("Jogo salvo." if ok else "Não foi possível salvar.")
	return ok


func load_game() -> void:
	if SaveSystem.load_from(self, Game.save_path()):
		EventBus.message.emit("Jogo carregado.")
	else:
		EventBus.message.emit("Nenhum jogo salvo encontrado.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		save_game()
	elif event.is_action_pressed(&"quick_load"):
		load_game()
	elif event.is_action_pressed(&"reload_config"):
		Config.reload()


func _physics_process(_delta: float) -> void:
	if player.frozen and not player.stats.dead and player.mounted_pet == null:
		# Espera o chão sob o jogador (e em volta) existir antes de soltá-lo.
		var c := chunks.world_to_chunk(player.global_position)
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if not chunks.is_loaded(c + Vector2i(dx, dz)):
					return
		player.frozen = false
		if Game.loading_world:
			# Entrou num mundo que já existe: volta tudo como estava no último save.
			Game.loading_world = false
			_starter_pet_done = true
			if SaveSystem.load_from(self, Game.save_path()):
				return  # o save prende o jogador de novo até o chão de onde ele estava carregar
		EventBus.world_ready.emit()
		_spawn_starter_pet()
		return
	if player.frozen:
		return
	# Rede de segurança: se por algum motivo o jogador atravessar o chão, devolve para cima.
	var ground := chunks.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground - 6.0:
		player.global_position.y = ground + 2.0
		player.velocity = Vector3.ZERO


## Opção game.start_with_tamed_pet: um Aerolho domado e selado ao lado do jogador, só no início
## de um jogo novo (não em testes nem depois de carregar um save, que já traz os próprios pets).
func _spawn_starter_pet() -> void:
	if _starter_pet_done or not Game.start_with_tamed_pet:
		return
	_starter_pet_done = true
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.begins_with("res://tests/"):
		return
	for p: FlyingPet in get_tree().get_nodes_in_group(&"pet"):
		if p.trust > 0.0:
			return
	var data: PetData = Database.pets.values()[0]
	var pos := player.global_position + Vector3(3.0, 0, -2.0)
	pos.y = chunks.height_at(pos.x, pos.z)
	var pet := pet_spawner.create_pet(data, pos)
	pet._player = player
	pet.trust = float(data.trust_thresholds[data.trust_thresholds.size() - 1])
	pet.level = data.trust_thresholds.size()
	pet.knows_food = true
	pet.knows_biome = true
	pet.saddled = true
	pet.state = FlyingPet.State.FOLLOW
	pet._update_label()
	EventBus.pet_level_changed.emit(pet, pet.level)  # conta como domado (objetivo da meta)
	EventBus.message.emit("%s já confia em você e está selado. Aperte F perto dele para montar." % data.display_name)

