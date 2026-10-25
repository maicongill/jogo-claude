extends Node
## Registro de todos os Resources de conteúdo. Para adicionar conteúdo, crie um .tres
## na pasta certa de res://resources/; ele é carregado aqui automaticamente.

var items: Dictionary = {}            # StringName -> ItemData
var recipes: Array[RecipeData] = []
var resource_nodes: Array[ResourceNodeData] = []
var build_pieces: Array[BuildPieceData] = []
var magic: Dictionary = {}              # StringName -> MagicData
var scroll_recipes: Array[ScrollRecipeData] = []
var pets: Dictionary = {}               # StringName -> PetData


func _ready() -> void:
	for r in _load_dir("res://resources/items"):
		var item := r as ItemData
		if item:
			items[item.id] = item
	for r in _load_dir("res://resources/resource_nodes"):
		if r is ResourceNodeData:
			resource_nodes.append(r)
	for r in _load_dir("res://resources/build_pieces"):
		if r is BuildPieceData:
			build_pieces.append(r)
	for r in _load_dir("res://resources/magic"):
		if r is MagicData:
			magic[r.id] = r
	for r in _load_dir("res://resources/scroll_recipes"):
		if r is ScrollRecipeData:
			scroll_recipes.append(r)
	for r in _load_dir("res://resources/pets"):
		if r is PetData:
			pets[r.id] = r
	for r in _load_dir("res://resources/recipes"):
		if r is RecipeData:
			recipes.append(r)


func spell(id: StringName) -> MagicData:
	return magic.get(id) as MagicData


func item(id: StringName) -> ItemData:
	return items.get(id) as ItemData


func _load_dir(path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		# Em jogos exportados os arquivos aparecem como ".tres.remap".
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(load(path.path_join(name)))
	return out
