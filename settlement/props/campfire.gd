class_name Campfire
extends Node3D
## Flickering fire light. The particles and logs live in the scene; the ring
## of hearth stones is the Poly Haven scanned stone fire pit.

@export var light: OmniLight3D
@export var base_energy := 2.2

var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	for c in get_children():
		if String(c.name).begins_with("Stone"):
			c.visible = false
	var pit := PHModels.node("stone_fire_pit")
	pit.name = "FirePit"
	pit.scale = Vector3.ONE * 1.2
	pit.position.y = 0.12
	add_child(pit)


func _process(delta: float) -> void:
	_t += delta * 8.0
	light.light_energy = base_energy * (0.8 + 0.35 * _noise.get_noise_1d(_t))
