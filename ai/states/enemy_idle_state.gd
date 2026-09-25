extends EnemyState
## Stands around home, occasionally wandering, until a hostile is seen.

var _wander_timer := 0.0


func enter(_message: Dictionary) -> void:
	ai.stop_moving()
	_wander_timer = randf_range(2.0, 5.0)


func tick(delta: float) -> void:
	var seen := ai.find_target()
	if seen:
		ai.target = seen
		transition(&"Chase")
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 7.0)
		var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.5, 4.0)
		ai.move_to(ai.home_position + offset, CharacterMotor.Gait.WALK)
