extends WorkerState
## Carries the held item to the nearest receiver that accepts it.

var _receiver: Interactable


func enter(_message: Dictionary) -> void:
	_receiver = null
	var item := worker.carry.carrying
	worker.set_activity("Hauling %s" % item.display_name().to_lower() if item else "Hauling")


func exit() -> void:
	worker.steering.stop()


func tick(_delta: float) -> void:
	var item := worker.carry.carrying
	if item == null:
		transition(&"Idle")
		return
	if _receiver == null or not is_instance_valid(_receiver) or not _receiver.can_accept(item) \
			or worker.is_blacklisted(_receiver):
		_receiver = worker.settlement().find_receiver_for(item, worker.body.global_position, worker.should_skip)
		if _receiver == null:
			worker.set_activity("Idle — nowhere to store %s" % item.display_name().to_lower())
			worker.steering.move_to(worker.home_position, CharacterMotor.Gait.WALK)
			return
	var target := _receiver.global_position
	if worker.is_near(target, _receiver.approach_radius):
		worker.steering.stop()
		if worker.carry.deposit(_receiver):
			# More produce may still lie where we worked.
			transition(&"Collect", {"near": worker.last_work_position, "radius": 9.0})
		else:
			_receiver = null
	elif worker.is_stuck(target):
		worker.blacklist(_receiver)
		_receiver = null
	else:
		worker.approach(target)
