class_name AbilityData
extends GameData
## A cooldown-gated special move (Shield Bash, Volley, Frost Nova).
## Its effect is an AttackData, so melee areas, projectiles and status
## effects all come for free from the combat system.

@export var attack: AttackData
@export var cooldown := 8.0


## How close an AI user should be to its target before using this:
## projectiles reach far, areas only as wide as their radius.
func ai_use_range() -> float:
	if attack == null:
		return 0.0
	if attack.projectile:
		return minf(attack.projectile.max_range * 0.6, 16.0)
	if attack.hitbox_radius > 0.0:
		return attack.hitbox_radius * 0.8
	return 2.2
