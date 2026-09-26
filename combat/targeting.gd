class_name Targeting
## Stateless target queries over registered combatants.
## Kept separate from CombatController so perception can later move to
## spatial queries without touching combat logic.


## Where to aim at a combatant: the centre of its hurtbox (chest height).
static func aim_point(target: CombatController) -> Vector3:
	return target.global_position() + Vector3.UP * 1.0


## Nearest living combatant hostile to `from` within `max_distance`.
## If `facing` is non-zero, only targets inside the cone (dot >= min_dot).
static func nearest_hostile(from: CombatController, max_distance: float,
		facing := Vector3.ZERO, min_dot := -1.0) -> CombatController:
	var best: CombatController = null
	var best_d := max_distance
	var origin := from.global_position()
	for node in from.get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == from or not other.is_alive() or not from.is_hostile_to(other):
			continue
		var offset := other.global_position() - origin
		offset.y = 0.0
		var d := offset.length()
		if d > best_d:
			continue
		if facing != Vector3.ZERO and d > 0.01 and offset.normalized().dot(facing) < min_dot:
			continue
		best = other
		best_d = d
	return best
