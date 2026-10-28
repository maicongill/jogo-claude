class_name Worlds
extends RefCounted
## Mundos do jogador: cada um tem uma pasta em user://worlds/<id>/ com world.json (nome, seed,
## datas) e save.json (o estado salvo). Criar, listar, excluir e marcar quando foi jogado.

## Pasta dos mundos (nos testes é outra, para nunca mexer nos mundos do jogador).
static var root := "user://worlds/"


static func init() -> void:
	for a in OS.get_cmdline_args():
		if String(a).begins_with("res://tests/"):
			root = "user://worlds_test/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))


static func dir_of(id: String) -> String:
	return root + id + "/"


static func save_path(id: String) -> String:
	return dir_of(id) + "save.json"


static func has_save(id: String) -> bool:
	return FileAccess.file_exists(save_path(id))


## Lista os mundos, o jogado por último primeiro.
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for id in dir.get_directories():
		var meta := get_info(id)
		if not meta.is_empty():
			out.append(meta)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("played", 0)) > float(b.get("played", 0)))
	return out


static func get_info(id: String) -> Dictionary:
	var f := FileAccess.open(dir_of(id) + "world.json", FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return {}
	d["id"] = id
	d["has_save"] = has_save(id)
	return d


## Cria um mundo. Seed vazia = sorteada; número = esse número; texto = o texto vira um número.
static func create(world_name: String, seed_text: String) -> Dictionary:
	world_name = world_name.strip_edges()
	if world_name == "":
		world_name = "Mundo %d" % (list().size() + 1)
	var s := seed_text.strip_edges()
	var seed_value: int
	if s == "":
		seed_value = randi() % 2147483647
	elif s.is_valid_int():
		seed_value = s.to_int()
	else:
		seed_value = absi(s.hash())
	var id := _slug(world_name) + "_" + str(int(Time.get_unix_time_from_system() * 1000.0) % 100000000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_of(id)))
	var now := Time.get_unix_time_from_system()
	var info := {"name": world_name, "seed": seed_value, "created": now, "played": now}
	_write(id, info)
	info["id"] = id
	info["has_save"] = false
	return info


## Apaga o mundo e tudo que foi salvo nele.
static func delete(id: String) -> bool:
	var path := ProjectSettings.globalize_path(dir_of(id))
	var dir := DirAccess.open(path)
	if dir == null:
		return false
	for f in dir.get_files():
		dir.remove(f)
	return DirAccess.remove_absolute(path) == OK


## Guarda o modo do mundo (para o menu mostrar "Criativo").
static func set_mode(id: String, creative: bool) -> void:
	var info := get_info(id)
	if info.is_empty():
		return
	info["creative"] = creative
	info.erase("id")
	info.erase("has_save")
	_write(id, info)


## Marca que o mundo foi jogado agora (para a lista ficar em ordem).
static func touch(id: String) -> void:
	var info := get_info(id)
	if info.is_empty():
		return
	info["played"] = Time.get_unix_time_from_system()
	info.erase("id")
	info.erase("has_save")
	_write(id, info)


static func _write(id: String, info: Dictionary) -> void:
	var f := FileAccess.open(dir_of(id) + "world.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(info, "\t"))


static func _slug(s: String) -> String:
	var out := ""
	for c in s.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif out != "" and not out.ends_with("-"):
			out += "-"
	out = out.trim_suffix("-")
	return out if out != "" else "mundo"
