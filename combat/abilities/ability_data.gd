class_name AbilityData
extends GameData
## A cooldown-gated special move (Shield Bash, Volley, Frost Nova, Raise
## Dead). Its effect is an AttackData (melee areas, projectiles, status
## effects come from the combat system) or a summon.

@export var attack: AttackData
@export var cooldown := 8.0
## Only usable at or below this fraction of health (boss phases).
@export_range(0.0, 1.0) var use_below_health := 1.0

@export_group("Summon")
## Raises these monsters instead of attacking.
@export var summon: EnemyDefinition
@export var summon_count := 2
## Never more than this many of the caster's summons alive at once.
@export var summon_max_alive := 4
@export var summon_animation: StringName = &"Spellcast_Summon"
## Seconds into the cast when they appear (interrupting the cast cancels).
@export var summon_delay := 1.0
@export var summon_radius := 3.0


## How close an AI user should be to its target before using this:
## projectiles reach far, areas only as wide as their radius.
func ai_use_range() -> float:
	if summon:
		return 20.0
	if attack == null:
		return 0.0
	if attack.projectile:
		return minf(attack.projectile.max_range * 0.6, 16.0)
	if attack.hitbox_radius > 0.0:
		return attack.hitbox_radius * 0.8
	return 2.2
