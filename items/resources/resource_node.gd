class_name ResourceNode
extends StaticBody3D
## A tree, boulder or ore vein placed in the world. Everything specific
## comes from its ResourceNodeDefinition. Players gather by hitting it
## (any melee attack; tools multiply via tags) or by pressing interact,
## which just performs a swing at it.

@export var definition: ResourceNodeDefinition

var health: HealthComponent
var receiver: DamageReceiver
var interactable: Interactable

var _pivot: Node3D
var _model: Node3D
var _depleted_model: Node3D
var _audio: AudioStreamPlayer3D
var _anim_tween: Tween
var _is_depleted := false
var _respawn_left := 0.0
var _built := false


func _enter_tree() -> void:
	if _built or definition == null:
		return
	_built = true
	_build()


func _ready() -> void:
	add_to_group(SaveManager.GROUP)
	set_process(false)


func is_depleted() -> bool:
	return _is_depleted


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

	var shape := CylinderShape3D.new()
	shape.radius = d.collision_radius
	shape.height = d.collision_height
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = d.collision_height * 0.5
	add_child(col)

	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = d.max_health
	add_child(health)
	health.died.connect(_on_depleted)

	receiver = DamageReceiver.new()
	receiver.name = "Hurtbox"
	receiver.health = health
	receiver.allowed_attacker_factions = d.gatherer_factions
	var hurt_shape := CylinderShape3D.new()
	hurt_shape.radius = d.collision_radius + 0.3
	hurt_shape.height = minf(d.collision_height, 2.5)
	var hurt_col := CollisionShape3D.new()
	hurt_col.shape = hurt_shape
	hurt_col.position.y = hurt_shape.height * 0.5
	receiver.add_child(hurt_col)
	add_child(receiver)
	receiver.about_to_take_damage.connect(_on_about_to_take_damage)
	receiver.damage_taken.connect(_on_damage_taken)

	interactable = Interactable.new()
	interactable.name = "Interactable"
	interactable.prompt = "%s %s" % [d.prompt, d.display_name]
	var i_shape := SphereShape3D.new()
	i_shape.radius = d.collision_radius + 0.8
	var i_col := CollisionShape3D.new()
	i_col.shape = i_shape
	i_col.position.y = 1.0
	interactable.add_child(i_col)
	add_child(interactable)
	interactable.interacted.connect(_on_interacted)

	var bar := WorldHealthBar.new()
	bar.health = health
	bar.position.y = minf(d.collision_height, 2.4) + 0.3
	add_child(bar)

	_audio = AudioStreamPlayer3D.new()
	_audio.position.y = 1.2
	_audio.unit_size = 6.0
	add_child(_audio)


# --- gathering ---------------------------------------------------------------

func _on_interacted(by: InteractionController) -> void:
	# "Use" on a resource = swing at it.
	by.motor.face(global_position - by.body.global_position, true)
	by.combat.request_light()


func _on_about_to_take_damage(event: DamageEvent) -> void:
	var m := 1.0
	for tag in event.tags:
		m *= float(definition.tag_multipliers.get(tag, 1.0))
	event.amount *= m


func _on_damage_taken(event: DamageEvent) -> void:
	if definition.hit_sound:
		_audio.stream = definition.hit_sound
		_audio.pitch_scale = randf_range(0.9, 1.1)
		_audio.play()
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


var _last_hit_from := Vector3.FORWARD


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


func _restart_tween() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()


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
			offset = Vector3.FORWARD.rotated(Vector3.UP, TAU * i / definition.yield_count + randf()) * 1.3
		parent.add_child(body)
		body.global_position = global_position + offset + Vector3.UP * (0.6 + i * 0.1)
		body.rotation.y = randf() * TAU
		body.visible = false
		body.freeze = true
		drops.append(body)
	return drops


func _set_depleted(value: bool) -> void:
	_is_depleted = value
	interactable.enabled = not value
	if _depleted_model:
		_depleted_model.visible = value
	if value:
		_respawn_left = definition.respawn_seconds
		set_process(definition.respawn_seconds > 0.0)
		# Stumps are short: shrink the blocking collider.
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = true
	else:
		set_process(false)
		for child in get_children():
			if child is CollisionShape3D:
				child.disabled = false


func _process(delta: float) -> void:
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_replenish()


func _replenish(animate := true) -> void:
	_set_depleted(false)
	health.set_current(health.max_health)
	_pivot.quaternion = Quaternion.IDENTITY
	_restart_tween()
	if animate:
		_pivot.scale = Vector3.ONE * 0.01
		_anim_tween.tween_property(_pivot, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK)
	else:
		_pivot.scale = Vector3.ONE


# --- persistence --------------------------------------------------------------

func get_save_id() -> String:
	return "resource:%s" % get_path()


func save_state() -> Dictionary:
	return {"health": health.current, "depleted": _is_depleted, "respawn_left": _respawn_left}


func load_state(state: Dictionary) -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	if state.get("depleted", false):
		health.current = 0.0
		_set_depleted(true)
		_pivot.quaternion = Quaternion.IDENTITY
		_pivot.scale = Vector3.ONE * 0.01
		_respawn_left = float(state.get("respawn_left", definition.respawn_seconds))
	else:
		_replenish(false)
		health.set_current(float(state.get("health", health.max_health)))
