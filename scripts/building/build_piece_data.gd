class_name BuildPieceData
extends Resource
## Definição de uma peça de construção (custo e propriedades). A geometria fica em PieceGeometry.

@export var id: StringName
@export var display_name := ""
@export var cost_items: Array[ItemData] = []
@export var cost_counts: Array[int] = []
@export var flammable := true
## Vida usada quando a peça pega fogo.
@export var fire_hp := 40.0
