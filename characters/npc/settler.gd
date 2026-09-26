class_name Settler
extends CharacterBody3D
## A character of the world who can live in the settlement. The same body
## works as a villager (WorkerController) or adventures as a companion
## (CompanionController); the mode decides which brain runs. The class
## (CharacterLoadout) gives body, stats, weapon and abilities, exactly as
## for the player. This root wires components, presents the character
## (tool/weapon, nameplate, prompt) and persists identity.

signal mode_changed(mode: Mode)

const GROUP := &"settlers"
const REVIVE_SECONDS := 1.0
## Within this distance a nameplate also says what the settler is doing.
const ACTIVITY_RANGE := 4.0
const REVIVE_HEALTH := 0.5

## STRANGER: met in the world, not (yet) part of the settlement.
enum Mode { STRANGER, WORKER, COMPANION }

@export var settler_name := "Settler"
@export var character_class: CharacterClassData
@export var mode := Mode.WORKER
## What a stranger says when you first talk to them.
@export_multiline var greeting := ""

var uid := ""

@onready var motor: CharacterMotor = $CharacterMotor
@onready var animator: CharacterAnimator = $CharacterAnimator
@onready var health: HealthComponent = $HealthComponent
@onready var combat: CombatController = $CombatController
@onready var carry: CarryComponent = $Carry
@onready var equipment: EquipmentController = $Equipment
@onready var abilities: AbilityController = $Abilities
@onready var loadout: CharacterLoadout = $Loadout
@onready var worker: WorkerController = $Worker
@onready var companion: CompanionController = $Companion
@onready var nameplate: Label3D = $Nameplate
@onready var interactable: Interactable = $Interactable
@onready var health_bar: Node3D = $HealthBar

var model_root: Node3D:
	get: return loadout.model_root

var _tool: Node3D  # the visible job tool (rig part or attached scene)
var _attached_tool: Node3D  # a tool scene we attached (freed on change)
var _ready_done := false
var _nameplate_near := false
var _nameplate_check := 0.0


func _process(delta: float) -> void:
	_nameplate_check -= delta
	if _nameplate_check <= 0.0:
		_nameplate_check = 0.5
		var player := get_tree().get_first_node_in_group(Player.GROUP) as Node3D
		var near := player != null and player.global_position.distance_to(global_position) < ACTIVITY_RANGE
		if near != _nameplate_near:
			_update_nameplate()


func _ready() -> void:
	add_to_group(GROUP)
	loadout.apply(character_class)
	carry.carrying_changed.connect(func(_item): _apply_look())
	worker.activity_changed.connect(func(_a): _update_nameplate())
	companion.activity_changed.connect(func(_a): _update_nameplate())
	worker.job_changed.connect(func(_j): _apply_look())
	combat.died.connect(_update_prompt)
	combat.revived.connect(_update_prompt)
	interactable.interacted.connect(_on_interacted)
	_ready_done = true
	_enter_mode(mode)


func _exit_tree() -> void:
	var party := Party.of(self)
	if party:
		party.remove(self)
	_set_party_collision(false)


# --- queries ---------------------------------------------------------------------

func is_member() -> bool:
	return mode != Mode.STRANGER


func is_downed() -> bool:
	return not combat.is_alive()


func job_title() -> String:
	return worker.job.display_name if worker.job else "No job"


func class_title() -> String:
	return character_class.display_name if character_class else "Commoner"


## Why this stranger can't be recruited right now ("" = they can).
func recruit_blocker() -> String:
	if mode != Mode.STRANGER:
		return "already one of us"
	var s := Settlement.of(self)
	if s == null:
		return "no settlement nearby"
	if s.free_beds() <= 0:
		return "needs a free bed — build a house"
	return ""


func party_blocker() -> String:
	var party := Party.of(self)
	if party == null:
		return "no party"
	if is_downed():
		return "downed"
	if not party.has(self) and party.is_full():
		return "party is full (%d)" % Party.MAX_COMPANIONS
	return ""


# --- commands (talk panel, party orders) --------------------------------------------

## A stranger moves into a free bed and starts working.
func recruit() -> bool:
	if recruit_blocker() != "":
		return false
	worker.home_position = _free_bed_position()
	_enter_mode(Mode.WORKER)
	DebugOverlay.notify("%s joined the settlement" % settler_name)
	return true


func join_party() -> bool:
	if party_blocker() != "":
		return false
	_enter_mode(Mode.COMPANION)
	return true


## Leaves the party, goes home and gets back to work.
func send_home() -> void:
	if mode == Mode.COMPANION:
		_enter_mode(Mode.WORKER)


func set_job(job: JobDefinition) -> void:
	worker.set_job(job)


func order_follow() -> void:
	companion.set_order(CompanionController.Order.FOLLOW)


## Holds at `at` (default: where they stand now).
func order_hold(at: Variant = null) -> void:
	companion.set_order(CompanionController.Order.HOLD, at)


# --- modes ------------------------------------------------------------------------

func _enter_mode(new_mode: Mode) -> void:
	mode = new_mode
	var party := Party.of(self)
	_set_party_collision(mode == Mode.COMPANION)
	health_bar.visible = mode != Mode.STRANGER
	match mode:
		Mode.STRANGER:
			worker.deactivate()
			companion.deactivate()
			# A bystander, not a combatant: nobody targets or hurts them.
			combat.set_faction(&"neutral")
			combat.receiver.accepts_damage = false
		Mode.WORKER:
			companion.deactivate()
			if party:
				party.remove(self)
			_become_combatant()
			worker.activate()
		Mode.COMPANION:
			worker.deactivate()
			if party:
				party.add(self)
			_become_combatant()
			companion.activate()
	_apply_look()
	mode_changed.emit(mode)


func _become_combatant() -> void:
	combat.set_faction(&"player")
	combat.receiver.accepts_damage = true


## Companions don't body-block the player (doorways, corridors, turning
## formations); steering separation keeps them apart instead.
func _set_party_collision(off: bool) -> void:
	var p := get_tree().get_first_node_in_group(Player.GROUP) as PhysicsBody3D
	if p == null:
		return
	if off:
		add_collision_exception_with(p)
		p.add_collision_exception_with(self)
	else:
		remove_collision_exception_with(p)
		p.remove_collision_exception_with(self)


func _free_bed_position() -> Vector3:
	var best := global_position
	var best_d := INF
	for h in get_tree().get_nodes_in_group(HousingComponent.GROUP):
		var house := h.get_parent() as Node3D
		if house == null:
			continue
		var d := house.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = house.global_position
	if best_d == INF:
		return best
	# Stand in front of the house, not inside it.
	var out := NavSteering.flat(global_position - best)
	return best + (out.normalized() if out.length_squared() > 0.01 else Vector3.BACK) * 2.5


# --- interaction ----------------------------------------------------------------------

func _on_interacted(by: InteractionController) -> void:
	if is_downed():
		_revive_by(by)
	else:
		EventBus.talk_requested.emit(self)


## The player kneels beside us for a moment; if not interrupted, we get up.
func _revive_by(by: InteractionController) -> void:
	if mode == Mode.STRANGER or not by.combat.perform(&"Interact", 1.0, 0.0, REVIVE_SECONDS):
		return
	# Connected (not awaited): if either of us is freed meanwhile, the
	# callback is dropped instead of resuming on a dead instance.
	get_tree().create_timer(REVIVE_SECONDS * 0.9, false).timeout.connect(
		_finish_revive.bind(by, by.combat.action_serial))


func _finish_revive(by: InteractionController, serial: int) -> void:
	if not is_instance_valid(by) or by.combat.action_serial != serial or not is_downed():
		return
	combat.revive(health.max_health * REVIVE_HEALTH)
	DebugOverlay.notify("%s is back on their feet" % settler_name)


# --- presentation ----------------------------------------------------------------------

## Working: the job's tool. Otherwise: the class weapon. Carrying: neither.
func _apply_look() -> void:
	if not _ready_done:
		return
	_clear_tool()
	var working := mode == Mode.WORKER
	var hands_free := carry.carrying == null
	equipment.set_weapon_visible(not working and hands_free)
	var job := worker.job
	if working and job and hands_free:
		if job.tool_part != &"":
			_tool = model_root.find_child(job.tool_part, true, false)
			if _tool:
				_tool.visible = true
		if _tool == null and job.tool_scene:
			_attached_tool = ModelUtils.attach_to_bone(model_root, "handslot.r", job.tool_scene)
			_tool = _attached_tool
	_update_prompt()
	_update_nameplate()


func _clear_tool() -> void:
	if _tool and _tool != _attached_tool:
		_tool.visible = false
	if _attached_tool:
		_attached_tool.get_parent().queue_free()  # its BoneAttachment3D
		_attached_tool = null
	_tool = null


func _update_prompt() -> void:
	if is_downed():
		interactable.prompt = "Revive %s" % settler_name
		interactable.focus_priority = 2
		return
	interactable.focus_priority = -1
	match mode:
		Mode.STRANGER:
			interactable.prompt = "Talk to %s" % settler_name
		Mode.WORKER:
			interactable.prompt = "Talk to %s (%s)" % [settler_name, job_title()]
		Mode.COMPANION:
			interactable.prompt = "Talk to %s (companion)" % settler_name


func _update_nameplate() -> void:
	if not _ready_done:
		return
	# Close up you see what they're doing; from afar just who they are.
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Node3D
	var near := player != null and player.global_position.distance_to(global_position) < ACTIVITY_RANGE
	_nameplate_near = near
	if not near:
		nameplate.text = "%s · %s" % [settler_name, class_title() if mode != Mode.WORKER else job_title()]
		return
	match mode:
		Mode.STRANGER:
			nameplate.text = "%s · %s\n(stranger)" % [settler_name, class_title()]
		Mode.WORKER:
			nameplate.text = "%s · %s\n%s" % [settler_name, job_title(), worker.activity]
		Mode.COMPANION:
			nameplate.text = "%s · %s\n%s" % [settler_name, class_title(), companion.activity]


# --- persistence (driven by Population) -------------------------------------------

func save_state() -> Dictionary:
	return {
		"name": settler_name,
		"class": String(character_class.id) if character_class else "",
		"mode": Mode.keys()[mode],
		"order": CompanionController.Order.keys()[companion.order],
		"hold": SaveManager.vec3_to_array(companion.hold_position),
		"greeting": greeting,
		"job": String(worker.job.id) if worker.job else "",
		"origin": SaveManager.vec3_to_array(global_position),
		"yaw": rotation.y,
		"home": SaveManager.vec3_to_array(worker.home_position),
		"health": health.current,
		"downed": is_downed(),
		"carrying": carry.save_state(),
	}


func load_state(state: Dictionary) -> void:
	settler_name = state.get("name", settler_name)
	greeting = state.get("greeting", greeting)
	var class_id := StringName(state.get("class", ""))
	if class_id != &"" and DataRegistry.has_data(class_id) and (character_class == null or class_id != character_class.id):
		character_class = DataRegistry.get_data(class_id) as CharacterClassData
		loadout.apply(character_class)
	var job_id := StringName(state.get("job", ""))
	worker.set_job(DataRegistry.get_data(job_id) as JobDefinition if job_id != &"" and DataRegistry.has_data(job_id) else null)
	global_position = SaveManager.array_to_vec3(state["origin"])
	rotation.y = float(state.get("yaw", 0.0))
	motor.face(Vector3.FORWARD.rotated(Vector3.UP, rotation.y), true)
	worker.home_position = SaveManager.array_to_vec3(state.get("home", state["origin"]))
	health.set_current(maxf(float(state.get("health", health.max_health)), 1.0))
	carry.load_state(state.get("carrying", ""))
	companion.order = CompanionController.Order.get(state.get("order", "FOLLOW"), CompanionController.Order.FOLLOW)
	companion.hold_position = SaveManager.array_to_vec3(state.get("hold", [0, 0, 0]))
	_enter_mode(Mode.get(state.get("mode", "WORKER"), Mode.WORKER))
	if state.get("downed", false) and not is_downed():
		health.take(health.current)  # still down after loading; the brain handles recovery
