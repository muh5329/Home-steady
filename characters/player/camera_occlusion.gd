class_name CameraOcclusion
extends Node
## Fades large props (tree canopies, later buildings) that come between
## the camera and the player. Props opt in by joining GROUP and setting
## metadata "fade_center" (local Vector3) and "fade_radius" (float).

const GROUP := &"camera_fade"
const FADED := 0.72
const CHECK_SECONDS := 0.1

@export var camera: Camera3D
@export var target: Node3D
@export var target_height := 1.2

var _fading: Dictionary = {}  # Node3D -> current transparency
var _timer := 0.0
var _wanted: Dictionary = {}


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = CHECK_SECONDS
		_wanted = _find_occluders()
	# Ease every tracked prop toward its wanted transparency.
	for node in _wanted:
		if not _fading.has(node):
			_fading[node] = 0.0
	for node in _fading.keys():
		if not is_instance_valid(node):
			_fading.erase(node)
			continue
		var goal := FADED if _wanted.has(node) else 0.0
		var value := move_toward(_fading[node], goal, delta * 3.0)
		_fading[node] = value
		_apply(node, value)
		if value == 0.0 and goal == 0.0:
			_fading.erase(node)


func _find_occluders() -> Dictionary:
	var found := {}
	if camera == null or target == null:
		return found
	var a := camera.global_position
	var b := target.global_position + Vector3.UP * target_height
	var ab := b - a
	var len_sq := maxf(ab.length_squared(), 0.001)
	for node: Node3D in get_tree().get_nodes_in_group(GROUP):
		if not node.is_visible_in_tree():
			continue
		var center: Vector3 = node.to_global(node.get_meta(&"fade_center", Vector3.ZERO))
		var radius: float = node.get_meta(&"fade_radius", 1.5)
		var t_raw := (center - a).dot(ab) / len_sq
		# Skip props clearly behind the player; a canopy the player stands
		# under still counts even if its centre projects slightly past them.
		if t_raw > 1.0 + radius / sqrt(len_sq):
			continue
		var t := clampf(t_raw, 0.0, 1.0)
		if center.distance_to(a + ab * t) < radius:
			found[node] = true
	return found


static func _apply(node: Node3D, value: float) -> void:
	for mesh: GeometryInstance3D in node.find_children("*", "GeometryInstance3D", true, false):
		mesh.transparency = value
