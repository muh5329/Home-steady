class_name CameraRig
extends Node3D
## Third-person orbit camera: follows a target with light smoothing,
## yaw/pitch from mouse or right stick, spring-arm collision, zoom and
## trauma-based screen shake.

@export var target: Node3D
@export var height := 1.55
@export var follow_sharpness := 14.0
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
@export var min_pitch := -70.0
@export var max_pitch := 35.0
@export var min_distance := 2.5
@export var max_distance := 8.0
@export var distance := 5.6
## Added to `distance` by gameplay (e.g. carrying a big load).
var extra_distance := 0.0
## Interiors lower the highest allowed pitch (look down more) so the arm
## rises over walls instead of snapping in behind the character.
var max_pitch_override := INF
## Aim mode (ranged): pulled in over the shoulder with a narrower FOV.
var aiming := false
@export var aim_distance := 2.3
@export var aim_shoulder_offset := 0.95
@export var aim_fov := 48.0
var _base_fov := 62.0
## Over-the-shoulder offset keeps the target visible past the character.
@export var shoulder_offset := 0.6
## The character's body: faded out when a wall pushes the camera into it.
@export var fade_root: Node3D
## Arm lengths between which the body fades (fully hidden below the first).
@export var fade_range := Vector2(1.1, 2.0)

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw := 0.0
var pitch := -24.0
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0
var _shoulder := 0.6
var _fade_meshes: Array[GeometryInstance3D] = []
var _fade := 0.0


func _ready() -> void:
	top_level = true
	_noise.frequency = 2.0
	if target:
		global_position = target.global_position + Vector3.UP * height
		yaw = target.global_rotation_degrees.y
	spring_arm.spring_length = distance
	_base_fov = camera.fov
	spring_arm.collision_mask = 1  # world only
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		yaw -= rad_to_deg(event.relative.x * mouse_sensitivity)
		pitch -= rad_to_deg(event.relative.y * mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - 0.4, min_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + 0.4, max_distance)


## Screen shake. Amount accumulates and decays; 1.0 is a big hit.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Jump straight to the target (teleports, respawns, loading): no swoop.
func snap() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height
	spring_arm.spring_length = aim_distance if aiming else distance + extra_distance
	_apply_rotation()


## Camera-relative horizontal basis for movement input.
func flat_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(yaw))


func flat_right() -> Vector3:
	return Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(yaw))


func _process(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	yaw -= look.x * stick_sensitivity * 60.0 * delta
	pitch -= look.y * stick_sensitivity * 40.0 * delta
	if target:
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * delta))
	var goal_length := aim_distance if aiming else distance + extra_distance
	spring_arm.spring_length = lerpf(spring_arm.spring_length, goal_length, 1.0 - exp(-8.0 * delta))
	camera.fov = lerpf(camera.fov, aim_fov if aiming else _base_fov, 1.0 - exp(-10.0 * delta))
	_shoulder = lerpf(_shoulder, aim_shoulder_offset if aiming else shoulder_offset, 1.0 - exp(-10.0 * delta))
	_apply_rotation()
	_apply_shake(delta)
	_update_body_fade()
	if target:
		RenderingServer.global_shader_parameter_set(&"player_position", target.global_position + Vector3.UP)


## A wall behind the player pulls the camera in; rather than filling the
## screen with the back of a helmet, the body fades out.
func _update_body_fade() -> void:
	if fade_root == null:
		return
	var length := spring_arm.get_hit_length()
	var fade := 1.0 - clampf((length - fade_range.x) / (fade_range.y - fade_range.x), 0.0, 1.0)
	if is_equal_approx(fade, _fade):
		return
	_fade = fade
	if _fade_meshes.is_empty() or not is_instance_valid(_fade_meshes[0]) or not _fade_meshes[0].is_inside_tree():
		_fade_meshes.clear()
		for m in fade_root.find_children("*", "GeometryInstance3D", true, false):
			_fade_meshes.append(m)
	for m in _fade_meshes:
		if is_instance_valid(m):
			m.transparency = fade * 0.85


func _apply_rotation() -> void:
	# Aiming needs the full range (free-aimed shots at distant targets).
	var top := max_pitch if aiming else minf(max_pitch, max_pitch_override)
	pitch = clampf(pitch, min_pitch, top)
	rotation_degrees = Vector3(pitch, yaw, 0.0)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(_trauma - 1.8 * delta, 0.0)
	var s := _trauma * _trauma
	_noise_t += delta * 60.0
	camera.h_offset = _shoulder + _noise.get_noise_2d(_noise_t, 0.0) * 0.25 * s
	camera.v_offset = _noise.get_noise_2d(0.0, _noise_t) * 0.25 * s
	camera.rotation.z = _noise.get_noise_2d(_noise_t, _noise_t) * 0.04 * s
