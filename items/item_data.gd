class_name ItemData
extends GameData
## Definition of an item type. Important resources are *physical*: they
## exist in the world as `carry_scene` (a Carryable) and only become a
## number once delivered into storage.

## The physical object (a Carryable) that represents one unit in the world.
@export var carry_scene: PackedScene
## Heavy loads block sprinting, dodging and attacking while carried.
@export var heavy := false
## Carrier speed multiplier while holding one.
@export var carry_speed := 0.9
## Can this item be put into stockpiles/warehouses?
@export var storable := true
## Mesh shown stacked on a stockpile for each stored unit.
@export var stack_visual: PackedScene
@export var stack_visual_scale := 1.0
## Height of one stacked unit (for piling visuals).
@export var stack_height := 0.4
