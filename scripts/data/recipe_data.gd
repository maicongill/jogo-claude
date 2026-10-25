class_name RecipeData
extends Resource
## Receita de crafting livre (feita direto pelo inventário).

@export var id: StringName
@export var output: ItemData
@export var output_count := 1
@export var inputs: Array[ItemData] = []
@export var input_counts: Array[int] = []
