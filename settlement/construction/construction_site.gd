class_name ConstructionSite
extends StaticBody3D
## A placed-but-unfinished building. Needs its materials delivered as
## physical items (E while carrying), then labour (melee swings, or E).
## Workers will use exactly the same two entry points later:
## `interactable.receive(item)` and hitting the hurtbox.

signal completed(site: ConstructionSite)

## Construction stage visuals, shown as overall progress rises.
@export var stage_models: Array[PackedScene] = []
@export var scaffolding_model: PackedScene
## Stage models are ~1 m hex tiles; scaled to the footprint's short side.
@export var model_scale_per_metre := 1.15

var definition: BuildingDefinition
var uid := ""
var delivered: Dictionary[StringName, int] = {}

var interactable: Interactable
var receiver: DamageReceiver
var work: HealthComponent

var _stages: Array[Node3D] = []
var _scaffold: Node3D
var _label: Label3D
var _audio: AudioStreamPlayer3D
var _built := false


func _enter_tree() -> void:
	if _built or definition == null:
		return
	_built = true
	_build()


func _ready() -> void:
	add_to_group(Settlement.CONSTRUCTION_GROUP)
	add_to_group(WorkTarget.GROUP)
	_refresh()


# --- queries --------------------------------------------------------------------

func remaining(item_id: StringName) -> int:
	return maxi(definition.cost.get(item_id, 0) - delivered.get(item_id, 0), 0)


## item id -> amount still needed.
func needs() -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	for id in definition.cost:
		var r := remaining(id)
		if r > 0:
			out[id] = r
	return out


func materials_complete() -> bool:
	return needs().is_empty()


func progress() -> float:
	var total := 0
	var have := 0
	for id in definition.cost:
		total += definition.cost[id]
		have += mini(delivered.get(id, 0), definition.cost[id])
	var m := 1.0 if total == 0 else float(have) / total
	var w := 1.0 - work.current / work.max_health
	return m * 0.5 + w * 0.5


# --- materials --------------------------------------------------------------------

func accepts(item: Carryable) -> bool:
	return remaining(item.item_id) > 0


func deliver(item: Carryable) -> bool:
	if not accepts(item):
		return false
	delivered[item.item_id] = delivered.get(item.item_id, 0) + 1
	item.queue_free()
	_play(preload("res://audio/sfx/thud.wav"))
	_refresh()
	return true


# --- labour -------------------------------------------------------------------------

## Labour from a worker, without a hitbox (same effect as a melee hit).
func apply_work(amount: float, worker: Node3D, tags: PackedStringArray) -> Dictionary:
	var e := DamageEvent.create(worker, amount)
	e.tags = tags
	e.hit_position = global_position + Vector3.UP * 1.0
	receiver.receive(e)
	return {}


# WorkTarget contract: builders share a site, so claims always succeed.
func has_work_for(job: JobDefinition) -> bool:
	return job.builds and materials_complete() and work.is_alive()


func can_claim(_by: Object) -> bool:
	return true


func claim(_by: Object) -> bool:
	return true


func release(_by: Object) -> void:
	pass


func work_position(from: Vector3) -> Vector3:
	var local := to_local(from)
	var half := Vector3(definition.footprint.x, 0, definition.footprint.y) * 0.5 + Vector3(0.6, 0, 0.6)
	local = Vector3(clampf(local.x, -half.x, half.x), 0, clampf(local.z, -half.z, half.z))
	# Push to the nearest edge of the (grown) footprint.
	if absf(local.x) / half.x > absf(local.z) / half.z:
		local.x = signf(local.x) * half.x
	else:
		local.z = signf(local.z) * half.z
	return to_global(local)


func _on_interacted(by: InteractionController) -> void:
	if materials_complete():
		by.motor.face(global_position - by.body.global_position, true)
		by.combat.request_light()


func _on_about_to_take_damage(event: DamageEvent) -> void:
	if not materials_complete():
		event.amount = 0.0  # can't build without materials


func _on_damage_taken(event: DamageEvent) -> void:
	if event.amount > 0.0:
		_play(preload("res://audio/sfx/hit_bone_2.wav"))
	_refresh()


func _on_work_done() -> void:
	# Deferred: let this hit's signal handlers finish before we're replaced.
	completed.emit.call_deferred(self)


# --- visuals --------------------------------------------------------------------------

func _refresh() -> void:
	if not is_inside_tree():
		return
	var p := progress()
	var stage := clampi(int(p * _stages.size()), 0, _stages.size() - 1)
	for i in _stages.size():
		_stages[i].visible = i == stage
	if _scaffold:
		_scaffold.visible = materials_complete()
	var lines: PackedStringArray = [definition.display_name]
	var n := needs()
	if n.is_empty():
		lines.append("Build it!  %d%%" % roundi(p * 100.0))
		interactable.prompt = "Build %s" % definition.display_name
	else:
		var parts: PackedStringArray = []
		for id in definition.cost:
			var item := DataRegistry.get_data(id) as ItemData
			parts.append("%s %d/%d" % [item.display_name, delivered.get(id, 0), definition.cost[id]])
		lines.append("  ".join(parts))
		interactable.prompt = "%s needs %s" % [definition.display_name, "  ".join(parts)]
	_label.text = "\n".join(lines)


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.pitch_scale = randf_range(0.9, 1.1)
	_audio.play()


func _build() -> void:
	var d := definition
	collision_layer = 1
	collision_mask = 0

	# Dirt foundation.
	var foundation := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(d.footprint.x, 0.12, d.footprint.y)
	foundation.mesh = box
	foundation.position.y = 0.06
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.24)
	mat.roughness = 1.0
	foundation.material_override = mat
	add_child(foundation)

	var model_scale := minf(d.footprint.x, d.footprint.y) * model_scale_per_metre
	for scene in stage_models:
		var stage: Node3D = scene.instantiate()
		stage.scale = Vector3.ONE * model_scale
		add_child(stage)
		_stages.append(stage)
	if scaffolding_model:
		_scaffold = scaffolding_model.instantiate()
		_scaffold.scale = Vector3.ONE * model_scale
		add_child(_scaffold)

	# Full-footprint collider from the start: nothing can stand where the
	# finished building will appear.
	var shape := BoxShape3D.new()
	shape.size = Vector3(d.footprint.x * 0.95, 1.2, d.footprint.y * 0.95)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.6
	add_child(col)
	add_child(Footprint.box(Vector3(d.footprint.x, 2.0, d.footprint.y),
		Vector3(d.footprint_offset.x, 0, d.footprint_offset.y)))

	work = HealthComponent.new()
	work.name = "Work"
	work.max_health = d.build_work
	add_child(work)
	work.died.connect(_on_work_done)

	receiver = DamageReceiver.new()
	receiver.name = "Hurtbox"
	receiver.health = work
	receiver.allowed_attacker_factions = [&"player"]
	var hurt := CollisionShape3D.new()
	var hurt_shape := BoxShape3D.new()
	hurt_shape.size = Vector3(d.footprint.x * 0.9, 2.0, d.footprint.y * 0.9)
	hurt.shape = hurt_shape
	hurt.position.y = 1.0
	receiver.add_child(hurt)
	add_child(receiver)
	receiver.about_to_take_damage.connect(_on_about_to_take_damage)
	receiver.damage_taken.connect(_on_damage_taken)

	interactable = Interactable.new()
	interactable.name = "Interactable"
	interactable.deposit_verb = "Deliver"
	var i_shape := BoxShape3D.new()
	i_shape.size = Vector3(d.footprint.x + 1.6, 2.5, d.footprint.y + 1.6)
	var i_col := CollisionShape3D.new()
	i_col.shape = i_shape
	i_col.position.y = 1.25
	interactable.add_child(i_col)
	add_child(interactable)
	interactable.item_filter = accepts
	interactable.item_receiver = deliver
	interactable.interacted.connect(_on_interacted)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 4.2
	_label.font_size = 64
	_label.pixel_size = 0.006
	_label.outline_size = 14
	_label.visibility_range_end = 30.0
	_label.modulate = Color(1, 0.95, 0.8)
	add_child(_label)

	_audio = AudioStreamPlayer3D.new()
	_audio.position.y = 1.0
	add_child(_audio)


# --- persistence (driven by BuildingRegistry) ---------------------------------------

func save_state() -> Dictionary:
	var d := {}
	for id in delivered:
		d[String(id)] = delivered[id]
	return {"delivered": d, "work": work.current}


func load_state(state: Dictionary) -> void:
	delivered.clear()
	var d: Dictionary = state.get("delivered", {})
	for id in d:
		delivered[StringName(id)] = int(d[id])
	work.set_current(float(state.get("work", work.max_health)))
	_refresh()
	# Saved in the frame between finishing and being replaced.
	if materials_complete() and work.current <= 0.0:
		completed.emit.call_deferred(self)
