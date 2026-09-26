class_name ResourceNode
extends StaticBody3D
## A tree, boulder, ore vein or crop plot. Everything specific comes from
## its ResourceNodeDefinition.
##
## Lifecycle: RIPE (hit it to gather) -> depleted -> [TEND: labour to
## replant, if the definition needs it] -> GROWING (timer) -> RIPE.
## Players gather by hitting it or pressing interact; workers call
## apply_work(). Both go through the same path, so feedback is identical.

@export var definition: ResourceNodeDefinition
## False when part of a Building (the Building persists it instead).
@export var standalone_persistence := true

var health: HealthComponent
var receiver: DamageReceiver
var interactable: Interactable

var _pivot: Node3D
var _model: Node3D
var _depleted_model: Node3D
var _audio: AudioStreamPlayer3D
var _anim_tween: Tween
var _collider: CollisionShape3D
var _is_depleted := false
var _growing := false
var _tend_progress := 0.0
var _respawn_left := 0.0
var _built := false
var _claimed_by: Object = null
var _last_hit_from := Vector3.FORWARD

## Only melee swings and tool work gather; bolts and spells do not.
const WORK_TAGS: PackedStringArray = ["melee", "work"]


func _enter_tree() -> void:
	if _built or definition == null:
		return
	_built = true
	_build()


func _ready() -> void:
	add_to_group(SaveManager.GROUP if standalone_persistence else Building.FEATURE_GROUP)
	add_to_group(WorkTarget.GROUP)
	set_process(false)
	_update_prompt()


func is_depleted() -> bool:
	return _is_depleted


## Depleted and waiting for someone to replant it.
func needs_tending() -> bool:
	return _is_depleted and not _growing and definition.tend_work > 0.0


func is_ripe() -> bool:
	return not _is_depleted


# --- work target (workers) ------------------------------------------------------

## Does this node offer work to someone with `job` right now?
func has_work_for(job: JobDefinition) -> bool:
	var item := definition.yield_item
	if item == null or not job.gathers(item.id):
		return false
	return is_ripe() or needs_tending()


## A worker reserves this node so others pick a different one.
func can_claim(by: Object) -> bool:
	return _claimed_by == null or _claimed_by == by or not is_instance_valid(_claimed_by)


func claim(by: Object) -> bool:
	if not can_claim(by):
		return false
	_claimed_by = by
	return true


func release(by: Object) -> void:
	if _claimed_by == by:
		_claimed_by = null


## Where a worker should stand to work on this node.
func work_position(from: Vector3) -> Vector3:
	var away := NavSteering.flat(from - global_position)
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	return global_position + away.normalized() * (maxf(definition.collision_radius, 0.3) + 0.55)


## One unit of labour (a tool swing). Harvests a ripe node through the same
## damage path as a melee hit, or tends a depleted one.
func apply_work(amount: float, worker: Node3D, tags: PackedStringArray) -> Dictionary:
	if needs_tending():
		_tend(amount)
		return {}
	if _is_depleted:
		return {}
	var e := DamageEvent.create(worker, amount)
	e.tags = tags
	e.hit_position = global_position + Vector3.UP * 1.0
	receiver.receive(e)
	return {"produced_at": global_position} if _is_depleted else {}


func _tend(amount: float) -> void:
	_tend_progress += amount
	_play_hit_sound()
	if _tend_progress >= definition.tend_work:
		_start_growing()
	_update_prompt()


# --- player interaction ----------------------------------------------------------

func _on_interacted(by: InteractionController) -> void:
	by.motor.face(global_position - by.body.global_position, true)
	if needs_tending():
		# Sowing isn't a weapon swing: kneel-and-work animation + labour.
		if by.combat.perform(&"Interact", 1.4):
			_tend(definition.tend_work * 0.5)
	else:
		by.combat.request_light()


func _update_prompt() -> void:
	if interactable == null:
		return
	var d := definition
	if needs_tending():
		interactable.enabled = true
		interactable.prompt = "%s %s" % [d.tend_verb, d.display_name]
	elif _is_depleted:
		interactable.enabled = false
	else:
		interactable.enabled = true
		interactable.prompt = "%s %s" % [d.prompt, d.display_name]


# --- damage (harvest) ------------------------------------------------------------

func _on_about_to_take_damage(event: DamageEvent) -> void:
	var m := 1.0
	for tag in event.tags:
		m *= float(definition.tag_multipliers.get(tag, 1.0))
	event.amount *= m


func _on_damage_taken(event: DamageEvent) -> void:
	_play_hit_sound()
	if not health.is_alive():
		return
	# Shudder away from the hit.
	var away := global_position - (event.source as Node3D).global_position if event.source else Vector3.FORWARD
	away.y = 0.0
	var axis := Vector3.UP.cross(away.normalized())
	_restart_tween()
	_anim_tween.tween_property(_pivot, "quaternion", Quaternion(axis, 0.06), 0.05)
	_anim_tween.tween_property(_pivot, "quaternion", Quaternion.IDENTITY, 0.2).set_trans(Tween.TRANS_ELASTIC)
	_last_hit_from = away.normalized() if away.length() > 0.01 else Vector3.FORWARD


func _play_hit_sound() -> void:
	if definition.hit_sound:
		_audio.stream = definition.hit_sound
		_audio.pitch_scale = randf_range(0.9, 1.1)
		_audio.play()


func _on_depleted() -> void:
	_set_depleted(true)
	var dir := _last_hit_from
	# Yield exists (and is saved) immediately; it's revealed when the
	# animation lands, so a save mid-fall can't lose or duplicate it.
	var drops := _spawn_yield(dir, definition.deplete_style == ResourceNodeDefinition.DepleteStyle.FALL)
	_restart_tween()
	match definition.deplete_style:
		ResourceNodeDefinition.DepleteStyle.FALL:
			var axis := Vector3.UP.cross(dir)
			_anim_tween.tween_property(_pivot, "quaternion", Quaternion(axis, PI * 0.5), 0.9) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_anim_tween.tween_callback(_reveal.bind(drops))
			_anim_tween.tween_property(_pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		ResourceNodeDefinition.DepleteStyle.CRUMBLE:
			_anim_tween.tween_property(_pivot, "scale", Vector3(1.1, 0.4, 1.1), 0.18)
			_anim_tween.tween_callback(_reveal.bind(drops))
			_anim_tween.tween_property(_pivot, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
		ResourceNodeDefinition.DepleteStyle.HARVEST:
			_anim_tween.tween_property(_pivot, "scale", _stubble_scale(), 0.2)
			_anim_tween.tween_callback(_reveal.bind(drops))


func _stubble_scale() -> Vector3:
	return Vector3(1.0, 0.12, 1.0)


## Kills any running animation and starts a fresh tween (only call when
## about to add tweeners to it).
func _restart_tween() -> void:
	_kill_tween()
	_anim_tween = create_tween()


func _kill_tween() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


func _reveal(drops: Array[Carryable]) -> void:
	for body in drops:
		if is_instance_valid(body) and body.is_available():
			body.visible = true
			body.freeze = false
			body.linear_velocity = Vector3.UP * 1.5


func _spawn_yield(dir: Vector3, along_trunk: bool) -> Array[Carryable]:
	var drops: Array[Carryable] = []
	var item := definition.yield_item
	if item == null or item.carry_scene == null:
		return drops
	var parent := get_tree().get_first_node_in_group(WorldItems.GROUP)
	if parent == null:
		parent = get_parent()
	for i in definition.yield_count:
		var body: Carryable = item.carry_scene.instantiate()
		var offset: Vector3
		if along_trunk:
			offset = dir * (1.6 + i * 1.3) + dir.cross(Vector3.UP) * randf_range(-0.3, 0.3)
		else:
			# Fan out to the sides of the hitter, just clear of the collider:
			# never inside rubble, never on top of whoever is working.
			var side := 1.0 if i % 2 == 0 else -1.0
			var spread := side * deg_to_rad(60.0 + (i / 2) * 45.0)
			offset = (-dir).rotated(Vector3.UP, spread) * (maxf(definition.collision_radius, 0.2) + 0.7)
		parent.add_child(body)
		body.global_position = global_position + offset + Vector3.UP * (0.6 + i * 0.1)
		body.rotation.y = randf() * TAU
		body.visible = false
		body.freeze = true
		drops.append(body)
	return drops


# --- lifecycle ---------------------------------------------------------------------

func _set_depleted(value: bool) -> void:
	_is_depleted = value
	_growing = false
	_tend_progress = 0.0
	if _depleted_model:
		_depleted_model.visible = value
	if value:
		# Things that need tending wait for a worker; others regrow alone.
		if definition.tend_work <= 0.0:
			_start_growing()
		if _collider:
			_set_collider_height(0.6)  # stump / rubble stays an obstacle
	else:
		set_process(false)
		if _collider:
			_set_collider_height(definition.collision_height)
	_update_prompt()


func _start_growing() -> void:
	_growing = true
	_respawn_left = definition.respawn_seconds
	set_process(definition.respawn_seconds > 0.0)
	if definition.grow_visual:
		_kill_tween()
		_pivot.quaternion = Quaternion.IDENTITY
		_pivot.scale = Vector3(0.6, 0.15, 0.6)
	_update_prompt()


func _process(delta: float) -> void:
	_respawn_left -= delta
	if definition.grow_visual and definition.respawn_seconds > 0.0:
		var t := 1.0 - clampf(_respawn_left / definition.respawn_seconds, 0.0, 1.0)
		_pivot.scale = Vector3(lerpf(0.6, 1.0, t), lerpf(0.15, 1.0, t), lerpf(0.6, 1.0, t))
	if _respawn_left <= 0.0:
		_replenish(not definition.grow_visual)


func _replenish(animate := true) -> void:
	_set_depleted(false)
	health.set_current(health.max_health)
	_pivot.quaternion = Quaternion.IDENTITY
	_kill_tween()
	if animate:
		_pivot.scale = Vector3.ONE * 0.01
		_restart_tween()
		_anim_tween.tween_property(_pivot, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK)
	else:
		_pivot.scale = Vector3.ONE


# --- construction ---------------------------------------------------------------------

func _build() -> void:
	var d := definition
	collision_layer = 1
	collision_mask = 0

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_model = d.model.instantiate()
	_model.scale = Vector3.ONE * d.model_scale
	_pivot.add_child(_model)
	if d.camera_fade_radius > 0.0:
		_pivot.add_to_group(CameraOcclusion.GROUP)
		_pivot.set_meta(&"fade_center", Vector3.UP * d.camera_fade_height)
		_pivot.set_meta(&"fade_radius", d.camera_fade_radius)
	if d.depleted_model:
		_depleted_model = d.depleted_model.instantiate()
		_depleted_model.scale = Vector3.ONE * d.depleted_scale
		_depleted_model.visible = false
		add_child(_depleted_model)

	if d.collision_radius > 0.0:
		var shape := CylinderShape3D.new()
		shape.radius = d.collision_radius
		shape.height = d.collision_height
		_collider = CollisionShape3D.new()
		_collider.shape = shape
		add_child(_collider)
		_set_collider_height(d.collision_height)
		# Reserve ground under the canopy for placement, felled or not.
		add_child(Footprint.cylinder(maxf(d.collision_radius + 0.6, d.camera_fade_radius * 0.8)))

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = d.max_health
	add_child(health)
	health.died.connect(_on_depleted)

	receiver = DamageReceiver.new()
	receiver.name = "Hurtbox"
	receiver.health = health
	receiver.allowed_attacker_factions = d.gatherer_factions
	receiver.required_any_tags = WORK_TAGS
	var hurt_shape := CylinderShape3D.new()
	hurt_shape.radius = maxf(d.collision_radius, 0.3) + 0.3
	hurt_shape.height = minf(maxf(d.collision_height, 1.0), 2.5)
	var hurt_col := CollisionShape3D.new()
	hurt_col.shape = hurt_shape
	hurt_col.position.y = hurt_shape.height * 0.5
	receiver.add_child(hurt_col)
	add_child(receiver)
	receiver.about_to_take_damage.connect(_on_about_to_take_damage)
	receiver.damage_taken.connect(_on_damage_taken)

	interactable = Interactable.new()
	interactable.name = "Interactable"
	var i_shape := SphereShape3D.new()
	i_shape.radius = maxf(d.collision_radius, 0.3) + 0.8
	var i_col := CollisionShape3D.new()
	i_col.shape = i_shape
	i_col.position.y = 1.0
	interactable.add_child(i_col)
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)

	var bar := WorldHealthBar.new()
	bar.health = health
	bar.position.y = minf(maxf(d.collision_height, 1.2), 2.4) + 0.3
	add_child(bar)

	_audio = AudioStreamPlayer3D.new()
	_audio.position.y = 1.2
	_audio.unit_size = 6.0
	add_child(_audio)


func _set_collider_height(h: float) -> void:
	(_collider.shape as CylinderShape3D).height = h
	_collider.position.y = h * 0.5


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "resource:%s" % get_path()


func save_state() -> Dictionary:
	return {
		"health": health.current, "depleted": _is_depleted, "growing": _growing,
		"tend": _tend_progress, "respawn_left": _respawn_left,
	}


func load_state(state: Dictionary) -> void:
	_kill_tween()
	if state.get("depleted", false):
		health.current = 0.0
		_is_depleted = false  # force the transition below
		_set_depleted(true)
		_pivot.quaternion = Quaternion.IDENTITY
		_pivot.scale = _stubble_scale() if definition.deplete_style == ResourceNodeDefinition.DepleteStyle.HARVEST \
			else Vector3.ONE * 0.01
		_tend_progress = float(state.get("tend", 0.0))
		if state.get("growing", false):
			_start_growing()
		_respawn_left = float(state.get("respawn_left", definition.respawn_seconds))
		if _growing and definition.grow_visual:
			_process(0.0)
	else:
		_replenish(false)
		health.set_current(float(state.get("health", health.max_health)))
	_update_prompt()
