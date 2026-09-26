class_name Enemy
extends CharacterBody3D
## Generic monster. The EnemyDefinition supplies model, stats, moveset and
## behaviour tuning; this script applies it to the shared components.

const CORPSE_SECONDS := 4.0
const SCENE_PATH := "res://characters/npc/enemy.tscn"

@export var definition: EnemyDefinition

@onready var motor: CharacterMotor = $CharacterMotor
@onready var combat: CombatController = $CombatController
@onready var health: HealthComponent = $HealthComponent
@onready var controller: EnemyController = $EnemyController
@onready var abilities: AbilityController = $Abilities

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
	_shape_body($CollisionShape3D, d.body_radius, d.body_height)
	_shape_body($Hurtbox/CollisionShape3D, d.hurtbox_radius, d.hurtbox_height)
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
	$Abilities.set_abilities(d.abilities)


func _ready() -> void:
	assert(definition != null, "Enemy needs an EnemyDefinition")
	combat.died.connect(_on_died)
	if definition.is_boss:
		var presence := BossPresence.new()
		presence.enemy = self
		add_child(presence)


## Sizes a capsule (a per-instance copy: scene shapes are shared).
static func _shape_body(node: CollisionShape3D, radius: float, height: float) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(height, radius * 2.0)
	node.shape = capsule
	node.position.y = capsule.height * 0.5


## Creates a monster at global `at` under `parent` (transform set before
## it enters the tree), playing its spawn animation (spawns, summons).
static func raise(def: EnemyDefinition, parent: Node, at: Vector3, yaw := 0.0) -> Enemy:
	var e: Enemy = load(SCENE_PATH).instantiate()
	e.definition = def
	e.position = (parent as Node3D).to_local(at) if parent is Node3D else at
	e.rotation.y = yaw
	parent.add_child(e)
	if def.spawn_animation != &"":
		e.combat.perform(def.spawn_animation, def.spawn_animation_speed)
	return e


func display_name() -> String:
	return definition.display_name


func _on_died() -> void:
	var d := definition
	if not d.loot.is_empty():
		LootDrop.spill(get_tree(), d.loot, global_position, motor.get_facing())
	for id in d.unlocks:
		Progression.unlock(id)
	if d.is_boss:
		EventBus.boss_defeated.emit(self)
	# Corpses stop blocking movement, then sink away.
	collision_layer = 0
	await get_tree().create_timer(CORPSE_SECONDS, false).timeout
	var tween := create_tween()
	tween.tween_property($Model, "position:y", -1.5, 1.5)
	await tween.finished
	queue_free()
