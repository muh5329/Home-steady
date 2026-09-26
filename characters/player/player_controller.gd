class_name PlayerController
extends Node
## Translates player input into requests on shared components. Contains no
## movement, combat or animation logic of its own.

@export var motor: CharacterMotor
@export var combat: CombatController
@export var interaction: InteractionController
@export var camera_rig: CameraRig
@export var equipment: EquipmentController
@export var abilities: AbilityController
@export var aim_assist_min_dot := 0.35
## Ranged weapons assist inside a narrower cone around the camera.
@export var ranged_assist_min_dot := 0.9

var input_enabled := true
## Off while a tool (build mode) uses the attack/block buttons.
var combat_input_enabled := true


func _ready() -> void:
	process_physics_priority = -10  # before combat and motor
	combat.aim_provider = _aim_direction
	combat.aim_point_provider = _aim_point
	combat.attack_hit.connect(_on_attack_hit)
	combat.staggered.connect(func(): camera_rig.add_trauma(0.35))
	interaction.carrying_changed.connect(func(item): camera_rig.extra_distance = 1.2 if item else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not input_enabled or not combat.is_alive():
		motor.stop()
		combat.set_block(false)
		return

	var move := _move_direction()
	motor.set_move_input(move, _gait(move))

	if Input.is_action_just_pressed(&"jump") and combat.can_move():
		motor.request_jump()
	if Input.is_action_just_pressed(&"interact"):
		interaction.interact()
	if Input.is_action_just_pressed(&"drop"):
		interaction.drop()

	if not combat_input_enabled:
		combat.set_block(false)
		return

	if interaction.is_carrying():
		combat.set_block(false)
		if Input.is_action_just_pressed(&"attack_light"):
			interaction.throw()
		if Input.is_action_just_pressed(&"dodge") and not interaction.is_carrying_heavy():
			combat.request_dodge(move)
		return

	# Weapons that can't block use the button to aim instead.
	var can_block := combat.moveset != null and combat.moveset.can_block
	combat.set_block(can_block and Input.is_action_pressed(&"block"))
	_set_aiming(not can_block and Input.is_action_pressed(&"block") and combat.can_move())
	if Input.is_action_just_pressed(&"attack_light"):
		combat.request_light()
	if Input.is_action_just_pressed(&"attack_heavy"):
		combat.request_heavy()
	if Input.is_action_just_pressed(&"dodge"):
		combat.request_dodge(move)
	if Input.is_action_just_pressed(&"ability_1"):
		abilities.use(0)


func _move_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	return camera_rig.flat_right() * input.x + camera_rig.flat_forward() * input.y


func _gait(move: Vector3) -> CharacterMotor.Gait:
	if Input.is_action_pressed(&"walk"):
		return CharacterMotor.Gait.WALK
	if Input.is_action_pressed(&"sprint") and move.length() > 0.5 and not interaction.is_carrying_heavy():
		return CharacterMotor.Gait.SPRINT
	return CharacterMotor.Gait.RUN


var aiming := false


## Ranged aim mode: zoomed shoulder camera, walk, strafe facing the reticle.
func _set_aiming(on: bool) -> void:
	aiming = on
	camera_rig.aiming = on
	motor.set_facing_lock(&"aim", on)
	motor.set_speed_modifier(&"aim", 0.5 if on else 1.0)
	if on:
		motor.face(camera_rig.flat_forward())


func _aim_range() -> float:
	return equipment.weapon.aim_range if equipment and equipment.weapon else 3.2


func _is_ranged() -> bool:
	return _aim_range() > 6.0


## Melee: nearest enemy in front, else the stick/keys direction.
## Ranged: where the camera looks, snapping to an enemy near that line.
func _aim_direction() -> Vector3:
	var target := _assist_target()
	if target:
		return target.global_position() - motor.body.global_position
	if _is_ranged():
		return camera_rig.flat_forward()
	var move := _move_direction()
	return move if move.length_squared() > 0.01 else Vector3.ZERO


func _assist_target() -> CombatController:
	if _is_ranged():
		return _ranged_assist_target()
	var target := combat.find_nearest_hostile(_aim_range(), motor.get_facing(), aim_assist_min_dot)
	if target == null:
		target = combat.find_nearest_hostile(_aim_range() * 0.6)
	return target


## Ranged assist: the visible hostile closest to the reticle (by angle),
## within range and a narrow cone around the camera's view.
func _ranged_assist_target() -> CombatController:
	var cam := camera_rig.camera
	var eye := cam.global_position
	var view := -cam.global_basis.z
	var best: CombatController = null
	var best_dot := ranged_assist_min_dot
	var space := motor.body.get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == combat or not other.is_alive() or not combat.is_hostile_to(other):
			continue
		var point := Targeting.aim_point(other)
		if point.distance_to(motor.body.global_position) > _aim_range():
			continue
		var dot := view.dot((point - eye).normalized())
		if dot <= best_dot:
			continue
		var los := PhysicsRayQueryParameters3D.create(eye, point, 1)  # world only
		if not space.intersect_ray(los).is_empty():
			continue
		best_dot = dot
		best = other
	return best


## Where shots go: the assisted target's chest, otherwise whatever is under
## the reticle (camera-centre ray), so aiming works with camera pitch too.
func _aim_point() -> Variant:
	var target := _assist_target()
	if target:
		return Targeting.aim_point(target)
	var cam := camera_rig.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * 80.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | DamageReceiver.LAYER,
		[motor.body.get_rid(), combat.receiver.get_rid()])
	query.collide_with_areas = true
	var hit := motor.body.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else to


## For the HUD reticle.
func is_ranged() -> bool:
	return _is_ranged()


func has_assist_target() -> bool:
	return _is_ranged() and _ranged_assist_target() != null


func _on_attack_hit(event: DamageEvent) -> void:
	camera_rig.add_trauma(0.45 if event.has_tag("heavy") else 0.22)
