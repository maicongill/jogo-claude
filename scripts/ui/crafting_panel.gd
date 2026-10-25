class_name CraftingPanel
extends VBoxContainer
## Lista de receitas do crafting livre, ao lado do inventário.

var inventory: Inventory
var _rows: Array[Dictionary] = []


func setup(inv: Inventory) -> void:
	inventory = inv
	add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "Crafting"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for r in Database.recipes:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(290, 44)
		button.pressed.connect(_on_craft.bind(r))
		list.add_child(button)
		_rows.append({"recipe": r, "button": button})
	inventory.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for row in _rows:
		var r: RecipeData = row["recipe"]
		var b: Button = row["button"]
		var out := r.output.display_name
		if r.output_count > 1:
			out += " x%d" % r.output_count
		var needs: PackedStringArray = []
		for i in r.inputs.size():
			needs.append("%d %s (%d)" % [r.input_counts[i], r.inputs[i].display_name, inventory.count_of(r.inputs[i])])
		b.text = "%s\n  %s" % [out, ", ".join(needs)]
		b.disabled = not Crafting.can_craft(inventory, r)
		b.tooltip_text = r.output.description


func _on_craft(r: RecipeData) -> void:
	if Crafting.craft(inventory, r):
		EventBus.message.emit("Criou %s." % r.output.display_name)
	else:
		EventBus.message.emit("Faltam materiais ou espaço no inventário.")
