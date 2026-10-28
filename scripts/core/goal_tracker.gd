class_name GoalTracker
extends Node
## Acompanha a meta do protótipo (GDD, meta de teste atualizada na Etapa 6) e mostra a dica do próximo passo.

const GOALS: Array[Dictionary] = [
	{"id": &"wood", "text": "Coletar madeira", "hint": "Chegue perto de uma árvore e aperte E (ou clique) para coletar madeira."},
	{"id": &"stone", "text": "Coletar pedra", "hint": "Pedras exigem uma picareta. Aperte Tab e crie uma picareta de madeira (3 madeiras), selecione-a na hotbar e bata na pedra."},
	{"id": &"tool", "text": "Fazer uma ferramenta", "hint": "Aperte Tab: o crafting fica ao lado do inventário. Crie um machado ou uma picareta."},
	{"id": &"house", "text": "Construir uma casa com porta e janelas", "hint": "Aperte B: piso, uma porta, duas janelas (roda do mouse troca a peça) e um telhado. R gira; vigas reforçam."},
	{"id": &"tame", "text": "Domar o pet voador", "hint": "Olhe para o Aerolho (azul, voa perto do início) para descobrir o que ele gosta. Use a Doma (T e botão direito) e ofereça frutinhas (E). Depois use uma sela."},
	{"id": &"fly", "text": "Voar fazendo manobras", "hint": "Monte (F) e faça as duas manobras: mergulho (C em velocidade) e planar (Q liga e desliga; recupera estamina)."},
	{"id": &"carry", "text": "Carregar itens com o pet", "hint": "Montado (ou perto do pet selado), aperte Tab e ponha itens no alforje (Shift + clique). Depois voe uns 40 m com ele carregado."},
	{"id": &"enemy_types", "text": "Derrotar 2 tipos de inimigo", "hint": "Saltilhos e cuspidores aparecem longe do início; musgolhos nas florestas. Cada um pede uma resposta diferente."},
	{"id": &"arsenal", "text": "Derrotar inimigos com espada, arco e magia", "hint": "Dê o golpe final com cada uma: espada (segure para golpe carregado), arco (segure para carregar) e magia (Z fogo, X vento)."},
]

var done: Dictionary = {}  # id -> true
var player: Player
## Progresso dos objetivos com várias partes.
var maneuvers: Dictionary = {}      # manobras de voo feitas
var killed_types: Dictionary = {}   # tipos de inimigo derrotados
var kill_sources: Dictionary = {}   # sword / bow / magic usados no golpe final
var carried_distance := 0.0
var _last_pet_pos := Vector3.INF


func setup(p: Player) -> void:
	player = p
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.item_crafted.connect(_on_item_crafted)
	EventBus.piece_placed.connect(func(_p: Node3D) -> void: _check_house())
	EventBus.pet_maneuver.connect(_on_maneuver)
	EventBus.pet_level_changed.connect(func(_pet: Node3D, lv: int) -> void:
		if lv >= 3:
			complete(&"tame"))
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.world_ready.connect(func() -> void: _announce_current(true), CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	# "Carregar itens" = voar montado com algo no alforje por uns 40 m.
	var pet := player.mounted_pet
	if pet == null or done.has(&"carry") or pet.load_fraction() <= 0.0:
		_last_pet_pos = Vector3.INF
		return
	if _last_pet_pos != Vector3.INF:
		carried_distance += pet.global_position.distance_to(_last_pet_pos)
	_last_pet_pos = pet.global_position
	if carried_distance >= Config.f("goals.carry_distance", 40.0):
		complete(&"carry")


func _on_maneuver(m: StringName) -> void:
	if maneuvers.has(m):
		return
	maneuvers[m] = true
	var names := {&"dive": "Mergulho", &"glide": "Planar"}
	EventBus.message.emit("Manobra: %s (%d/2)" % [names.get(m, String(m)), mini(maneuvers.size(), 2)])
	if maneuvers.size() >= 2:
		complete(&"fly")


func _on_enemy_killed(e: Node3D) -> void:
	var enemy := e as Enemy
	if enemy == null:
		return
	killed_types[enemy.type_id if enemy.type_id != &"" else &"musgolho"] = true
	if killed_types.size() >= 2:
		complete(&"enemy_types")
	if enemy.last_source in [&"sword", &"bow", &"magic"] and not kill_sources.has(enemy.last_source):
		kill_sources[enemy.last_source] = true
		var names := {&"sword": "espada", &"bow": "arco", &"magic": "magia"}
		var got: PackedStringArray = []
		for k in [&"sword", &"bow", &"magic"]:
			got.append(("✓ " if kill_sources.has(k) else "· ") + names[k])
		if not done.has(&"arsenal"):
			EventBus.message.emit("Inimigo derrotado com %s  (%s)" % [names[enemy.last_source], "  ".join(got)])
		if kill_sources.size() >= 3:
			complete(&"arsenal")


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
	var doors := 0
	var windows := 0
	var roofs := 0
	for p: BuildPiece in get_tree().get_nodes_in_group(&"build_piece"):
		match p.piece_id:
			&"floor": floors += 1
			&"door": doors += 1
			&"window": windows += 1
			&"roof": roofs += 1
	if floors >= 1 and doors >= 1 and windows >= 2 and roofs >= 1:
		complete(&"house")
