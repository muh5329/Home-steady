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
@export var distance := 4.6
## Added to `distance` by gameplay (e.g. carrying a big load).
var extra_distance := 0.0
## Over-the-shoulder offset keeps the target visible past the character.
@export var shoulder_offset := 0.6

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var yaw := 0.0
var pitch := -20.0
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_t := 0.0


func _ready() -> void:
	top_level = true
	_noise.frequency = 2.0
	if target:
		global_position = target.global_position + Vector3.UP * height
		yaw = target.global_rotation_degrees.y
	spring_arm.spring_length = distance
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
	spring_arm.spring_length = lerpf(spring_arm.spring_length, distance + extra_distance, 1.0 - exp(-6.0 * delta))
	_apply_rotation()
	_apply_shake(delta)


func _apply_rotation() -> void:
	pitch = clampf(pitch, min_pitch, max_pitch)
	rotation_degrees = Vector3(pitch, yaw, 0.0)


func _apply_shake(delta: float) -> void:
	_trauma = maxf(_trauma - 1.8 * delta, 0.0)
	var s := _trauma * _trauma
	_noise_t += delta * 60.0
	camera.h_offset = shoulder_offset + _noise.get_noise_2d(_noise_t, 0.0) * 0.25 * s
	camera.v_offset = _noise.get_noise_2d(0.0, _noise_t) * 0.25 * s
	camera.rotation.z = _noise.get_noise_2d(_noise_t, _noise_t) * 0.04 * s
