class_name StatusEffectData
extends GameData
## A timed condition applied by a hit (chilled, burning, blessed...).

@export var duration := 3.0
## Movement speed multiplier while active.
@export var speed_multiplier := 1.0
## Overlay tint on the affected character's meshes.
@export var tint := Color(0, 0, 0, 0)
