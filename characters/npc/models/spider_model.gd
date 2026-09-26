class_name SpiderModel
extends Node3D
## A giant crypt spider built from primitives, with procedurally keyed
## animations (the art kit has no spider). It exposes the same clip names
## as the KayKit rigs, so it plugs into CharacterAnimator, CombatController
## and EnemyDefinition like any other monster body. Faces +Z.

const LEGS_PER_SIDE := 4
## Hip positions along the body (front to back) and how far each leg spreads.
const HIP_Z: Array[float] = [0.36, 0.2, 0.04, -0.12]
const SPREAD: Array[float] = [0.75, 0.3, -0.2, -0.65]

var _body: Node3D
var _legs: Array[Node3D] = []  # hip pivots; even = right, odd = left
var _player: AnimationPlayer

## Shared by every spider: materials and the animation library (the leg
## node names are identical, so the tracks fit any instance).
static var _materials: Dictionary = {}
static var _library: AnimationLibrary


func _init() -> void:
	_build_body()
	_build_animations()


# --- body ----------------------------------------------------------------------------------

func _build_body() -> void:
	if _materials.is_empty():
		_materials = {
			"dark": _material(Color(0.1, 0.085, 0.11), 0.55),
			"leg": _material(Color(0.16, 0.12, 0.13), 0.7),
			"mark": _material(Color(0.55, 0.05, 0.04), 0.4, Color(0.6, 0.05, 0.02), 0.6),
			"eye": _material(Color(1.0, 0.15, 0.1), 0.2, Color(1.0, 0.1, 0.05), 3.0),
		}
	var dark: Material = _materials["dark"]
	var leg_mat: Material = _materials["leg"]
	var mark: Material = _materials["mark"]
	var eye: Material = _materials["eye"]
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, 0.55, 0)
	add_child(_body)
	_sphere(_body, 0.28, Vector3(0, 0, 0.22), Vector3(1.0, 0.75, 1.1), dark)
	_sphere(_body, 0.44, Vector3(0, 0.14, -0.42), Vector3(0.95, 0.8, 1.2), dark)
	_sphere(_body, 0.2, Vector3(0, 0.47, -0.42), Vector3(0.8, 0.12, 1.5), mark)
	for x in [-1.0, 1.0]:
		_sphere(_body, 0.045, Vector3(0.07 * x, 0.1, 0.49), Vector3.ONE, eye)
		_sphere(_body, 0.035, Vector3(0.14 * x, 0.07, 0.45), Vector3.ONE, eye)
		_segment(_body, Vector3(0.07 * x, -0.04, 0.46), Vector3(0.04 * x, -0.24, 0.56), 0.035, 0.005, leg_mat)
	for i in LEGS_PER_SIDE:
		for side in [1.0, -1.0]:
			var hip := Node3D.new()
			hip.name = "Leg_%d_%s" % [i, "R" if side > 0.0 else "L"]
			hip.position = Vector3(0.18 * side, 0.0, HIP_Z[i])
			hip.set_meta(&"side", side)
			hip.set_meta(&"index", i)
			_body.add_child(hip)
			var knee := Vector3(0.55 * side, 0.32, SPREAD[i] * 0.55)
			var foot := Vector3(0.95 * side, -0.55, SPREAD[i])
			_segment(hip, Vector3.ZERO, knee, 0.05, 0.04, leg_mat)
			_segment(hip, knee, foot, 0.04, 0.012, leg_mat)
			_sphere(hip, 0.055, knee, Vector3.ONE, leg_mat)
			_legs.append(hip)


func _material(color: Color, rough: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _sphere(parent: Node3D, radius: float, pos: Vector3, scl: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	s.material = mat
	mi.mesh = s
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)


## A tapered cylinder from `a` to `b`.
func _segment(parent: Node3D, a: Vector3, b: Vector3, r_a: float, r_b: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var length := a.distance_to(b)
	c.height = length
	c.bottom_radius = r_a
	c.top_radius = r_b
	c.radial_segments = 6
	c.rings = 1
	c.material = mat
	mi.mesh = c
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, up, side.cross(up))
	mi.position = (a + b) * 0.5
	parent.add_child(mi)


# --- animations -------------------------------------------------------------------------------

func _build_animations() -> void:
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	if _library == null:
		_library = _make_library()
	_player.add_animation_library(&"", _library)


func _make_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idle := _gait(1.6, 0.04, 0.03, 0.02)
	var walk := _gait(0.7, 0.3, 0.3, 0.04)
	var run := _gait(0.42, 0.42, 0.4, 0.06)
	lib.add_animation(&"Idle", idle)
	lib.add_animation(&"Jump_Idle", idle)
	lib.add_animation(&"Walking_A", walk)
	lib.add_animation(&"Walking_Backwards", walk)
	lib.add_animation(&"Running_A", run)
	lib.add_animation(&"Running_B", run)
	lib.add_animation(&"Running_Strafe_Left", run)
	lib.add_animation(&"Running_Strafe_Right", run)
	lib.add_animation(&"Spider_Bite", _bite())
	lib.add_animation(&"Spider_Leap", _leap())
	lib.add_animation(&"Hit_A", _flinch(1.0))
	lib.add_animation(&"Hit_B", _flinch(-1.0))
	lib.add_animation(&"Death_A", _death())
	lib.add_animation(&"Spawn_Drop", _spawn_drop())
	return lib


func _leg_path(leg: Node3D) -> NodePath:
	return NodePath("Body/%s:rotation" % leg.name)


## Alternating tetrapod gait: legs swing forward while lifted.
func _gait(length: float, swing: float, lift: float, bob: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var steps := 8
	var body := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(body, "Body:position")
	for k in steps + 1:
		var t := float(k) / steps
		a.track_insert_key(body, t * length, Vector3(0, 0.55 + sin(t * TAU * 2.0) * bob, 0))
	for leg in _legs:
		var side: float = leg.get_meta(&"side")
		var i: int = leg.get_meta(&"index")
		var group := (i + (0 if side > 0.0 else 1)) % 2
		var track := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(track, _leg_path(leg))
		for k in steps + 1:
			var t := float(k) / steps
			var p := t * TAU + group * PI
			var y := -side * swing * sin(p)
			var z := side * lift * maxf(0.0, cos(p))
			a.track_insert_key(track, t * length, Vector3(0, y, z))
	return a


func _pose_track(a: Animation, keys: Array, leg_filter: Callable, pose: Callable) -> void:
	for leg in _legs:
		if not leg_filter.call(leg):
			continue
		var track := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(track, _leg_path(leg))
		for k in keys:
			a.track_insert_key(track, k[0], pose.call(leg, k[1]))


func _body_track(a: Animation, keys: Array) -> void:
	var track := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(track, "Body:position")
	for k in keys:
		a.track_insert_key(track, k[0], k[1])


func _bite() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	_body_track(a, [[0.0, Vector3(0, 0.55, 0)], [0.28, Vector3(0, 0.66, -0.14)],
		[0.42, Vector3(0, 0.5, 0.38)], [0.9, Vector3(0, 0.55, 0)]])
	var front := func(leg): return leg.get_meta(&"index") == 0
	_pose_track(a, [[0.0, 0.0], [0.28, 1.0], [0.42, 0.2], [0.9, 0.0]], front,
		func(leg, w): return Vector3(0, -leg.get_meta(&"side") * 0.3 * w, leg.get_meta(&"side") * 0.9 * w))
	return a


func _leap() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	_body_track(a, [[0.0, Vector3(0, 0.55, 0)], [0.25, Vector3(0, 0.4, -0.1)],
		[0.5, Vector3(0, 0.95, 0.3)], [0.75, Vector3(0, 0.5, 0.2)], [1.0, Vector3(0, 0.55, 0)]])
	_pose_track(a, [[0.0, 0.0], [0.25, -0.4], [0.5, 0.8], [0.75, 0.1], [1.0, 0.0]], func(_l): return true,
		func(leg, w): return Vector3(0, 0, leg.get_meta(&"side") * 0.5 * w))
	return a


func _flinch(dir: float) -> Animation:
	var a := Animation.new()
	a.length = 0.35
	_body_track(a, [[0.0, Vector3(0, 0.55, 0)], [0.08, Vector3(0.06 * dir, 0.6, -0.16)], [0.35, Vector3(0, 0.55, 0)]])
	return a


func _death() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	_body_track(a, [[0.0, Vector3(0, 0.55, 0)], [0.3, Vector3(0, 0.7, 0)], [0.7, Vector3(0, 0.2, 0)], [1.0, Vector3(0, 0.18, 0)]])
	# Legs curl up over the body.
	_pose_track(a, [[0.0, 0.0], [0.4, 0.4], [1.0, 1.0]], func(_l): return true,
		func(leg, w): return Vector3(0, 0, leg.get_meta(&"side") * 1.25 * w))
	return a


## Drops from the ceiling on a thread (used by spawns).
func _spawn_drop() -> Animation:
	var a := Animation.new()
	a.length = 0.9
	_body_track(a, [[0.0, Vector3(0, 2.0, 0)], [0.45, Vector3(0, 0.45, 0)], [0.6, Vector3(0, 0.62, 0)], [0.9, Vector3(0, 0.55, 0)]])
	_pose_track(a, [[0.0, 1.0], [0.45, 0.0], [0.9, 0.0]], func(_l): return true,
		func(leg, w): return Vector3(0, 0, leg.get_meta(&"side") * 0.8 * w))
	return a
