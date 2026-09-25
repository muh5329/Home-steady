class_name Campfire
extends Node3D
## Flickering fire light. The particles and meshes live in the scene.

@export var light: OmniLight3D
@export var base_energy := 2.2

var _t := 0.0
var _noise := FastNoiseLite.new()


func _process(delta: float) -> void:
	_t += delta * 8.0
	light.light_energy = base_energy * (0.8 + 0.35 * _noise.get_noise_1d(_t))
