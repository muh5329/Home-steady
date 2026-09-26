class_name AbilityData
extends GameData
## A cooldown-gated special move (Shield Bash, Volley, Frost Nova).
## Its effect is an AttackData, so melee areas, projectiles and status
## effects all come for free from the combat system.

@export var attack: AttackData
@export var cooldown := 8.0
