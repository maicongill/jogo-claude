class_name ChunkManager
extends Node3D
## Carrega e descarta chunks em volta do alvo (o jogador). A geração roda em threads
## (WorkerThreadPool); só a criação dos nós acontece na thread principal.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

@export var chunk_size := 32
@export var load_radius := 6
@export var max_tasks_in_flight := 4
@export var max_chunks_per_frame := 2

var world_seed := 0
var target: Node3D
var generator: TerrainGenerator

var _node_defs: Array[ResourceNodeData] = []
var _def_dicts: Array = []
var _chunks: Dictionary = {}   # Vector2i -> Chunk
var _tasks: Dictionary = {}    # Vector2i -> id da tarefa
var _results: Dictionary = {}  # Vector2i -> dados prontos
var _queue: Array[Vector2i] = []
var _mutex := Mutex.new()
var _center := Vector2i(1 << 30, 1 << 30)


func setup(seed_value: int, node_defs: Array[ResourceNodeData]) -> void:
	world_seed = seed_value
	chunk_size = Config.i("world.chunk_size", chunk_size)
	generator = TerrainGenerator.new(seed_value)
	_node_defs = node_defs
	_def_dicts.clear()
	for i in node_defs.size():
		var d := node_defs[i]
		_def_dicts.append({"index": i, "density_plain": d.density_plain, "density_forest": d.density_forest,
				"radius": d.radius, "scale_min": d.scale_min, "scale_max": d.scale_max})


func world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))


func is_loaded(coord: Vector2i) -> bool:
	return _chunks.has(coord)


func loaded_count() -> int:
	return _chunks.size()


func height_at(x: float, z: float) -> float:
	return generator.height_at(x, z)


func _process(_delta: float) -> void:
	if target == null:
		return
	if load_radius != Game.load_radius:
		load_radius = Game.load_radius
		_center = Vector2i(1 << 30, 1 << 30)
	var c := world_to_chunk(target.global_position)
	if c != _center:
		_center = c
		_refresh_queue()
	_start_tasks()
	_finalize_ready()


func _refresh_queue() -> void:
	var wanted: Array[Vector2i] = []
	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			if dx * dx + dz * dz <= load_radius * load_radius:
				wanted.append(_center + Vector2i(dx, dz))
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - _center).length_squared() < (b - _center).length_squared())
	_queue.clear()
	for c in wanted:
		if not _chunks.has(c) and not _tasks.has(c):
			_queue.append(c)
	# Descarta os que ficaram longe.
	var limit := (load_radius + 1) * (load_radius + 1)
	for c: Vector2i in _chunks.keys():
		if (c - _center).length_squared() > limit:
			_chunks[c].queue_free()
			_chunks.erase(c)
			chunk_unloaded.emit(c)


func _start_tasks() -> void:
	while not _queue.is_empty() and _tasks.size() < max_tasks_in_flight:
		var c: Vector2i = _queue.pop_front()
		if _chunks.has(c) or _tasks.has(c):
			continue
		_tasks[c] = WorkerThreadPool.add_task(_generate.bind(c))


func _generate(coord: Vector2i) -> void:
	var data := ChunkBuilder.build(world_seed, coord, chunk_size, _def_dicts)
	_mutex.lock()
	_results[coord] = data
	_mutex.unlock()


func _finalize_ready() -> void:
	_mutex.lock()
	var ready: Array = _results.keys()
	_mutex.unlock()
	ready.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - _center).length_squared() < (b - _center).length_squared())
	var done := 0
	for c: Vector2i in ready:
		if done >= max_chunks_per_frame:
			break
		_mutex.lock()
		var data: Dictionary = _results[c]
		_results.erase(c)
		_mutex.unlock()
		WorkerThreadPool.wait_for_task_completion(_tasks[c])
		_tasks.erase(c)
		if (c - _center).length_squared() > (load_radius + 1) * (load_radius + 1):
			continue  # o jogador já se afastou
		var chunk := Chunk.new()
		add_child(chunk)
		chunk.setup(data, chunk_size, _node_defs)
		_chunks[c] = chunk
		chunk_loaded.emit(c)
		done += 1


## Descarta todos os chunks e gera de novo (usado ao carregar um jogo salvo, para aplicar o estado do mundo).
func reload_all() -> void:
	for c: Vector2i in _chunks.keys():
		_chunks[c].queue_free()
		chunk_unloaded.emit(c)
	_chunks.clear()
	_queue.clear()
	_center = Vector2i(1 << 30, 1 << 30)


## Usado por testes: espera todas as tarefas pendentes.
func flush() -> void:
	for c: Vector2i in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[c])
