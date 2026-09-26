class_name CharacterLoadout
extends Node
## Applies a CharacterClassData to a character: body model, stats, weapon,
## abilities. Works at startup and at runtime (loading a save, promoting a
## settler to a companion class), so every character uses one code path.

signal class_applied(character_class: CharacterClassData)

@export var model_holder: Node3D
@export var animator: CharacterAnimator
@export var motor: CharacterMotor
@export var health: HealthComponent
@export var combat: CombatController
@export var carry: CarryComponent
@export var equipment: EquipmentController
@export var abilities: AbilityController
@export var status_effects: StatusEffectComponent

var character_class: CharacterClassData
var model_root: Node3D

var _base_speeds := Vector3.ZERO  # walk, run, sprint before class multipliers


func apply(c: CharacterClassData) -> void:
	if _base_speeds == Vector3.ZERO:
		_base_speeds = Vector3(motor.walk_speed, motor.run_speed, motor.sprint_speed)
	var first := character_class == null
	character_class = c
	if not first:
		carry.discard_carried()
	# Body.
	if model_root:
		model_holder.remove_child(model_root)
		model_root.queue_free()
	model_root = c.model.instantiate()
	model_holder.add_child(model_root)
	model_holder.scale = Vector3.ONE * c.model_scale
	ModelUtils.set_parts_visible(model_root, c.hidden_parts, false)
	animator.set_model(model_root)
	CarryPoseModifier.install(animator, carry)
	if status_effects:
		status_effects.clear()
		status_effects.model = model_root
	# Stats.
	var ratio := health.ratio() if not first else 1.0
	health.max_health = c.max_health
	health.set_current(c.max_health * ratio)
	combat.max_poise = c.max_poise
	combat.poise = c.max_poise
	combat.receiver.damage_multiplier = c.damage_taken_multiplier
	motor.walk_speed = _base_speeds.x * c.move_speed_multiplier
	motor.run_speed = _base_speeds.y * c.move_speed_multiplier
	motor.sprint_speed = _base_speeds.z * c.move_speed_multiplier
	# Gear and abilities.
	equipment.set_model(model_root)
	equipment.base_damage_multiplier = c.damage_multiplier
	equipment.equip(c.starting_weapon)
	if abilities:
		abilities.set_abilities(c.abilities)
	class_applied.emit(c)
