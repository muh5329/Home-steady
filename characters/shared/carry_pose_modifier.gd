class_name CarryPoseModifier
extends SkeletonModifier3D
## Overrides upper-body bones with a pose sampled from an existing clip so
## a character can hold something while its legs keep running.
## Blend in/out through the built-in `influence` property.

@export var source_animation: StringName = &"2H_Ranged_Aiming"
## Time (seconds) in the source clip to sample the pose from.
@export var source_time := 0.3
@export var bones: PackedStringArray = [
	"upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
]
@export var blend_speed := 8.0

var holding := false

var _pose: Dictionary = {}  # bone index -> Quaternion


func _ready() -> void:
	influence = 0.0


## Samples the pose from `player`'s clip. Call once after the model loads.
func setup(anim_player: AnimationPlayer) -> void:
	_pose.clear()
	var skeleton := get_skeleton()
	if skeleton == null or not anim_player.has_animation(source_animation):
		push_warning("CarryPoseModifier: cannot sample '%s'" % source_animation)
		return
	var anim := anim_player.get_animation(source_animation)
	for bone_name in bones:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			if String(anim.track_get_path(track)).ends_with(":" + bone_name):
				_pose[bone] = anim.rotation_track_interpolate(track, source_time)
				break


func _process(delta: float) -> void:
	var target := 1.0 if holding else 0.0
	influence = move_toward(influence, target, blend_speed * delta)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for bone: int in _pose:
		skeleton.set_bone_pose_rotation(bone, _pose[bone])
