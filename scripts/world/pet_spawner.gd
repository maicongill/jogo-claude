class_name PetSpawner
extends Node
## Cria pets selvagens em planícies e florestas conforme os chunks carregam.

const SPAWN_CHANCE := 0.10
## Chunks que sempre têm um pet, para o jogador encontrar um perto do início.
const GUARANTEED: Array[Vector2i] = [Vector2i(1, 0)]

var chunks: ChunkManager
var world_root: Node3D
var pets: Dictionary = {}  # Vector2i -> FlyingPet


func setup(manager: ChunkManager, root: Node3D) -> void:
	chunks = manager
	world_root = root
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)


func _key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _on_chunk_loaded(c: Vector2i) -> void:
	if pets.has(c) or WorldState.owned_pets.has(_key(c)) or Database.pets.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ChunkBuilder._mix(chunks.world_seed, c.x, c.y, 4242)
	if not (c in GUARANTEED) and rng.randf() > SPAWN_CHANCE:
		return
	var size := chunks.chunk_size
	var x := c.x * size + rng.randf_range(6.0, size - 6.0)
	var z := c.y * size + rng.randf_range(6.0, size - 6.0)
	var pet := create_pet(Database.pets.values()[0], Vector3(x, chunks.height_at(x, z), z))
	pet.set_meta(&"chunk_key", _key(c))
	pet.trust_changed.connect(_on_trust_changed.bind(c))
	pets[c] = pet


## Cria um pet com as funções do mundo ligadas (também usado nos testes).
func create_pet(data: PetData, pos: Vector3) -> FlyingPet:
	var pet := FlyingPet.new()
	pet.data = data
	pet.height_fn = chunks.height_at
	pet.forest_fn = chunks.generator.is_forest
	world_root.add_child(pet)
	pet.global_position = pos
	return pet


func _on_trust_changed(pet: FlyingPet, c: Vector2i) -> void:
	# Pets com algum vínculo viram "do jogador": não somem quando o chunk descarrega.
	if pet.trust > 0.0 and pets.has(c):
		pets.erase(c)
		WorldState.owned_pets[_key(c)] = true


func _on_chunk_unloaded(c: Vector2i) -> void:
	if pets.has(c):
		var p: Variant = pets[c]
		if is_instance_valid(p) and p.trust <= 0.0 and p.rider == null:
			p.queue_free()
		pets.erase(c)
