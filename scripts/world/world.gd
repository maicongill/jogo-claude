extends Node3D
## Cena principal: monta o terreno por chunks e coloca o jogador.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var player: Player
var chunks: ChunkManager
var hud: HUD
var build: BuildSystem
var spawner: EnemySpawner
var pet_spawner: PetSpawner
var goals: GoalTracker


func _ready() -> void:
	chunks = ChunkManager.new()
	chunks.name = "Terrain"
	add_child(chunks)
	chunks.setup(Game.world_seed, Database.resource_nodes)

	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.frozen = true  # só começa a cair/andar quando o chão sob ele existir
	player.global_position = Vector3(0, chunks.height_at(0, 0) + 1.0, 0)
	chunks.target = player
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


func save_game() -> void:
	if SaveSystem.save_to(self):
		EventBus.message.emit("Jogo salvo.")
	else:
		EventBus.message.emit("Não foi possível salvar.")


func load_game() -> void:
	if SaveSystem.load_from(self):
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
		EventBus.world_ready.emit()
		return
	if player.frozen:
		return
	# Rede de segurança: se por algum motivo o jogador atravessar o chão, devolve para cima.
	var ground := chunks.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground - 6.0:
		player.global_position.y = ground + 2.0
		player.velocity = Vector3.ZERO
