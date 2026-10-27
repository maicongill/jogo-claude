class_name GoalTracker
extends Node
## Acompanha a meta do protótipo (GDD, marco 10) e mostra a dica do próximo passo.

const GOALS: Array[Dictionary] = [
	{"id": &"wood", "text": "Coletar madeira", "hint": "Chegue perto de uma árvore e aperte E (ou clique) para coletar madeira."},
	{"id": &"stone", "text": "Coletar pedra", "hint": "Pedras exigem uma picareta. Aperte Tab e crie uma picareta de madeira (3 madeiras), selecione-a na hotbar e bata na pedra."},
	{"id": &"tool", "text": "Fazer uma ferramenta", "hint": "Aperte Tab: o crafting fica ao lado do inventário. Crie um machado ou uma picareta."},
	{"id": &"house", "text": "Construir uma casa pequena", "hint": "Aperte B para construir: piso, 3 paredes (ou porta) e um telhado. Roda do mouse troca a peça, R gira."},
	{"id": &"magic", "text": "Lançar uma magia", "hint": "As magias já estão com você: Z bola de fogo, X rajada de vento, V muralha de terra. O botão direito lança a escolhida (gasta mana)."},
	{"id": &"tame", "text": "Domar o pet voador", "hint": "Olhe para o Aerolho (azul, voa perto do início) para descobrir o que ele gosta. Use a magia de Doma (botão direito) e ofereça frutinhas (E). Depois use uma sela."},
	{"id": &"fly", "text": "Voar com o pet", "hint": "Com o pet selado e confiando, aperte F perto dele. Espaço sobe, C desce, Shift acelera."},
	{"id": &"enemy", "text": "Derrotar um inimigo", "hint": "Os musgolhos vivem nas florestas. Crie uma espada ou um arco e ataque com o clique; Q esquiva."},
]

var done: Dictionary = {}  # id -> true
var player: Player
var _fly_timer := 0.0


func setup(p: Player) -> void:
	player = p
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.piece_placed.connect(func(_p: Node3D) -> void: _check_house())
	EventBus.spell_cast.connect(func(s: MagicData) -> void:
		if s.effect != &"tame":
			complete(&"magic"))
	EventBus.pet_level_changed.connect(func(_pet: Node3D, lv: int) -> void:
		if lv >= 3:
			complete(&"tame"))
	EventBus.enemy_killed.connect(func(_e: Node3D) -> void: complete(&"enemy"))
	EventBus.world_ready.connect(func() -> void: _announce_current(true), CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	# "Voar" = ficar montado e longe do chão por um instante.
	var pet := player.mounted_pet
	if pet != null and not done.has(&"fly"):
		var ground: float = pet.height_fn.call(pet.global_position.x, pet.global_position.z)
		if pet.global_position.y > ground + 3.0:
			_fly_timer += delta
			if _fly_timer > 1.0:
				complete(&"fly")
	else:
		_fly_timer = 0.0


func is_done(id: StringName) -> bool:
	return done.has(id)


func all_done() -> bool:
	for g in GOALS:
		if not done.has(g["id"]):
			return false
	return true


func current() -> Dictionary:
	for g in GOALS:
		if not done.has(g["id"]):
			return g
	return {}


func complete(id: StringName) -> void:
	if done.has(id):
		return
	done[id] = true
	EventBus.goal_completed.emit(id)
	for g in GOALS:
		if g["id"] == id:
			EventBus.message.emit("Objetivo concluído: %s" % g["text"])
	_announce_current(false)


func _announce_current(first: bool) -> void:
	var g := current()
	if g.is_empty():
		EventBus.hint_requested.emit("Você completou todos os objetivos do protótipo! Explore, construa e domine o mundo.")
	elif first:
		EventBus.hint_requested.emit("Bem-vindo! WASD move, Shift corre, Espaço pula, C agacha, Tab abre o inventário.\n" + g["hint"])
	else:
		EventBus.hint_requested.emit("Próximo: " + g["hint"])


func _on_item_collected(item: ItemData, _count: int) -> void:
	if item.id == &"wood":
		complete(&"wood")
	elif item.id == &"stone":
		complete(&"stone")


func _on_item_crafted(item: ItemData) -> void:
	if item.kind == ItemData.Kind.TOOL:
		complete(&"tool")


func _check_house() -> void:
	var floors := 0
	var walls := 0
	var roofs := 0
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		match p.piece_id:
			&"floor": floors += 1
			&"wall", &"door": walls += 1
			&"roof": roofs += 1
	if floors >= 1 and walls >= 3 and roofs >= 1:
		complete(&"house")
