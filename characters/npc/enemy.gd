class_name Enemy
extends CharacterBody3D
## Generic monster. The EnemyDefinition supplies model, stats, moveset and
## behaviour tuning; this script applies it to the shared components.

const CORPSE_SECONDS := 4.0

@export var definition: EnemyDefinition

@onready var motor: CharacterMotor = $CharacterMotor
@onready var combat: CombatController = $CombatController
@onready var health: HealthComponent = $HealthComponent
@onready var controller: EnemyController = $EnemyController

var _configured := false


func _enter_tree() -> void:
	# Runs before children's _ready, so components see final values.
	if _configured or definition == null:
		return
	_configured = true
	var d := definition
	var model: Node3D = d.model.instantiate()
	$Model.add_child(model)
	$Model.scale = Vector3.ONE * d.model_scale
	ModelUtils.set_parts_visible(model, d.hidden_parts, false)
	if d.right_hand_item:
		ModelUtils.attach_to_bone(model, "handslot.r", d.right_hand_item)
	if d.left_hand_item:
		ModelUtils.attach_to_bone(model, "handslot.l", d.left_hand_item)
	$CharacterAnimator.model = model
	$HealthComponent.max_health = d.max_health
	$CharacterMotor.walk_speed = d.walk_speed
	$CharacterMotor.run_speed = d.run_speed
	$CharacterMotor.sprint_speed = d.run_speed
	var c: CombatController = $CombatController
	c.moveset = d.moveset
	c.faction = d.faction
	c.max_poise = d.max_poise
	c.stagger_duration = d.stagger_duration
	c.flinch_duration = d.flinch_duration
	$EnemyController.definition = d
	$CombatSfx.sounds = d.sounds


func _ready() -> void:
	assert(definition != null, "Enemy needs an EnemyDefinition")
	combat.died.connect(_on_died)


func _on_died() -> void:
	# Corpses stop blocking movement, then sink away.
	collision_layer = 0
	await get_tree().create_timer(CORPSE_SECONDS, false).timeout
	var tween := create_tween()
	tween.tween_property($Model, "position:y", -1.5, 1.5)
	await tween.finished
	queue_free()
