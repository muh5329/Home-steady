class_name JobDefinition
extends GameData
## A settlement profession as data. Every job runs the same worker states:
##   find work -> go to work target -> work -> collect produce -> deliver.
## What differs is which resource nodes count as work, which items are
## produce, and how the work looks and feels.

## Produce this job gathers and hauls, in priority order.
@export var gather_items: Array[StringName] = []
## How far from home the worker looks for work.
@export var work_radius := 45.0
## Also works on construction sites whose materials are complete.
@export var builds := false

@export_group("Work swing")
@export var work_animation: StringName = &"1H_Melee_Attack_Chop"
@export var work_speed := 1.0
## Seconds into the (unscaled) clip where the tool connects.
@export var work_impact_time := 0.6
@export var work_amount := 10.0
## Tags on each work hit (resource nodes multiply damage per tag).
@export var work_tags: PackedStringArray = []
## Shown on the nameplate while working ("Chopping", "Mining"...).
@export var work_verb := "Working"

@export_group("Look")
## Model part (on the rig) to show as this job's tool, if the rig has one.
@export var tool_part: StringName = &""
## Otherwise a tool scene attached to the right hand.
@export var tool_scene: PackedScene


func gathers(item_id: StringName) -> bool:
	return item_id in gather_items
