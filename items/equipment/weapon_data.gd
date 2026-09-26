class_name WeaponData
extends ItemData
## A wieldable weapon: how it fights (moveset) and how it looks.

@export var moveset: MovesetData
## Multiplies all the wielder's damage.
@export var damage_multiplier := 1.0
## Rig meshes to show when equipped (KayKit rigs carry their weapons).
@export var rig_parts: PackedStringArray = []
## Or a scene attached to the right hand.
@export var hand_scene: PackedScene
## Ranged/magic weapons aim further with auto-aim.
@export var aim_range := 3.2
