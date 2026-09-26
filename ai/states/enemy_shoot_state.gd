extends EnemyState
## Ranged monsters (EnemyDefinition.attack_state = "Shoot"): hold at range
## with a clear line of fire, shoot between cooldowns, and back off when
## rushed. They don't take melee attack slots.

const BACK_OFF := 4.0

var _cooldown := 0.0


func enter(_message: Dictionary) -> void:
	ai.stop_moving()
	_cooldown = randf_range(0.4, 0.9)


func exit() -> void:
	ai.motor.set_facing_lock(&"ai", false)


func tick(delta: float) -> void:
	if not ai.has_valid_target() or (ai.distance_from_home() > ai.definition.leash_range and not ai.is_provoked()):
		transition(&"Return")
		return
	var d := ai.distance_to_target()
	if d > ai.definition.attack_range + 2.0 or not Targeting.has_line_of_sight(ai.combat, ai.target):
		transition(&"Chase")  # close in / regain sight (and give up if it can't)
		return
	ai.motor.set_facing_lock(&"ai", true)
	ai.face_target()
	if d < BACK_OFF:
		# Back away along the navmesh (not into a wall or a corner).
		var away := NavSteering.flat(ai.body.global_position - ai.target.global_position()).normalized()
		var goal := ai.body.global_position + away * 5.0
		var map := ai.body.get_world_3d().navigation_map
		if NavSteering.is_map_ready(map):
			goal = NavigationServer3D.map_get_closest_point(map, goal)
		ai.move_to(goal, CharacterMotor.Gait.WALK)
	else:
		ai.stop_moving()
	_cooldown -= delta
	if ai.try_ability():
		return
	if _cooldown <= 0.0 and ai.combat.state == CombatController.CombatState.READY:
		ai.combat.request_light()
		var c := ai.definition.attack_cooldown
		_cooldown = randf_range(c.x, c.y)
