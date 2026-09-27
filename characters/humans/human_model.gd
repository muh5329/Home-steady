class_name HumanModel
extends Node3D
## A realistic-proportion humanoid body (Quaternius CC0 modular characters,
## built by tools/build_humans). The bodies ship without clips; they all
## share one animation library, loaded once and added here, whose clips use
## the game's existing clip names (Idle, Running_A, 1H_Melee_Attack_Chop…).

const ANIMS := "res://art/third_party/quaternius/humans/human_anims.glb"

static var _library: AnimationLibrary


func _ready() -> void:
	var body := get_child(0)
	var player := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		body.add_child(player)
		player.root_node = player.get_path_to(body)
	if not player.has_animation_library(&""):
		player.add_animation_library(&"", shared_library())
	for mesh: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Crowds of the same body (villagers, undead) get a slightly different
	# dye and wear each, so a group doesn't read as clones. The hero keeps
	# their colours.
	if find_parent("Player") == null:
		_vary_clothes()


const CLOTH_TINTS := [Color(1, 1, 1), Color(1.0, 0.9, 0.82), Color(0.88, 0.94, 1.0), Color(0.94, 1.0, 0.88), Color(0.82, 0.8, 0.78), Color(1.05, 0.98, 0.92)]


func _vary_clothes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	var tint: Color = CLOTH_TINTS[rng.randi() % CLOTH_TINTS.size()]
	tint = tint * rng.randf_range(0.9, 1.06)
	tint.a = 1.0
	if tint.is_equal_approx(Color.WHITE):
		return
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var n := m.resource_name
			if "Eyes" in n or "Hair" in n or "Regular" in n:
				continue
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = m.albedo_color * tint
			mi.set_surface_override_material(i, d)


static func shared_library() -> AnimationLibrary:
	if _library == null:
		var source: Node = (load(ANIMS) as PackedScene).instantiate()
		var src_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_library = src_player.get_animation_library(&"")
		source.free()
	return _library
