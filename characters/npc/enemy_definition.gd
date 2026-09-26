class_name EnemyDefinition
extends GameData
## Everything that makes one monster type different from another. All
## monsters share one scene, controller and AI states; this resource is
## the only per-monster content.

@export var model: PackedScene
@export var model_scale := 0.75
@export var hidden_parts: PackedStringArray = []
@export var faction: StringName = &"monsters"
@export var right_hand_item: PackedScene
@export var left_hand_item: PackedScene
@export var sounds: CombatSounds

@export_group("Stats")
@export var max_health := 60.0
@export var max_poise := 20.0
@export var walk_speed := 1.8
@export var run_speed := 3.8
@export var moveset: MovesetData
@export var stagger_duration := 0.9
@export var flinch_duration := 0.35

@export_group("Behaviour")
@export var aggro_range := 11.0
@export var attack_range := 1.9
## Gives up the chase when this far from its home position.
@export var leash_range := 28.0
## Pause between attack strings, randomized in [x, y].
@export var attack_cooldown := Vector2(0.7, 1.6)
## How many light attacks it chains in one string (random 1..max).
@export var max_combo := 2
## After being hit, ignores its leash for this long (can't be kited to death).
@export var provoked_seconds := 6.0
## AI state used in range: "Attack" (melee strings) or "Shoot" (ranged).
@export var attack_state: StringName = &"Attack"
## Played when raised by an EnemySpawn (e.g. clawing out of the floor).
@export var spawn_animation: StringName = &""
@export var spawn_animation_speed := 1.0
