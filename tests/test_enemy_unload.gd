extends Node
## Regressão: descarregar um chunk cujo inimigo já morreu não pode dar erro.

func _ready() -> void:
	var sp := EnemySpawner.new()
	add_child(sp)
	var e := Enemy.new()
	add_child(e)
	sp.enemies[Vector2i(3, 3)] = e
	e.free()
	sp._on_chunk_unloaded(Vector2i(3, 3))
	var ok := not sp.enemies.has(Vector2i(3, 3))
	print("OK" if ok else "FALHOU: inimigo não removido")
	get_tree().quit(0 if ok else 1)
