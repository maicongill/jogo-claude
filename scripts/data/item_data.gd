class_name ItemData
extends Resource
## Definição de um item. Para criar conteúdo novo, basta um novo .tres em resources/items/.

enum Kind { RESOURCE, TOOL, WEAPON, FOOD, PLACEABLE, SEED, AMMO, SADDLE }

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var kind: Kind = Kind.RESOURCE
@export var stack_max := 64
## Cor usada como ícone provisório na interface.
@export var color := Color.WHITE

@export_group("Ferramenta / arma")
## "axe", "pickaxe", "sword" ou "bow".
@export var tool_kind: StringName
@export var tool_level := 0
## Dano causado em recursos por golpe.
@export var tool_power := 1.0
## Dano causado em inimigos.
@export var damage := 0.0
## 0 = não quebra.
@export var max_durability := 0

@export_group("Uso")
@export var food_value := 0.0
## Para PLACEABLE e SEED: o que é colocado no mundo ("sapling", "bed", "stable", "flower_pot").
@export var place_id: StringName


func is_stackable() -> bool:
	return max_durability == 0 and stack_max > 1
