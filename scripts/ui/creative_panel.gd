class_name CreativePanel
extends VBoxContainer
## Modo criativo: todos os itens do jogo, ao lado do inventário (no lugar do crafting).
## Clique pega a quantidade escolhida (clicar de novo no mesmo item soma), botão direito pega uma
## pilha cheia, Shift + clique manda direto para o inventário. Soltar um item aqui joga fora.

signal item_clicked(item: ItemData, button: int, shift: bool)
signal trash_requested

const OFFSET := 2000

var quantity: SpinBox
var _items: Array[ItemData] = []
var _slots: Array[SlotUI] = []


func setup() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Todos os itens (criativo)"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)
	var row := HBoxContainer.new()
	add_child(row)
	var ql := Label.new()
	ql.text = "Quantidade:"
	row.add_child(ql)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 64
	quantity.value = 1
	quantity.custom_minimum_size.x = 90
	row.add_child(quantity)
	for preset in [1, 16, 64]:
		var b := Button.new()
		b.text = str(preset)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: quantity.value = preset)
		row.add_child(b)
	var help := Label.new()
	help.text = "Clique: pega · Direito: pilha cheia\nShift + clique: vai para o inventário\nSolte um item aqui para jogar fora"
	help.modulate = Color(1, 1, 1, 0.7)
	help.add_theme_font_size_override("font_size", 13)
	add_child(help)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	_items.clear()
	for it: ItemData in Database.items.values():
		_items.append(it)
	_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.kind != b.kind:
			return a.kind < b.kind
		return a.display_name < b.display_name)
	for i in _items.size():
		var slot := SlotUI.new()
		slot.index = OFFSET + i
		slot.set_stack(ItemStack.new(_items[i], 1))
		slot.pressed.connect(_on_pressed)
		grid.add_child(slot)
		_slots.append(slot)


func _on_pressed(index: int, button: int) -> void:
	var i := index - OFFSET
	if i < 0 or i >= _items.size():
		return
	item_clicked.emit(_items[i], button, Input.is_key_pressed(KEY_SHIFT))


func item_at(i: int) -> ItemData:
	return _items[i]


func item_count() -> int:
	return _items.size()
