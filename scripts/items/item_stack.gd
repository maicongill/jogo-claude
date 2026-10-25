class_name ItemStack
extends RefCounted
## Uma pilha de itens em um espaço do inventário.

var item: ItemData
var count := 1
## Só usada em itens com durabilidade.
var durability := 0


func _init(item_data: ItemData = null, amount := 1) -> void:
	item = item_data
	count = amount
	if item_data != null:
		durability = item_data.max_durability


func duplicate_stack() -> ItemStack:
	var s := ItemStack.new(item, count)
	s.durability = durability
	return s
