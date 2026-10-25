extends Node
## Lê config/game_config.json: a fonte única de parâmetros, itens, receitas e conteúdo do jogo.
## Edite o arquivo e rode o jogo (ou aperte F10 dentro dele para recarregar ao vivo).

signal reloaded

const PATH := "res://config/game_config.json"

var data: Dictionary = {}
## Arquivo lido (os testes apontam para uma cópia).
var path := PATH


func _enter_tree() -> void:
	if not load_file():
		push_error("Config: não foi possível ler %s. O jogo precisa desse arquivo." % PATH)


## Lê o arquivo. Se estiver com erro, mantém os valores anteriores e avisa.
func load_file() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	var err := parser.parse(FileAccess.get_file_as_string(path))
	if err != OK or not parser.data is Dictionary:
		push_error("Config: erro de JSON em %s, linha %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return false
	data = parser.data
	return true


## F10: recarrega o arquivo e reaplica. Devolve false (e mantém o que estava) se o JSON estiver inválido.
func reload() -> bool:
	if not load_file():
		EventBus.message.emit("Erro no game_config.json: veja o console. Mantendo os valores anteriores.")
		return false
	Database.reload()
	reloaded.emit()
	EventBus.message.emit("Configuração recarregada.")
	return true


## Seção inteira (ex.: "player").
func section(name: String) -> Dictionary:
	return data.get(name, {})


## Valor por caminho com ponto (ex.: "player.walk_speed"). Usa `default` se não existir.
func get_value(path: String, default: Variant = null) -> Variant:
	var cur: Variant = data
	for key in path.split("."):
		if cur is Dictionary and cur.has(key):
			cur = cur[key]
		else:
			return default
	return cur


func f(path: String, default := 0.0) -> float:
	return float(get_value(path, default))


func i(path: String, default := 0) -> int:
	return int(get_value(path, default))


func b(path: String, default := false) -> bool:
	return bool(get_value(path, default))


func color(path: String, default := Color.WHITE) -> Color:
	return to_color(get_value(path, null), default)


static func to_color(v: Variant, default := Color.WHITE) -> Color:
	if v is Array and v.size() >= 3:
		return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0)
	return default
