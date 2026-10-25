class_name ResourceNodeData
extends Resource
## Recurso coletável do mundo (árvore, pedra, arbusto...).

@export var id: StringName
@export var display_name := ""
## Forma procedural usada ("tree", "rock", "bush").
@export var mesh_id: StringName
@export var drop_item: ItemData
@export var drop_min := 1
@export var drop_max := 1
@export var bonus_item: ItemData
@export var bonus_chance := 0.0
## Vida do recurso, em pontos de dano.
@export var hits := 5.0
## Ferramenta que coleta mais rápido/melhor ("axe", "pickaxe"). Vazio = qualquer uma.
@export var tool_kind: StringName
## Nível mínimo da ferramenta para causar dano. 0 = nenhum.
@export var min_tool_level := 0
## Dano causado com as mãos (0 = precisa de ferramenta).
@export var hand_damage := 1.0
## 0 = some para sempre. > 0 = regenera depois desse tempo (segundos).
@export var respawn_time := 0.0
@export var flammable := false

@export_group("Distribuição")
## Probabilidade de aparecer em cada célula de 4 x 4 m.
@export_range(0.0, 1.0) var density_plain := 0.0
@export_range(0.0, 1.0) var density_forest := 0.0
@export var radius := 0.5
@export var height := 2.0
@export var scale_min := 0.9
@export var scale_max := 1.2
