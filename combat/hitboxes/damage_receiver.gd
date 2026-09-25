class_name DamageReceiver
extends Area3D
## Hurtbox. The single entry point for damage into an entity.
##
## Flow: Hitbox -> receive(event) -> about_to_take_damage (listeners may
## mitigate: block, armor, resistances) -> HealthComponent.take ->
## damage_taken. Works for anything damageable: characters, trees, doors.

signal about_to_take_damage(event: DamageEvent)
signal damage_taken(event: DamageEvent)

const LAYER := 1 << 2  # physics layer 3 "hurtboxes"

@export var health: HealthComponent
## Hitboxes never damage receivers of the same faction.
@export var faction: StringName = &"neutral"
## Damage multiplier per DamageEvent.Type (missing = 1.0). Resistances and
## weaknesses are data, not code.
@export var type_multipliers: Dictionary = {}
## If non-empty, only attackers of these factions can damage this receiver
## (e.g. only settlers can chop trees).
@export var allowed_attacker_factions: Array[StringName] = []

var invulnerable := false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_be_hit_by(attacker_faction: StringName) -> bool:
	if invulnerable or (health and not health.is_alive()):
		return false
	if not allowed_attacker_factions.is_empty():
		return attacker_faction in allowed_attacker_factions
	return attacker_faction == &"neutral" or attacker_faction != faction


func receive(event: DamageEvent) -> void:
	if invulnerable or (health and not health.is_alive()):
		return
	event.target = owner if owner else get_parent()
	event.amount *= float(type_multipliers.get(event.damage_type, 1.0))
	about_to_take_damage.emit(event)
	if health:
		health.take(event.amount)
	damage_taken.emit(event)
	EventBus.damage_applied.emit(event)
