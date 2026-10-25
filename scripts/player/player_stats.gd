class_name PlayerStats
extends Node
## Vida e fome do jogador. A fome zerada causa dano; não há opção de desativá-la.

@export var max_health := 100.0
@export var max_hunger := 100.0
## Segundos para a fome ir de 100 a 0.
@export var seconds_to_starve := 600.0
@export var starve_damage := 3.0
@export var starve_interval := 2.0
@export var regen_per_second := 1.0

var health := 100.0
var hunger := 100.0
var dead := false
## Enquanto > 0 o jogador não recebe dano (esquiva).
var invulnerable_time := 0.0

var _starve_timer := 0.0


func _ready() -> void:
	health = max_health
	hunger = max_hunger
	_emit()


func _process(delta: float) -> void:
	if dead:
		return
	invulnerable_time = maxf(invulnerable_time - delta, 0.0)
	hunger = maxf(hunger - max_hunger / seconds_to_starve * delta, 0.0)
	if hunger <= 0.0:
		_starve_timer += delta
		if _starve_timer >= starve_interval:
			_starve_timer = 0.0
			hurt(starve_damage, &"fome", true)
			EventBus.message.emit("Você está com fome!")
	elif hunger > 40.0 and health < max_health:
		health = minf(health + regen_per_second * delta, max_health)
	_emit()


func _emit() -> void:
	EventBus.player_health_changed.emit(health, max_health)
	EventBus.player_hunger_changed.emit(hunger, max_hunger)


func hurt(amount: float, _source: StringName = &"", ignore_invulnerability := false) -> bool:
	if dead or amount <= 0.0:
		return false
	if invulnerable_time > 0.0 and not ignore_invulnerability:
		return false
	health = maxf(health - amount, 0.0)
	_emit()
	EventBus.player_hurt.emit(amount)
	if health <= 0.0:
		dead = true
		EventBus.player_died.emit()
	return true


func heal(amount: float) -> void:
	health = minf(health + amount, max_health)
	_emit()


func eat(food_value: float) -> void:
	hunger = minf(hunger + food_value, max_hunger)
	_emit()


func revive(hunger_value := 50.0) -> void:
	dead = false
	health = max_health
	hunger = hunger_value
	invulnerable_time = 2.0
	_starve_timer = 0.0
	_emit()
