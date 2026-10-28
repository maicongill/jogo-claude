extends Node
## Estado global do jogo: opções, seed do mundo e controle de captura do mouse.

## Seed global: a mesma seed gera o mesmo mundo.
var world_seed: int = 12345
var mouse_sensitivity: float = 0.003
## Raio de chunks carregados em volta do jogador.
var load_radius: int = 6

## Verdadeiro enquanto o modo de construção está ativo (a roda do mouse troca a peça, não a hotbar).
var build_mode := false

## Opção do jogador: perder os itens ao morrer (fome e durabilidade não têm opção).
var lose_items_on_death := true
## Ponto de renascimento (cama). Vector3.INF = ainda não há cama.
var spawn_point := Vector3.INF
## Ponto inicial do mundo, definido pela cena principal.
var default_spawn := Vector3(0, 3, 0)
## Posições dos estábulos construídos (onde o pet renasce).
var stables: Array[Vector3] = []
## Começa com ferramentas no inventário (útil para testar). Desligado quando o crafting existir.
var debug_starter_kit := false
## O jogador nasce com uma pilha de cada item do jogo (game.start_with_all_items). Os testes ignoram.
var start_with_all_items := false
## O jogo começa com um Aerolho já domado (confiança máxima) e selado ao lado do jogador
## (game.start_with_tamed_pet). Os testes ignoram.
var start_with_tamed_pet := false

var _ui_open_count := 0
## Modo criativo: todos os itens à mão (Tab) e construções sem custo. Falso = sobrevivência.
var creative := false

## Mundo em que o jogador está (pasta em user://worlds/). Vazio = sem mundo (testes, cena direta).
var current_world := ""
## Ao entrar num mundo que já tem save: o mundo carrega o save assim que o chão existir.
var loading_world := false

const MENU_SCENE := "res://scenes/main_menu.tscn"
const WORLD_SCENE := "res://scenes/main.tscn"


func _enter_tree() -> void:
	Keybinds.init()
	Worlds.init()
	apply_config()
	Config.reloaded.connect(apply_config)


## Lê as opções gerais de config/game_config.json (seção "game" e "world").
func apply_config() -> void:
	if current_world == "":
		world_seed = Config.i("game.world_seed", world_seed)  # dentro de um mundo, a seed é a dele
	lose_items_on_death = Config.b("game.lose_items_on_death", lose_items_on_death)
	mouse_sensitivity = Config.f("game.mouse_sensitivity", mouse_sensitivity)
	start_with_all_items = Config.b("game.start_with_all_items", start_with_all_items)
	start_with_tamed_pet = Config.b("game.start_with_tamed_pet", start_with_tamed_pet)
	load_radius = Config.i("world.load_radius", load_radius)


func is_ui_open() -> bool:
	return _ui_open_count > 0


## Chamado por qualquer painel que precise do cursor (inventário, menu...).
func push_ui() -> void:
	_ui_open_count += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func pop_ui() -> void:
	_ui_open_count = maxi(_ui_open_count - 1, 0)
	if _ui_open_count == 0:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Entra num mundo: novo (começa do zero com a seed dele) ou existente (carrega o save).
func start_world(id: String) -> void:
	if prepare_world(id):
		get_tree().change_scene_to_file(WORLD_SCENE)


## Deixa tudo pronto para abrir o mundo (estado limpo, seed dele, carregar o save se houver).
func prepare_world(id: String) -> bool:
	var info := Worlds.get_info(id)
	if info.is_empty():
		return false
	reset_world_state()
	current_world = id
	world_seed = int(info["seed"])
	loading_world = Worlds.has_save(id)
	Worlds.touch(id)
	return true


## Salva o mundo atual e volta ao menu inicial.
func exit_to_menu() -> void:
	save_current_world()
	reset_world_state()
	current_world = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


## Salva o mundo atual (se houver um mundo aberto).
func save_current_world() -> bool:
	var scene := get_tree().current_scene
	if current_world == "" or scene == null or not scene.has_method("save_game"):
		return false
	return scene.save_game()


## Onde salvar: no mundo atual, ou no arquivo padrão quando não há mundo (testes, cena direta).
func save_path() -> String:
	return Worlds.save_path(current_world) if current_world != "" else SaveSystem.DEFAULT_PATH


## Limpa o que é de um mundo e fica nos autoloads (senão vazaria para o próximo mundo).
func reset_world_state() -> void:
	WorldState.reset()
	stables.clear()
	spawn_point = Vector3.INF
	build_mode = false
	_ui_open_count = 0
	loading_world = false
	creative = false


## Fechar a janela no meio do jogo também salva.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_world()


## Troca entre sobrevivência e criativo (o modo fica salvo no mundo).
func set_creative(on: bool) -> void:
	if creative == on:
		return
	creative = on
	if current_world != "":
		Worlds.set_mode(current_world, on)
	EventBus.game_mode_changed.emit(on)
