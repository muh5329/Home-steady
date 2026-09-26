class_name Player
extends CharacterBody3D
## Player root. Wires components together and handles persistence; the
## body, stats and gear come from the chosen class via CharacterLoadout.

const GROUP := &"player"

## Used when no class was chosen (tests, direct scene runs).
@export var default_class: CharacterClassData

var character_class: CharacterClassData:
	get: return loadout.character_class
var model_root: Node3D:
	get: return loadout.model_root

@onready var motor: CharacterMotor = $CharacterMotor
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatController = $CombatController
@onready var interaction: InteractionController = $Interaction
@onready var carry: CarryComponent = $Carry
@onready var equipment: EquipmentController = $Equipment
@onready var abilities: AbilityController = $Abilities
@onready var loadout: CharacterLoadout = $Loadout
@onready var controller: PlayerController = $PlayerController
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(SaveManager.GROUP)
	loadout.apply(GameManager.selected_class if GameManager.selected_class else default_class)
	carry.carrying_changed.connect(func(item): equipment.set_weapon_visible(item == null))


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	combat.revive()
	camera_rig.snap()


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "player"


func can_save() -> bool:
	return combat.is_alive()


func save_state() -> Dictionary:
	return {
		"class": String(character_class.id),
		"position": SaveManager.vec3_to_array(global_position),
		"yaw": rotation.y,
		"health": health.current,
		"carrying": carry.save_state(),
		"weapon": String(equipment.weapon.id) if equipment.weapon else "",
	}


func load_state(state: Dictionary) -> void:
	carry.discard_carried()
	var class_id := StringName(state.get("class", ""))
	if class_id != &"" and class_id != character_class.id and DataRegistry.has_data(class_id):
		loadout.apply(DataRegistry.get_data(class_id) as CharacterClassData)
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
	var weapon_id := StringName(state.get("weapon", ""))
	if weapon_id != &"" and DataRegistry.has_data(weapon_id):
		equipment.equip(DataRegistry.get_data(weapon_id) as WeaponData)
	carry.load_state(state.get("carrying", ""))
	camera_rig.snap()
