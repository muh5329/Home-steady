class_name HealthComponent
extends Node
## Tracks hit points. Knows nothing about how damage is produced or what
## death looks like; other components react to its signals.

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(value, 1.0)
		current = minf(current, max_health)

var current: float = -1.0


func _ready() -> void:
	if current < 0.0:
		current = max_health


func is_alive() -> bool:
	return current > 0.0


func ratio() -> float:
	return current / max_health


func take(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	health_changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	health_changed.emit(current, max_health)


## Sets health directly (used by save/load and respawn).
func set_current(value: float) -> void:
	current = clampf(value, 0.0, max_health)
	health_changed.emit(current, max_health)
