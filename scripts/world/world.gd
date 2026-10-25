extends Node3D
## Cena principal: monta o terreno por chunks e coloca o jogador.

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var player: Player
var chunks: ChunkManager
var hud: HUD


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

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player)


func _physics_process(_delta: float) -> void:
	if player.frozen:
		var spawn_chunks: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]
		for c in spawn_chunks:
			if not chunks.is_loaded(c):
				return
		player.frozen = false
		EventBus.world_ready.emit()
		return
	# Rede de segurança: se por algum motivo o jogador atravessar o chão, devolve para cima.
	var ground := chunks.height_at(player.global_position.x, player.global_position.z)
	if player.global_position.y < ground - 6.0:
		player.global_position.y = ground + 2.0
		player.velocity = Vector3.ZERO
