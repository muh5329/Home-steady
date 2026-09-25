class_name CharacterAnimator
extends Node
## Drives a rigged model's AnimationPlayer.
##
## Base layer: locomotion chosen from the motor's speed (idle/walk/run/
## sprint/airborne) unless a "base override" loop is set (blocking, dead).
## Action layer: one-shot clips (attacks, dodges, hit reactions) that play
## over the base and hand control back when finished.

signal action_finished(animation: StringName)

@export var model: Node3D
@export var motor: CharacterMotor

@export_group("Locomotion clips")
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walking_A"
@export var run_animation: StringName = &"Running_A"
@export var sprint_animation: StringName = &"Running_B"
@export var air_animation: StringName = &"Jump_Idle"
## Used when the motor's facing is locked (blocking, circling, lock-on).
@export var strafe_left_animation: StringName = &"Running_Strafe_Left"
@export var strafe_right_animation: StringName = &"Running_Strafe_Right"
@export var backward_animation: StringName = &"Walking_Backwards"
## Ground speed (m/s) at which each clip looks correct at 1x playback.
@export var walk_reference_speed := 2.2
@export var run_reference_speed := 5.0
@export var sprint_reference_speed := 7.0
@export var blend_time := 0.18

var player: AnimationPlayer
var skeleton: Skeleton3D

var _action: StringName = &""
var _action_hold := false
## A "soft" action is the leftover tail of a finished gameplay action; it
## yields to locomotion as soon as the character moves.
var _action_soft := false
var _base_override: StringName = &""
var _base_current: StringName = &""
var _freeze_time := 0.0
var _flash_time := 0.0
var _flash_material: ShaderMaterial
var _meshes: Array[MeshInstance3D] = []

const FLASH_SHADER := preload("res://art/VFX/hit_flash.gdshader")


func _ready() -> void:
	player = model.find_child("AnimationPlayer", true, false)
	skeleton = model.find_child("Skeleton3D", true, false)
	assert(player != null, "CharacterAnimator: model has no AnimationPlayer")
	player.animation_finished.connect(_on_animation_finished)
	for clip in [idle_animation, walk_animation, run_animation, sprint_animation, air_animation,
			strafe_left_animation, strafe_right_animation, backward_animation,
			&"Blocking", &"Unarmed_Idle", &"2H_Melee_Idle", &"Idle_Combat"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node)
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	_play_base(idle_animation)


func has_animation(clip: StringName) -> bool:
	return player.has_animation(clip)


func clip_length(clip: StringName) -> float:
	return player.get_animation(clip).length if player.has_animation(clip) else 0.0


## Plays a one-shot clip over locomotion. `hold` keeps the last frame
## (e.g. death) instead of returning to the base layer.
func play_action(clip: StringName, speed := 1.0, blend := 0.08, hold := false) -> void:
	if not player.has_animation(clip):
		push_warning("CharacterAnimator: missing clip '%s'" % clip)
		return
	_action = clip
	_action_hold = hold
	_action_soft = false
	player.play(clip, blend, speed)
	# Restart even if the same clip is already playing (combo repeats).
	player.seek(0.0, true)


func stop_action() -> void:
	if _action == &"":
		return
	_action = &""
	_action_hold = false
	_action_soft = false
	_base_current = &""


## Gameplay no longer depends on the current clip: let it finish unless
## the character starts moving, in which case locomotion takes over.
func soften_action() -> void:
	if _action != &"" and not _action_hold:
		_action_soft = true


func is_action_playing() -> bool:
	return _action != &""


func current_action() -> StringName:
	return _action


## A looping clip that replaces locomotion (blocking, carrying idle, dead).
func set_base_override(clip: StringName) -> void:
	_base_override = clip


## Briefly pauses the animation for impact weight ("hitstop").
func freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)


func flash(duration := 0.12) -> void:
	_flash_time = duration
	for mesh in _meshes:
		mesh.material_overlay = _flash_material


func _process(delta: float) -> void:
	_update_freeze(delta)
	_update_flash(delta)
	if _action_soft and motor and motor.horizontal_speed() > 0.6:
		stop_action()
	if _action != &"":
		return
	_play_base(_choose_base())


func _choose_base() -> StringName:
	if _base_override != &"":
		return _base_override
	if motor == null:
		return idle_animation
	if not motor.is_grounded() and motor.body.velocity.y < -2.0:
		return air_animation
	var speed := motor.horizontal_speed()
	if speed < 0.3:
		return idle_animation
	if motor.lock_facing:
		var v := motor.body.velocity
		var facing := motor.get_facing()
		var right := facing.cross(Vector3.UP)
		var fwd := Vector3(v.x, 0, v.z).dot(facing)
		var side := Vector3(v.x, 0, v.z).dot(right)
		if absf(side) > absf(fwd):
			return strafe_right_animation if side > 0.0 else strafe_left_animation
		if fwd < 0.0:
			return backward_animation
	if speed < (motor.walk_speed + motor.run_speed) * 0.5:
		return walk_animation
	if speed < (motor.run_speed + motor.sprint_speed) * 0.5:
		return run_animation
	return sprint_animation


func _play_base(clip: StringName) -> void:
	var speed_scale := 1.0
	if motor:
		var speed := motor.horizontal_speed()
		match clip:
			walk_animation: speed_scale = clampf(speed / walk_reference_speed, 0.6, 1.5)
			run_animation: speed_scale = clampf(speed / run_reference_speed, 0.7, 1.4)
			sprint_animation: speed_scale = clampf(speed / sprint_reference_speed, 0.8, 1.4)
			strafe_left_animation, strafe_right_animation:
				speed_scale = clampf(speed / run_reference_speed, 0.5, 1.3)
			backward_animation: speed_scale = clampf(speed / walk_reference_speed, 0.6, 1.5)
	# play() on the clip that is already playing only updates its speed.
	_base_current = clip
	player.play(clip, blend_time, speed_scale)


func _update_freeze(delta: float) -> void:
	if _freeze_time > 0.0:
		_freeze_time -= delta
		player.speed_scale = 0.0 if _freeze_time > 0.0 else 1.0


func _update_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		return
	_flash_time -= delta
	if _flash_time <= 0.0:
		for mesh in _meshes:
			mesh.material_overlay = null


func _on_animation_finished(clip: StringName) -> void:
	if clip != _action:
		return
	if _action_hold:
		action_finished.emit(clip)
		return
	_action = &""
	_base_current = &""
	action_finished.emit(clip)
