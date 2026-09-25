class_name Settler
extends CharacterBody3D
## A villager. The same body can work in the settlement (WorkerController)
## and, later, adventure as a companion. Root only wires components,
## presents the job (tool, nameplate) and persists identity.

const GROUP := &"settlers"

@export var settler_name := "Settler"
@export var hidden_parts: PackedStringArray = []
## Rig parts that may serve as job tools (hidden unless the job uses one).
@export var tool_parts: PackedStringArray = []

var uid := ""

@onready var model_root: Node3D = $Model.get_child(0)
@onready var motor: CharacterMotor = $CharacterMotor
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatController = $CombatController
@onready var carry: CarryComponent = $Carry
@onready var worker: WorkerController = $Worker
@onready var nameplate: Label3D = $Nameplate
@onready var interactable: Interactable = $Interactable

var _tool: Node3D  # the visible tool (rig part or attached scene)
var _attached_tool: Node3D  # a tool scene we attached (freed on job change)


func _ready() -> void:
	add_to_group(GROUP)
	ModelUtils.set_parts_visible(model_root, hidden_parts, false)
	CarryPoseModifier.install(animator, carry)
	carry.carrying_changed.connect(func(item): if _tool: _tool.visible = item == null)
	worker.activity_changed.connect(func(_a): _update_nameplate())
	worker.job_changed.connect(func(_j): _apply_job_look())
	interactable.interacted.connect(_on_interacted)
	_apply_job_look()


func job_title() -> String:
	return worker.job.display_name if worker.job else "Idle"


## Talking to a settler cycles through the available jobs.
func _on_interacted(_by: InteractionController) -> void:
	var jobs: Array = DataRegistry.get_all(JobDefinition)
	jobs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	if jobs.is_empty():
		return
	var i := jobs.find(worker.job)
	worker.set_job(jobs[(i + 1) % jobs.size()])


func _apply_job_look() -> void:
	ModelUtils.set_parts_visible(model_root, tool_parts, false)
	if _attached_tool:
		_attached_tool.get_parent().queue_free()  # its BoneAttachment3D
		_attached_tool = null
	_tool = null
	var job := worker.job
	if job:
		if job.tool_part != &"":
			_tool = model_root.find_child(job.tool_part, true, false)
			if _tool:
				_tool.visible = true
		elif job.tool_scene:
			_attached_tool = ModelUtils.attach_to_bone(model_root, "handslot.r", job.tool_scene)
			_tool = _attached_tool
		if _tool:
			_tool.visible = carry.carrying == null
	interactable.prompt = "Talk to %s (%s) — change job" % [settler_name, job_title()]
	_update_nameplate()


func _update_nameplate() -> void:
	nameplate.text = "%s · %s\n%s" % [settler_name, job_title(), worker.activity]


# --- persistence (driven by Population) -------------------------------------------

func save_state() -> Dictionary:
	return {
		"name": settler_name,
		"job": String(worker.job.id) if worker.job else "",
		"origin": SaveManager.vec3_to_array(global_position),
		"yaw": rotation.y,
		"home": SaveManager.vec3_to_array(worker.home_position),
		"health": health.current,
		"carrying": carry.save_state(),
	}


func load_state(state: Dictionary) -> void:
	settler_name = state.get("name", settler_name)
	var job_id := StringName(state.get("job", ""))
	if job_id != &"" and DataRegistry.has_data(job_id):
		worker.set_job(DataRegistry.get_data(job_id) as JobDefinition)
	global_position = SaveManager.array_to_vec3(state["origin"])
	rotation.y = float(state.get("yaw", 0.0))
	motor.face(Vector3.FORWARD.rotated(Vector3.UP, rotation.y), true)
	worker.home_position = SaveManager.array_to_vec3(state.get("home", state["origin"]))
	health.set_current(float(state.get("health", health.max_health)))
	carry.load_state(state.get("carrying", ""))
	_apply_job_look()
