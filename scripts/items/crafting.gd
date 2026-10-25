class_name Crafting
extends RefCounted
## Regras do crafting livre (feito direto pelo inventário).


static func can_craft(inv: Inventory, recipe: RecipeData) -> bool:
	return inv.has_items(recipe.inputs, recipe.input_counts)


## Consome os ingredientes e entrega o resultado. Devolve false se faltar algo ou não houver espaço.
static func craft(inv: Inventory, recipe: RecipeData) -> bool:
	if not can_craft(inv, recipe):
		return false
	# Testa o espaço com os ingredientes já removidos (eles liberam espaços).
	var snapshot: Array[ItemStack] = []
	for s in inv.slots:
		snapshot.append(s.duplicate_stack() if s != null else null)
	for i in recipe.inputs.size():
		inv.remove(recipe.inputs[i], recipe.input_counts[i])
	if not inv.can_add(recipe.output, recipe.output_count):
		inv.slots.assign(snapshot)
		inv.changed.emit()
		return false
	inv.add(recipe.output, recipe.output_count)
	EventBus.item_crafted.emit(recipe.output)
	return true
