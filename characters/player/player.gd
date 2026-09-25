class_name Player
extends CharacterBody3D
## Player root. Only wires components together and handles persistence;
## all behavior lives in the child components.

const GROUP := &"player"

## Model parts hidden at start (until equipment drives visuals).
@export var hidden_parts: PackedStringArray = []
## Weapon meshes, stowed (hidden) while both hands carry something.
@export var weapon_parts: PackedStringArray = []

@onready var model_root: Node3D = $Model.get_child(0)
@onready var motor: CharacterMotor = $CharacterMotor
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatController = $CombatController
@onready var interaction: InteractionController = $Interaction
@onready var carry: CarryComponent = $Carry
@onready var controller: PlayerController = $PlayerController
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)
	ModelUtils.set_parts_visible(model_root, hidden_parts, false)
	_setup_carry_pose()
	carry.carrying_changed.connect(func(item): ModelUtils.set_parts_visible(model_root, weapon_parts, item == null))


func _setup_carry_pose() -> void:
	CarryPoseModifier.install(animator, carry)


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	combat.revive()


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "player"


func can_save() -> bool:
	return combat.is_alive()


func save_state() -> Dictionary:
	return {
		"position": SaveManager.vec3_to_array(global_position),
		"yaw": rotation.y,
		"health": health.current,
		"carrying": carry.save_state(),
	}


func load_state(state: Dictionary) -> void:
	carry.discard_carried()
	global_position = SaveManager.array_to_vec3(state["position"])
	velocity = Vector3.ZERO
	var yaw := float(state.get("yaw", 0.0))
	rotation.y = yaw
	motor.face(Vector3.FORWARD.rotated(Vector3.UP, yaw), true)
	var hp := float(state.get("health", health.max_health))
	if combat.is_alive():
		combat.interrupt()
		health.set_current(hp)
	else:
		combat.revive(hp)
	carry.load_state(state.get("carrying", ""))
