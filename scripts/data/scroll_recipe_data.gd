class_name ScrollRecipeData
extends Resource
## Combinação fixa de itens que a mesa de magia transforma em um pergaminho.

@export var id: StringName
@export var scroll: ItemData
@export var inputs: Array[ItemData] = []
@export var input_counts: Array[int] = []
