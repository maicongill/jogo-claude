extends Node
## O arquivo config/game_config.json é a fonte de todos os parâmetros: editar o arquivo muda o jogo.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	while main.player.frozen:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var p: Player = main.player
	check(Config.data.has("player") and Config.data.has("items") and Config.data.has("recipes"), "o arquivo carrega parâmetros e conteúdo")
	check(p.walk_speed == Config.f("player.walk_speed") and p.stats.max_health == Config.f("survival.max_health"), "o jogador usa os valores do arquivo")
	var axe := Database.item(&"wooden_axe")
	var recipe: RecipeData = null
	for r in Database.recipes:
		if r.id == &"wooden_axe":
			recipe = r
	check(recipe != null and recipe.input_counts == [3], "receita do machado lida do arquivo (3 madeiras)")

	# Edita uma cópia do arquivo como o usuário faria
	var original_path := Config.path
	var cfg: Dictionary = Config.data.duplicate(true)
	cfg["player"]["walk_speed"] = 3.3
	cfg["survival"]["max_health"] = 150.0
	cfg["recipes"]["wooden_axe"]["inputs"]["wood"] = 5
	cfg["items"]["wooden_axe"]["max_durability"] = 99
	cfg["items"]["dragon_scale"] = {"name": "Escama de dragão", "kind": "RESOURCE", "stack_max": 10, "color": [0.9, 0.2, 0.2]}
	cfg["recipes"]["dragon_axe"] = {"output": "wooden_axe", "count": 1, "inputs": {"dragon_scale": 2}}
	cfg["visual"]["outline_thickness"] = 0.05
	cfg["magics"]["fireball"]["mana_cost"] = 7.0
	var tmp := "user://test_config.json"
	FileAccess.open(tmp, FileAccess.WRITE).store_string(JSON.stringify(cfg))
	Config.path = tmp
	check(Config.reload(), "F10: recarrega o arquivo editado")
	check(p.walk_speed == 3.3, "a velocidade do jogador mudou ao vivo (%.1f)" % p.walk_speed)
	check(p.stats.max_health == 150.0, "a vida máxima mudou")
	check(Database.item(&"wooden_axe") == axe and axe.max_durability == 99, "o item é o mesmo objeto, com a durabilidade nova")
	check(recipe.input_counts == [5], "a receita mudou (5 madeiras)")
	check(Database.item(&"dragon_scale") != null and Database.recipes.size() == cfg["recipes"].size(), "item e receita novos criados só pelo arquivo")
	check(Database.spell(&"fireball").mana_cost == 7.0, "custo de mana da magia mudou")
	check(Visuals.outline_thickness == 0.05, "o visual mudou")
	# JSON inválido: mantém o que estava
	FileAccess.open(tmp, FileAccess.WRITE).store_string("{ isto nao e json ")
	check(not Config.reload() and p.walk_speed == 3.3, "arquivo com erro é recusado e os valores anteriores ficam")
	Config.path = original_path
	Config.reload()
	check(p.walk_speed == Config.f("player.walk_speed") and p.walk_speed != 3.3, "voltou ao arquivo original")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
