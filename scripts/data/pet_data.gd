class_name PetData
extends Resource
## Definição de uma espécie de pet. Preferências (comida e bioma) aceleram a confiança.

@export var id: StringName
@export var display_name := ""
@export var favorite_food: ItemData
## "forest" ou "plain".
@export var favorite_biome: StringName = &"forest"
## Confiança necessária para os níveis 1 (tolera), 2 (segue) e 3 (aceita sela e montaria). PROPOSTA.
@export var trust_thresholds: Array[int] = [30, 60, 100]
@export var max_health := 60.0
@export var max_stamina := 100.0
@export var fly_speed := 9.0
@export var fast_speed := 16.0
## Estamina gasta por segundo voando rápido, e recuperada por segundo nas outras situações.
@export var stamina_drain := 22.0
@export var stamina_regen := 14.0
