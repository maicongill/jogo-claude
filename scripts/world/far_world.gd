class_name FarWorld
extends Node3D
## Mundo distante, além dos chunks de perto. Faixa média (blocos de 64 m): terreno simplificado e
## árvores, pedras e arbustos como imagens (PNG) viradas para a câmera, nas mesmas posições dos
## objetos 3D. Faixa longe (blocos de 128 m): terreno mais simples e as árvores agrupadas em manchas
## de cor sólida. Cada faixa fica um pouco abaixo da anterior, então onde as duas existem a mais
## detalhada aparece por cima; as trocas dos objetos usam pontilhado (ver shaders/impostor.gdshader).

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
var _materials: Dictionary = {}  # id do objeto -> ShaderMaterial (e &"cluster")
var _frames: Dictionary = {}     # id do objeto -> {size, bottom}
var _terrain_mat: Material


func setup(manager: ChunkManager, who: Node3D) -> void:
	chunks = manager
	target = who
	name = "FarWorld"
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_quad.center_offset = Vector3(0, 0.5, 0)
	_terrain_mat = MaterialFactory.vertex_color(MaterialFactory.Hull.NONE)
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
	# A neblina acompanha a distância de renderização nova.
	var we := get_tree().get_first_node_in_group(&"world_environment") as WorldEnvironment
	if we == null:
		for n in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			we = n as WorldEnvironment
	if we != null and we.environment != null and enabled():
		we.environment.fog_depth_begin = _cfg.get("fog_begin", 260.0)
		we.environment.fog_depth_end = _cfg.get("fog_end", 780.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.far = maxf(cam.far, float(_cfg.get("far_radius", 820.0)) + 200.0)


func enabled() -> bool:
	return bool(_cfg.get("enabled", true))


func _load_impostors() -> void:
	var info := {}
	var f := FileAccess.open(IMPOSTOR_DIR + "impostors.json", FileAccess.READ)
	if f != null:
		info = JSON.parse_string(f.get_as_text())
	for d in Database.resource_nodes:
		var key := String(d.mesh_id)
		var tex := load(IMPOSTOR_DIR + key + ".png") as Texture2D
		if tex == null:
			continue
		var fr: Dictionary = info.get(key, {})
		if fr.is_empty():
			var lf := LodFrame.of(PrimitiveMeshes.get_mesh(d.mesh_id))
			fr = {"size": lf.size, "bottom": lf.bottom}
		_frames[d.id] = fr
		_materials[d.id] = _impostor_material(tex, 0, false)
	var cluster := load(IMPOSTOR_DIR + "cluster.png") as Texture2D
	if cluster != null:
		_materials[&"cluster"] = _impostor_material(cluster, 1, true)


func _impostor_material(tex: Texture2D, tier: int, instance_color: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/impostor.gdshader")
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tier", tier)
	m.set_shader_parameter("use_instance_color", instance_color)
	return m


func _process(_delta: float) -> void:
	if target == null or not enabled():
		return
	var p := Vector2(target.global_position.x, target.global_position.z)
	if p.distance_to(_last_center) > float(_cfg.get("mid_tile", 64)) * 0.5:
		_last_center = p
		_refresh(p)
	_start_tasks()
	_finalize()


## Quais blocos devem existir: médios até mid_radius, longes até far_radius. Os que ficam inteiros
## dentro da faixa mais detalhada não são feitos (lá eles nunca apareceriam).
func _wanted(p: Vector2) -> Array:
	var out: Array = []
	for far in [false, true]:
		var tile: int = _cfg.get("far_tile", 128) if far else _cfg.get("mid_tile", 64)
		var outer: float = _cfg.get("far_radius", 820.0) if far else _cfg.get("mid_radius", 400.0)
		var inner: float = float(_cfg.get("far_fade_start", 300.0)) if far else float(_cfg.get("near_fade_start", 130.0))
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
		var tile: int = _cfg.get("far_tile", 128) if key[0] else _cfg.get("mid_tile", 64)
		var outer: float = _cfg.get("far_radius", 820.0) if key[0] else _cfg.get("mid_radius", 400.0)
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
		var tile: int = _cfg.get("far_tile", 128) if far else _cfg.get("mid_tile", 64)
		var params := {
			"seed": chunks.world_seed, "origin": Vector2i(t.x * tile, t.y * tile), "size": tile,
			"step": _cfg.get("far_step", 8) if far else _cfg.get("mid_step", 4),
			"chunk_size": chunks.chunk_size, "defs": _defs.duplicate(true),
			"lower": _cfg.get("far_lower", 2.5) if far else _cfg.get("mid_lower", 0.6),
			"skirt": 10.0 if far else 5.0, "far": far,
			"cluster_cell": _cfg.get("cluster_cell", 16.0), "tree_index": _tree_index,
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
	arrays[Mesh.ARRAY_INDEX] = t["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	if data["far"]:
		_add_blobs(node, data["blobs"])
	else:
		_add_impostors(node, data["objects"])
	return node


## Faixa média: uma MultiMesh por tipo de objeto, pulando os que já foram coletados.
func _add_impostors(node: Node3D, objects: Array) -> void:
	var by_type := impostor_transforms(objects)
	for id: StringName in by_type:
		var xfs: Array = by_type[id]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _quad
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Impostors_%s" % id
		mmi.multimesh = mm
		mmi.material_override = _materials[id]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.set_meta(&"transforms", xfs)  # cópia das posições (o servidor sem tela não as guarda)
		node.add_child(mmi)


## Onde fica cada imagem (por tipo de objeto), no espaço do bloco: a base do quadrado no pé do
## objeto e o tamanho igual ao enquadramento usado ao gerar o PNG.
func impostor_transforms(objects: Array) -> Dictionary:
	var by_type: Dictionary = {}
	for o: Dictionary in objects:
		var id: StringName = _def_ids[o["index"]]
		if not _materials.has(id):
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


## Faixa longe: uma mancha por grupo de árvores, em cor sólida (varia um pouco de uma para outra).
func _add_blobs(node: Node3D, blobs: Array) -> void:
	if blobs.is_empty() or not _materials.has(&"cluster"):
		return
	# Cor média das copas no tree.png (ver tools/impostor_color.gd), para a mancha ter o tom das árvores.
	var base := Config.to_color(_cfg.get("cluster_color"), Color(0.02, 0.30, 0.03))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad
	mm.instance_count = blobs.size()
	for i in blobs.size():
		var b: Dictionary = blobs[i]
		var sc: float = b["scale"]
		var count: int = b["count"]
		var w := maxf(3.6 * sc, 2.0 * float(b["spread"]) + 3.2 * sc)
		var h := 4.4 * sc * (1.0 + 0.08 * minf(count - 1, 4))
		var pos := Vector3(b["x"], float(b["y"]) + 1.5 * sc - 0.08 * h, b["z"])
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(w, h, w)), pos))
		mm.set_instance_color(i, base.lightened(float(b["tint"]) * 0.05))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Clusters"
	mmi.multimesh = mm
	mmi.material_override = _materials[&"cluster"]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mmi)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	var tile: int = _cfg.get("mid_tile", 64)
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


## Usado por testes: espera as tarefas pendentes.
func flush() -> void:
	for key: Array in _tasks.keys():
		WorkerThreadPool.wait_for_task_completion(_tasks[key])
