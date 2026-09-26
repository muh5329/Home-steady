extends OmniLight3D
## Cheap fire flicker: smooth noise on energy. Each torch gets its own
## phase so a corridor of torches doesn't pulse in sync.

@export var amount := 0.25
@export var speed := 7.0

var _base := 0.0
var _t := 0.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = _base * (1.0 + amount * (sin(_t) * 0.5 + sin(_t * 2.3 + 1.7) * 0.3 + sin(_t * 5.1) * 0.2))
