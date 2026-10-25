class_name Inventory
extends RefCounted
## Inventário em grade: os 9 primeiros espaços são a hotbar.

signal changed
signal item_broken(item: ItemData)

const HOTBAR_SIZE := 9

var slots: Array[ItemStack] = []


func _init(size := 36) -> void:
	slots.resize(size)


func size() -> int:
	return slots.size()


func get_stack(i: int) -> ItemStack:
	return slots[i]


func set_stack(i: int, stack: ItemStack) -> void:
	slots[i] = stack
	changed.emit()


## Guarda o item. Devolve quantas unidades NÃO couberam.
func add(item: ItemData, count := 1) -> int:
	var left := count
	if item.is_stackable():
		for s in slots:
			if left <= 0:
				break
			if s != null and s.item.id == item.id and s.count < item.stack_max:
				var moved := mini(item.stack_max - s.count, left)
				s.count += moved
				left -= moved
	for i in slots.size():
		if left <= 0:
			break
		if slots[i] == null:
			var moved := mini(item.stack_max if item.is_stackable() else 1, left)
			slots[i] = ItemStack.new(item, moved)
			left -= moved
	changed.emit()
	return left


## Verdadeiro se todas as unidades coubessem no inventário agora.
func can_add(item: ItemData, count := 1) -> bool:
	var room := 0
	for s in slots:
		if s == null:
			room += item.stack_max if item.is_stackable() else 1
		elif item.is_stackable() and s.item.id == item.id:
			room += item.stack_max - s.count
	return room >= count


func count_of(item: ItemData) -> int:
	var total := 0
	for s in slots:
		if s != null and s.item.id == item.id:
			total += s.count
	return total


func has_items(items: Array[ItemData], counts: Array[int]) -> bool:
	for i in items.size():
		if count_of(items[i]) < counts[i]:
			return false
	return true


func remove(item: ItemData, count := 1) -> bool:
	if count_of(item) < count:
		return false
	var left := count
	for i in range(slots.size() - 1, -1, -1):
		var s := slots[i]
		if s == null or s.item.id != item.id:
			continue
		var taken := mini(s.count, left)
		s.count -= taken
		left -= taken
		if s.count <= 0:
			slots[i] = null
		if left <= 0:
			break
	changed.emit()
	return true


func remove_from_slot(i: int, count := 1) -> void:
	var s := slots[i]
	if s == null:
		return
	s.count -= count
	if s.count <= 0:
		slots[i] = null
	changed.emit()


## Gasta durabilidade do item no espaço i. Quebra (some) ao chegar a zero.
func use_durability(i: int, amount := 1) -> void:
	var s := slots[i]
	if s == null or s.item.max_durability <= 0:
		return
	s.durability -= amount
	if s.durability <= 0:
		var broken := s.item
		slots[i] = null
		item_broken.emit(broken)
	changed.emit()


## Esvazia o inventário e devolve o que havia (usado na morte).
func clear() -> Array[ItemStack]:
	var old: Array[ItemStack] = []
	for i in slots.size():
		if slots[i] != null:
			old.append(slots[i])
			slots[i] = null
	changed.emit()
	return old
