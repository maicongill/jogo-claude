class_name EnemySpawner
extends Node
## Cria musgolhos nas florestas conforme os chunks carregam e os remove quando descarregam.

const SPAWN_CHANCE := 0.4

var chunks: ChunkManager
var world_root: Node3D
var enemies: Dictionary = {}  # Vector2i -> Enemy


func setup(manager: ChunkManager, root: Node3D) -> void:
	chunks = manager
	world_root = root
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)


func _key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _on_chunk_loaded(c: Vector2i) -> void:
	if enemies.has(c) or WorldState.killed_enemies.has(_key(c)):
		return
	var size := chunks.chunk_size
	var center := Vector2(c.x * size + size * 0.5, c.y * size + size * 0.5)
	if chunks.generator.forest_amount(center.x, center.y) < 0.6:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ChunkBuilder._mix(chunks.world_seed, c.x, c.y, 7777)
	if rng.randf() > SPAWN_CHANCE:
		return
	var x := c.x * size + rng.randf_range(4.0, size - 4.0)
	var z := c.y * size + rng.randf_range(4.0, size - 4.0)
	var enemy := Enemy.new()
	enemy.spawn_key = _key(c)
	world_root.add_child(enemy)
	enemy.global_position = Vector3(x, chunks.height_at(x, z) + 1.0, z)
	enemies[c] = enemy


func _on_chunk_unloaded(c: Vector2i) -> void:
	if enemies.has(c):
		var e: Enemy = enemies[c]
		if is_instance_valid(e):
			e.queue_free()
		enemies.erase(c)
