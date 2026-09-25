extends WorkerState
## Runs home after being attacked. The controller remembers the threat, so
## afterwards Idle avoids work near it for a while.

var _time := 0.0


func enter(_message: Dictionary) -> void:
	_time = 6.0
	worker.set_activity("Fleeing!")
	worker.steering.move_to(worker.home_position, CharacterMotor.Gait.SPRINT)


func exit() -> void:
	worker.steering.stop()


func tick(delta: float) -> void:
	_time -= delta
	if _time <= 0.0 or worker.is_near(worker.home_position, 1.5):
		transition(&"Idle")
