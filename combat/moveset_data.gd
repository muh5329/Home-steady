class_name MovesetData
extends Resource
## The combat actions a weapon (or monster) offers.

## Chained with repeated light-attack input; wraps back to the start.
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData

@export_group("Defense")
@export var can_block := true
## Fraction of frontal damage negated while blocking.
@export_range(0.0, 1.0) var block_reduction: float = 0.8
@export var block_start_animation: StringName = &"Block"
@export var block_loop_animation: StringName = &"Blocking"
@export var block_hit_animation: StringName = &"Block_Hit"
