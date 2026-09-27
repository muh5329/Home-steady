class_name AmbientFolk
extends Node3D
## Townsfolk going about their day so streets and quays aren't empty, as in
## the references: each figure either strolls between random points around
## its spot (pausing now and then) or stands chatting, arms folded or
## gesturing. Purely visual: no collision, no navigation, no AI cost beyond
## a straight-line walk.

## Spots: x, z, radius, mode (0 = wander, 1 = stand and chat).
@export var spots: PackedFloat32Array = []
@export var random_seed := 17

const BODIES := ["peasant_m", "peasant_m2", "peasant_f", "noble_m"]
const WALK_SPEED := 1.15

var _folk: Array = []  # [node, anim player, home Vector3, radius, mode, target, wait]
var _rng := RandomNumberGenerator.new()
## Decks and quays are built over the first frames; keep re-grounding
## everyone until they exist.
var _settle := 2.0


func _ready() -> void:
	_rng.seed = random_seed
	for i in range(0, spots.size(), 4):
		var home := Vector3(spots[i], 0, spots[i + 1])
		var mode := int(spots[i + 3])
		var body: Node3D = load("res://characters/humans/%s.tscn" % BODIES[_rng.randi() % BODIES.size()]).instantiate()
		body.position = home + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
		body.rotation.y = _rng.randf() * TAU
		add_child(body)
		body.position.y = _ground(body.position)
		var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var entry := [body, ap, home, spots[i + 2], mode, body.position, _rng.randf_range(0.0, 3.0)]
		_folk.append(entry)
		if ap:
			ap.play(_idle_clip(mode))
			ap.seek(_rng.randf() * 2.0, true)


func _idle_clip(mode: int) -> StringName:
	if mode == 1:
		return [&"Talking", &"Fold_Arms", &"Idle"][_rng.randi() % 3]
	return &"Idle"


func _process(delta: float) -> void:
	if _settle > 0.0:
		_settle -= delta
		for f in _folk:
			(f[0] as Node3D).position.y = _ground((f[0] as Node3D).position)
	for f in _folk:
		var body: Node3D = f[0]
		var ap: AnimationPlayer = f[1]
		if int(f[4]) == 1 or ap == null:
			continue
		if float(f[6]) > 0.0:
			f[6] = float(f[6]) - delta
			if float(f[6]) <= 0.0:
				# Pick somewhere new nearby and set off.
				var a := _rng.randf() * TAU
				var r := sqrt(_rng.randf()) * float(f[3])
				f[5] = (f[2] as Vector3) + Vector3(cos(a) * r, 0, sin(a) * r)
				ap.play(&"Walking_A", 0.25)
			continue
		var to: Vector3 = (f[5] as Vector3) - body.position
		to.y = 0.0
		if to.length() < 0.15:
			f[6] = _rng.randf_range(2.5, 7.0)
			ap.play(&"Idle", 0.3)
			continue
		var step := minf(WALK_SPEED * delta, to.length())
		body.position += to.normalized() * step
		body.position.y = _ground(body.position)
		var want := atan2(to.x, to.z)
		body.rotation.y = lerp_angle(body.rotation.y, want, minf(delta * 6.0, 1.0))


## Height of whatever they stand on (ground, a wharf deck).
func _ground(at: Vector3) -> float:
	if not is_inside_tree():
		return at.y
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if hit else 0.0
