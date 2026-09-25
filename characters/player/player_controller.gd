class_name PlayerController
extends Node
## Translates player input into requests on shared components. Contains no
## movement, combat or animation logic of its own.

@export var motor: CharacterMotor
@export var combat: CombatController
@export var interaction: InteractionController
@export var camera_rig: CameraRig
## Attacks snap toward enemies inside this range and cone.
@export var aim_assist_range := 3.2
@export var aim_assist_min_dot := 0.35

var input_enabled := true


func _ready() -> void:
	process_physics_priority = -10  # before combat and motor
	combat.aim_provider = _aim_direction
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

	if interaction.is_carrying():
		combat.set_block(false)
		if Input.is_action_just_pressed(&"attack_light"):
			interaction.throw()
		if Input.is_action_just_pressed(&"dodge") and not interaction.is_carrying_heavy():
			combat.request_dodge(move)
		return

	combat.set_block(Input.is_action_pressed(&"block"))
	if Input.is_action_just_pressed(&"attack_light"):
		combat.request_light()
	if Input.is_action_just_pressed(&"attack_heavy"):
		combat.request_heavy()
	if Input.is_action_just_pressed(&"dodge"):
		combat.request_dodge(move)


func _move_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	return camera_rig.flat_right() * input.x + camera_rig.flat_forward() * input.y


func _gait(move: Vector3) -> CharacterMotor.Gait:
	if Input.is_action_pressed(&"walk"):
		return CharacterMotor.Gait.WALK
	if Input.is_action_pressed(&"sprint") and move.length() > 0.5 and not interaction.is_carrying_heavy():
		return CharacterMotor.Gait.SPRINT
	return CharacterMotor.Gait.RUN


## Aim: nearest enemy in front, else the stick/keys direction, else facing.
func _aim_direction() -> Vector3:
	var target := combat.find_nearest_hostile(aim_assist_range, motor.get_facing(), aim_assist_min_dot)
	if target == null:
		target = combat.find_nearest_hostile(aim_assist_range * 0.6)
	if target:
		return target.global_position() - motor.body.global_position
	var move := _move_direction()
	return move if move.length_squared() > 0.01 else Vector3.ZERO


func _on_attack_hit(event: DamageEvent) -> void:
	camera_rig.add_trauma(0.45 if event.has_tag("heavy") else 0.22)
