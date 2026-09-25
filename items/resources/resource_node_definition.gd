class_name ResourceNodeDefinition
extends GameData
## A gatherable world object (tree, boulder, ore vein). Gathering reuses
## combat: hitting the node with a melee attack wears it down; when
## depleted it drops physical items.

enum DepleteStyle { FALL, CRUMBLE }

@export var model: PackedScene
@export var depleted_model: PackedScene
@export var model_scale := 1.0
@export var depleted_scale := 1.0
@export var collision_radius := 0.5
@export var collision_height := 3.0
## Fade out when it blocks the camera's view of the player (0 = never).
@export var camera_fade_radius := 0.0
@export var camera_fade_height := 3.0

@export_group("Gathering")
@export var max_health := 60.0
@export var yield_item: ItemData
@export var yield_count := 3
## Damage multiplier by attack tag, e.g. {"chop": 2.5} for axes on trees.
@export var tag_multipliers: Dictionary = {}
## Only these attacker factions can gather it (monsters don't chop trees).
@export var gatherer_factions: Array[StringName] = [&"player"]
@export var deplete_style := DepleteStyle.FALL
## Seconds until it regrows/refills; 0 = never.
@export var respawn_seconds := 240.0
@export var hit_sound: AudioStream
@export var prompt := "Chop"
