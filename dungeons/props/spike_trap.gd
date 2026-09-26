class_name SpikeTrap
extends Node3D
## Floor spikes on a fixed rhythm: a short warning poke, then up and
## deadly, then down. All traps share one clock, so a hall of them rises
## as one: watch the rhythm, then sprint across in the gap. `phase`
## allows staggered patterns later.
## Only the player is hurt: the dead ignore their own traps, and
## companions step where you step.

@export var damage := 18.0
@export var cycle := 3.2
@export var warn_time := 0.5
@export var up_time := 0.8
## Seconds added to the shared clock (alternating rows use cycle / 2).
@export var phase := 0.0
@export var knockback := 4.0

@onready var spikes: Node3D = find_child("spikes", true, false)
@onready var area: Area3D = $Area

var _rest_y := 0.0

## Shared by every trap: knockback into the next tile doesn't hit twice.
static var _hit_cooldown: Dictionary = {}  # receiver instance id -> clock

static var _clock := 0.0
static var _clock_frame := -1


func _ready() -> void:
	if spikes:
		_rest_y = spikes.position.y
		# Stretch the centre spike cluster over the whole tile.
		spikes.scale = Vector3(1.7, 1.0, 1.7)
		spikes.position.y = _rest_y - 2.05


## 0 = down, 1 = warning, 2 = up.
func stage() -> int:
	var t := fposmod(_clock + phase, cycle)
	if t < warn_time:
		return 1
	if t < warn_time + up_time:
		return 2
	return 0


func _physics_process(delta: float) -> void:
	# One shared clock for every trap, advanced once per physics frame.
	var frame := Engine.get_physics_frames()
	if frame != _clock_frame:
		_clock_frame = frame
		_clock += delta
	var s := stage()
	if spikes:
		var target: float = [-2.05, -1.65, -0.6][s]
		spikes.position.y = move_toward(spikes.position.y, _rest_y + target, delta * (18.0 if s == 2 else 5.0))
	if s == 2:
		_hurt_players()


func _hurt_players() -> void:
	for a in area.get_overlapping_areas():
		var r := a as DamageReceiver
		if r == null or not (r.owner is Player):
			continue
		var key := r.get_instance_id()
		if _clock < float(_hit_cooldown.get(key, -1.0)):
			continue
		_hit_cooldown[key] = _clock + 1.2
		var e := DamageEvent.create(self, damage, DamageEvent.Type.PHYSICAL)
		e.poise_damage = 25.0
		e.tags = PackedStringArray(["trap"])
		var push := NavSteering.flat(r.global_position - global_position)
		e.knockback = (push.normalized() if push.length_squared() > 0.01 else Vector3.BACK) * knockback
		r.receive(e)
