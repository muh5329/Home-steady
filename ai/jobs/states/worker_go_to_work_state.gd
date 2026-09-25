extends WorkerState
## Walks to the claimed work target. Gives up (and avoids it for a while)
## if it stops making progress.

var _target: Node3D
var _spot: Vector3
var _handed_over := false


func enter(message: Dictionary) -> void:
	_target = message["target"]
	_handed_over = false
	_spot = _target.work_position(worker.body.global_position)
	worker.set_activity("Heading to work")
	worker.approach(_spot)


func exit() -> void:
	worker.steering.stop()
	# Keep the claim only when handing it to Work.
	if not _handed_over and is_instance_valid(_target):
		_target.release(worker)


func tick(_delta: float) -> void:
	if not is_instance_valid(_target) or not _target.has_work_for(worker.job):
		_release_and(&"Idle")
		return
	if worker.is_near(_spot, 0.6):
		# Keep the claim: Work releases it when done.
		_handed_over = true
		transition(&"Work", {"target": _target})
		return
	if worker.is_stuck(_spot):
		worker.blacklist(_target)
		_release_and(&"Idle")
		return
	worker.approach(_spot)


func _release_and(next: StringName) -> void:
	if is_instance_valid(_target):
		_target.release(worker)
	transition(next)
