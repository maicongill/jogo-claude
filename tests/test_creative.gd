extends Node
## Modo criativo: botão no Esc troca de modo; painel com todos os itens (pegar quantidade, pilha
## cheia, Shift = direto no inventário, soltar = jogar fora); construir não gasta material; o modo
## fica salvo.

var failures := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var p: Player = main.player
	while p.frozen:
		await get_tree().process_frame
	check(not Game.creative, "começa no modo sobrevivência")
	var opts: OptionsMenu = main.hud.options
	var mode_btn: Button = opts._box.get_node("ModeButton")
	check(mode_btn.text.begins_with("Modo: Sobrevivência"), "botão do Esc mostra o modo atual")
	mode_btn.pressed.emit()
	check(Game.creative and mode_btn.text.begins_with("Modo: Criativo"), "o botão troca para o criativo")

	var inv_panel: InventoryPanel = main.hud._inventory_panel
	check(inv_panel._creative.visible and not inv_panel._crafting.visible, "no criativo o inventário mostra todos os itens no lugar do crafting")
	check(inv_panel._creative.item_count() == Database.items.size(), "todos os %d itens do jogo estão no painel" % Database.items.size())

	# Pegar itens.
	var stone := Database.item(&"stone")
	inv_panel.toggle()
	inv_panel._creative.quantity.value = 10
	inv_panel._on_creative_item(stone, MOUSE_BUTTON_LEFT, false)
	check(inv_panel._cursor != null and inv_panel._cursor.item == stone and inv_panel._cursor.count == 10, "clique pega a quantidade escolhida (10)")
	inv_panel._on_creative_item(stone, MOUSE_BUTTON_LEFT, false)
	check(inv_panel._cursor.count == 20, "clicar de novo no mesmo item soma (20)")
	inv_panel._on_slot_pressed(20, MOUSE_BUTTON_LEFT)
	check(p.inventory.get_stack(20) != null and p.inventory.get_stack(20).count == 20, "solta as 20 pedras no inventário")
	inv_panel._on_creative_item(Database.item(&"wood"), MOUSE_BUTTON_RIGHT, false)
	check(inv_panel._cursor != null and inv_panel._cursor.count == Database.item(&"wood").stack_max, "botão direito pega uma pilha cheia")
	inv_panel._on_creative_item(stone, MOUSE_BUTTON_LEFT, false)
	check(inv_panel._cursor == null, "soltar no painel joga fora o que estava no cursor")
	var before := p.inventory.count_of(Database.item(&"arrow"))
	inv_panel._creative.quantity.value = 32
	inv_panel._on_creative_item(Database.item(&"arrow"), MOUSE_BUTTON_LEFT, true)
	check(p.inventory.count_of(Database.item(&"arrow")) == before + 32, "Shift + clique manda 32 flechas direto para o inventário")
	inv_panel._on_creative_item(Database.item(&"wooden_sword"), MOUSE_BUTTON_RIGHT, false)
	check(inv_panel._cursor != null and inv_panel._cursor.count == 1, "itens que não empilham vêm 1 por vez")
	inv_panel._cursor = null
	inv_panel.toggle()

	# Construir sem gastar.
	p.inventory.clear()
	var b: BuildSystem = main.build
	var h: float = main.chunks.height_at(16, 16)
	var t := b.compute_target(Vector3(16, h, 16), 0)
	check(t["valid"], "no criativo dá para construir sem nenhum material")
	var fl := b.place(b.pieces_data[0], t)
	check(fl != null and p.inventory.count_of(Database.item(&"wood")) == 0, "construir não gasta nada")
	check(b._cost_text(b.pieces_data[0]).contains("grátis"), "o custo aparece como grátis")
	b.demolish(fl)
	check(p.inventory.count_of(Database.item(&"wood")) == 0, "demolir no criativo não devolve material")

	# Volta à sobrevivência: construir volta a custar.
	mode_btn.pressed.emit()
	check(not Game.creative and inv_panel._crafting.visible and not inv_panel._creative.visible, "de volta à sobrevivência: crafting de volta")
	var t2 := b.compute_target(Vector3(16, h, 16), 0)
	check(not t2["valid"], "na sobrevivência, sem material não constrói")

	# O modo é salvo.
	Game.set_creative(true)
	var d := SaveSystem.serialize(main)
	check(d.get("creative", false) == true, "o save guarda o modo")
	Game.set_creative(false)
	SaveSystem.apply(main, d)
	check(Game.creative, "carregar o save volta ao modo salvo")
	var w := Worlds.create("Teste criativo", "1")
	Game.current_world = w["id"]
	Game.creative = false
	Game.set_creative(true)
	check(Worlds.get_info(w["id"]).get("creative", false), "o modo fica registrado no mundo (para o menu)")
	Worlds.delete(w["id"])
	Game.current_world = ""
	Game.creative = false
	print("FALHAS: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
