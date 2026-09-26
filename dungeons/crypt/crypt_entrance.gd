extends Node3D
## The crypt's surface ruin: the bright dungeon kit is weathered into old,
## mossy stone so it sits in the storybook overworld.

const RUIN_PARTS: Array[StringName] = [&"Floor", &"BackDoor", &"WallLeft", &"WallRight",
	&"PillarL", &"PillarR", &"PillarBL", &"PillarBR", &"Banner"]


func _ready() -> void:
	for part in RUIN_PARTS:
		var n := get_node_or_null(NodePath(part))
		if n:
			StorybookPalette.apply(n, 0.85)
	for n in get_children():
		if String(n.name).begins_with("Rubble"):
			StorybookPalette.apply(n, 0.85)
	# In daylight the torches glow but barely light the stone.
	for torch in [get_node_or_null(^"TorchL"), get_node_or_null(^"TorchR")]:
		var light := torch.get_node_or_null(^"Light") as OmniLight3D if torch else null
		if light:
			light.omni_range = 4.0
			if light.has_method(&"set_base_energy"):
				light.set_base_energy(0.5)
			else:
				light.light_energy = 0.5
