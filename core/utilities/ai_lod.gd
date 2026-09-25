class_name AiLod
## Distance-based AI update rates (spec: high frequency near the player,
## medium for active characters, low for distant simulation).


## Seconds between "think" ticks for an actor at `position`.
static func think_interval(tree: SceneTree, position: Vector3) -> float:
	var player := tree.get_first_node_in_group(&"player") as Node3D
	if player == null:
		return 0.5
	var d := position.distance_to(player.global_position)
	if d < 25.0:
		return 0.1
	if d < 60.0:
		return 0.35
	return 1.0
