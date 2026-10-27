class_name MagicData
extends Resource
## Definição de uma magia. O efeito em si é escolhido por `effect` (ver PlayerMagic).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## "fire", "wind", "earth" (e outros nos próximos marcos).
@export var element: StringName
@export var mana_cost := 20.0
@export var cooldown := 0.8
## "fireball", "wind_gust", "earth_wall", "tame".
@export var effect: StringName
@export var damage := 0.0
@export var radius := 2.5
@export var range := 25.0
@export var color := Color.WHITE
## Magias iniciais não precisam de pergaminho.
@export var learned_by_default := false
## Tecla que seleciona a magia (só para mostrar na barra; o mapa de teclas fica no projeto).
@export var key := ""
