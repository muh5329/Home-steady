@tool
class_name FenceRun
extends Path3D
## A run of wooden fence along this path (roadsides, paddocks), with the
## odd gap and lean so it looks hand-built.

const SEGMENT := preload("res://art/props/fence_segment.tscn")
const LENGTH := 2.1

@export var gap_every := 5
@export var random_seed := 1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var total := curve.get_baked_length()
	var d := LENGTH * 0.5
	var i := 0
	while d < total - LENGTH * 0.5:
		i += 1
		if gap_every > 0 and i % gap_every == 0:
			d += LENGTH
			continue
		var p := curve.sample_baked(d)
		var ahead := curve.sample_baked(minf(d + 0.5, total))
		var dir := (ahead - p).normalized()
		var seg: Node3D = SEGMENT.instantiate()
		add_child(seg)
		seg.position = p
		seg.rotation.y = atan2(-dir.z, dir.x) + rng.randf_range(-0.05, 0.05)
		seg.rotation.z = rng.randf_range(-0.04, 0.04)
		d += LENGTH
