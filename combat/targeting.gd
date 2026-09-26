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


## Nearest hostile within `max_distance` that `from` can see (no noticing
## anyone through walls, but a hidden nearest one doesn't mask a visible
## one further away).
static func nearest_visible_hostile(from: CombatController, max_distance: float,
		around := Vector3.INF) -> CombatController:
	var origin := from.global_position() if around == Vector3.INF else around
	var candidates: Array = []
	for node in from.get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == from or not other.is_alive() or not from.is_hostile_to(other):
			continue
		var d := NavSteering.flat(other.global_position() - origin).length()
		if d <= max_distance:
			candidates.append([d, other])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for c in candidates:
		if has_line_of_sight(from, c[1]):
			return c[1]
	return null


## Nearest living combatant hostile to `from`, measured from `point`
## (companions look for threats around the player they protect).
static func nearest_hostile_around(from: CombatController, point: Vector3, radius: float) -> CombatController:
	var best: CombatController = null
	var best_d := radius
	for node in from.get_tree().get_nodes_in_group(CombatController.GROUP):
		var other := node as CombatController
		if other == from or not other.is_alive() or not from.is_hostile_to(other):
			continue
		var d := NavSteering.flat(other.global_position() - point).length()
		if d <= best_d:
			best = other
			best_d = d
	return best


## True if nothing solid (physics layer 1) blocks the line between two
## combatants' aim points.
static func has_line_of_sight(from: CombatController, to: CombatController) -> bool:
	var space := from.body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(aim_point(from), aim_point(to), 1)
	return space.intersect_ray(q).is_empty()
