class_name FarWorld
extends Node3D
## Mundo distante, além dos chunks de perto. Faixa média (blocos de 96 m): terreno simplificado e
## árvores, pedras e arbustos como imagens (PNG, num atlas) viradas para a câmera, nas mesmas posições
## dos objetos 3D. Faixa longe (blocos de 128 m): terreno mais simples em que a floresta vira um
## dossel verde no próprio terreno (shaders/far_terrain.gdshader). Cada faixa fica um pouco abaixo da
## anterior, então onde as duas existem a mais detalhada aparece por cima; as trocas usam pontilhado
## (imagens) e uma subida gradual (dossel), na mesma faixa de distância.

const IMPOSTOR_DIR := "res://assets/impostors/"

var chunks: ChunkManager
var target: Node3D

var _cfg: Dictionary = {}
var _defs: Array = []
var _def_ids: Array[StringName] = []
var _tree_index := -1
var _tiles: Dictionary = {}    # [far, Vector2i] -> Node3D
var _data: Dictionary = {}     # [far, Vector2i] -> dados do bloco (para refazer as imagens)
var _tasks: Dictionary = {}    # [far, Vector2i] -> id
var _results: Dictionary = {}
var _queue: Array = []
var _mutex := Mutex.new()
var _last_center := Vector2(INF, INF)
var _quad: QuadMesh
var _impostor_mat: ShaderMaterial
var _frames: Dictionary = {}     # id do objeto -> {size, bottom, column}
var _terrain_mat: Material
var _far_terrain_mat: ShaderMaterial


func setup(manager: ChunkManager, who: Node3D) -> void:
	chunks = manager
	target = who
	name = "FarWorld"
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_quad.center_offset = Vector3(0, 0.5, 0)
	_terrain_mat = MaterialFactory.vertex_color(MaterialFactory.Hull.NONE)
	_far_terrain_mat = ShaderMaterial.new()
	_far_terrain_mat.shader = preload("res://shaders/far_terrain.gdshader")
	_load_impostors()
	_apply_config()
	Config.reloaded.connect(func() -> void:
		_apply_config()
		reload_all())
	# Quando um chunk de perto sai, refaz as imagens do bloco médio dele (recursos coletados somem).
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)


func _apply_config() -> void:
	_cfg = Config.section("lod")
	_defs.clear()
	_def_ids.clear()
	for i in Database.resource_nodes.size():
		var d := Database.resource_nodes[i]
		_defs.append({"index": i, "density_plain": d.density_plain, "density_forest": d.density_forest,
				"radius": d.radius, "scale_min": d.scale_min, "scale_max": d.scale_max})
		_def_ids.append(d.id)
		if d.mesh_id == &"tree":
			_tree_index = i
	_far_terrain_mat.set_shader_parameter("canopy_height", float(_cfg.get("canopy_height", 4.5)))
	_far_terrain_mat.set_shader_parameter("canopy_color", Config.to_color(_cfg.get("canopy_color"), Color(0.02, 0.30, 0.03)))
	# A neblina acompanha a distância de renderização nova.
	var we := get_tree().get_first_node_in_group(&"world_environment") as WorldEnvironment
	if we == null:
		for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			we = n as WorldEnvironment
	if we != null and we.environment != null and enabled():
		we.environment.fog_depth_begin = _cfg.get("fog_begin", 380.0)
		we.environment.fog_depth_end = _cfg.get("fog_end", 1050.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.far = maxf(cam.far, float(_cfg.get("far_radius", 1100.0)) + 200.0)


func enabled() -> bool:
	return bool(_cfg.get("enabled", true))


func _load_impostors() -> void:
	var info := {}
	var f := FileAccess.open(IMPOSTOR_DIR + "impostors.json", FileAccess.READ)
	if f != null:
		info = JSON.parse_string(f.get_as_text())
	var atlas := load(IMPOSTOR_DIR + "atlas.png") as Texture2D
	if atlas == null or info.is_empty():
		push_warning("FarWorld: faltam as imagens (rode tools/bake_impostors.tscn).")
		return
	for d in Database.resource_nodes:
		var fr: Dictionary = info.get(String(d.mesh_id), {})
		if not fr.is_empty():
			_frames[d.id] = fr
	_impostor_mat = ShaderMaterial.new()
	_impostor_mat.shader = preload("res://shaders/impostor.gdshader")
	_impostor_mat.set_shader_parameter("albedo_tex", atlas)
	_impostor_mat.set_shader_parameter("columns", float(info.get("_columns", 1)))


func _process(_delta: float) -> void:
	if target == null or not enabled():
		return
	var p := Vector2(target.global_position.x, target.global_position.z)
	if p.distance_to(_last_center) > float(_cfg.get("mid_tile", 96)) * 0.5:
		_last_center = p
		_refresh(p)
	_start_tasks()
	_finalize()


## Quais blocos devem existir: médios até mid_radius, longes até far_radius. Os que ficam inteiros
## dentro da faixa mais detalhada não são feitos (lá eles nunca apareceriam).
func _wanted(p: Vector2) -> Array:
	var out: Array = []
	for far in [false, true]:
		var tile: int = _cfg.get("far_tile", 128) if far else _cfg.get("mid_tile", 96)
		var outer: float = _cfg.get("far_radius", 1100.0) if far else _cfg.get("mid_radius", 650.0)
		var inner: float = float(_cfg.get("far_fade_start", 500.0)) if far else float(_cfg.get("near_fade_start", 130.0))
		var half := tile * 0.5
		var reach := ceili(outer / tile) + 1
		var c := Vector2i(floori(p.x / tile), floori(p.y / tile))
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var t := c + Vector2i(dx, dz)
				var center := Vector2(t.x * tile + half, t.y * tile + half)
				var d := center.distance_to(p)
				if d - half * 1.42 > outer or d + half * 1.42 < inner - 10.0:
					continue
				out.append([far, t, d])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return not a[0]  # médios primeiro
		return a[2] < b[2])
	return out


func _refresh(p: Vector2) -> void:
	var wanted := _wanted(p)
	var keep := {}
	_queue.clear()
	for w: Array in wanted:
		var key := [w[0], w[1]]
		keep[key] = true
		if not _tiles.has(key) and not _tasks.has(key):
			_queue.append(key)
	# Folga de um bloco antes de descartar, para não ficar criando e apagando na fronteira.
	for key: Array in _tiles.keys():
		if keep.has(key):
			continue
		var tile: int = _cfg.get("far_tile", 128) if key[0] else _cfg.get("mid_tile", 96)
		var outer: float = _cfg.get("far_radius", 1100.0) if key[0] else _cfg.get("mid_radius", 650.0)
		var t: Vector2i = key[1]
		var center := Vector2(t.x * tile + tile * 0.5, t.y * tile + tile * 0.5)
		if center.distance_to(p) > outer + tile * 1.5 or center.distance_to(p) < 0.0:
			_free_tile(key)


func _free_tile(key: Array) -> void:
	if _tiles.has(key):
		_tiles[key].queue_free()
		_tiles.erase(key)
	_data.erase(key)


func _start_tasks() -> void:
	var limit: int = _cfg.get("max_tasks", 2)
	while not _queue.is_empty() and _tasks.size() < limit:
		var key: Array = _queue.pop_front()
		if _tiles.has(key) or _tasks.has(key):
			continue
		var far: bool = key[0]
		var t: Vector2i = key[1]
		var tile: int = _cfg.get("far_tile", 128) if far else _cfg.get("mid_tile", 96)
		var params := {
			"seed": chunks.world_seed, "origin": Vector2i(t.x * tile, t.y * tile), "size": tile,
			"step": _cfg.get("far_step", 8) if far else _cfg.get("mid_step", 4),
			"chunk_size": chunks.chunk_size, "defs": _defs.duplicate(true),
			"lower": _cfg.get("far_lower", 2.5) if far else _cfg.get("mid_lower", 0.6),
			"skirt": 10.0 if far else 5.0, "far": far, "tree_index": _tree_index,
			"canopy_min": _cfg.get("canopy_min", 1.5), "canopy_full": _cfg.get("canopy_full", 7.5),
		}
		_tasks[key] = WorkerThreadPool.add_task(_generate.bind(key, params))


func _generate(key: Array, params: Dictionary) -> void:
	var data := FarBuilder.build(params)
	_mutex.lock()
	_results[key] = data
	_mutex.unlock()


func _finalize() -> void:
	_mutex.lock()
	var ready: Array = _results.keys()
	_mutex.unlock()
	var done := 0
	for key: Array in ready:
		if done >= int(_cfg.get("max_tiles_per_frame", 2)):
			break
		_mutex.lock()
		var data: Dictionary = _results[key]
		_results.erase(key)
		_mutex.unlock()
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
		_tasks.erase(key)
		_data[key] = data
		_tiles[key] = _make_tile(data)
		done += 1


func _make_tile(data: Dictionary) -> Node3D:
	var node := Node3D.new()
	var origin: Vector2i = data["origin"]
	node.position = Vector3(origin.x, 0, origin.y)
	add_child(node)
	var t: Dictionary = data["terrain"]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = t["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = t["normals"]
	arrays[Mesh.ARRAY_COLOR] = t["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = t["uvs"]
	arrays[Mesh.ARRAY_INDEX] = t["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = _far_terrain_mat if data["far"] else _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	if not data["far"]:
		_add_impostors(node, data["objects"])
	return node


## Faixa média: uma MultiMesh por bloco com todas as imagens (árvores, pedras e arbustos, cada uma
## numa coluna do atlas), pulando os objetos que já foram coletados.
func _add_impostors(node: Node3D, objects: Array) -> void:
	if _impostor_mat == null:
		return
	var by_type := impostor_transforms(objects)
	var xfs: Array = []
	var cols: Array = []
	for id: StringName in by_type:
		for xf in by_type[id]:
			xfs.append(xf)
			cols.append(float(_frames[id].get("column", 0)))
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_custom_data(i, Color(cols[i], 0, 0, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Impostors"
	mmi.multimesh = mm
	mmi.material_override = _impostor_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta(&"transforms", xfs)  # cópia das posições (o servidor sem tela não as guarda)
	mmi.set_meta(&"types", by_type.keys())
	node.add_child(mmi)


## Onde fica cada imagem (por tipo de objeto), no espaço do bloco: a base do quadrado no pé do
## objeto e o tamanho igual ao enquadramento usado ao gerar o PNG.
func impostor_transforms(objects: Array) -> Dictionary:
	var by_type: Dictionary = {}
	for o: Dictionary in objects:
		var id: StringName = _def_ids[o["index"]]
		if not _frames.has(id):
			continue
		var state := WorldState.resource_states.get("%s,%s" % [o["key"], id], {}) as Dictionary
		var s: Variant = state.get(o["i"])
		if s != null and float(s[0]) <= 0.0:
			continue  # coletado (árvore cortada, pedra quebrada)
		if not by_type.has(id):
			by_type[id] = []
		var xf: Transform3D = o["xf"]
		var fr: Dictionary = _frames[id]
		var sc := xf.basis.get_scale().x
		var size: float = fr["size"] * sc
		var pos := xf.origin + Vector3(0, float(fr["bottom"]) * sc, 0)
		by_type[id].append(Transform3D(Basis().scaled(Vector3(size, size, size)), pos))
	return by_type


func _on_chunk_unloaded(coord: Vector2i) -> void:
	var tile: int = _cfg.get("mid_tile", 96)
	var t := Vector2i(floori(float(coord.x * chunks.chunk_size) / tile), floori(float(coord.y * chunks.chunk_size) / tile))
	var key := [false, t]
	if not _tiles.has(key) or not _data.has(key):
		return
	for c in _tiles[key].get_children():
		if c is MultiMeshInstance3D:
			c.queue_free()
	_add_impostors(_tiles[key], _data[key]["objects"])


## Apaga tudo e gera de novo (ao carregar um jogo ou recarregar a configuração).
func reload_all() -> void:
	for key: Array in _tiles.keys():
		_free_tile(key)
	_queue.clear()
	_last_center = Vector2(INF, INF)


## Quantos blocos de cada faixa existem (para testes).
func tile_count(far: bool) -> int:
	var n := 0
	for key: Array in _tiles:
		if key[0] == far:
			n += 1
	return n


## Ao sair da cena (fechar o jogo, trocar de cena), espera as threads terminarem: senão uma
## geração em andamento tentaria usar este nó já apagado.
func _exit_tree() -> void:
	flush()
	_tasks.clear()


## Usado por testes: espera as tarefas pendentes.
func flush() -> void:
	for key: Array in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
