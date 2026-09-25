extends WorkerState
## Swings at the claimed target back-to-back while it offers work. Swings
## run every frame-accurate cycle, independent of the think rate. When a
## swing produced items, go collect them.

var _target: Node3D
var _generation := 0


func enter(message: Dictionary) -> void:
	_target = message["target"]
	worker.steering.stop()
	worker.set_activity(worker.job.work_verb)
	_generation += 1
	_work_loop(_generation)


func exit() -> void:
	_generation += 1  # stops the loop
	if is_instance_valid(_target):
		_target.release(worker)


func _work_loop(gen: int) -> void:
	while gen == _generation:
		if not is_instance_valid(_target) or not _target.has_work_for(worker.job):
			transition(&"Idle")
			return
		var result = await worker.swing_at(_target)
		if gen != _generation:
			return
		if result is Dictionary and result.has("produced_at"):
			worker.last_work_position = result["produced_at"]
			# Give the produce a moment to land.
			transition(&"Collect", {"near": result["produced_at"], "radius": 9.0, "delay": 1.4})
			return
		# Wait for the swing (or whatever interrupted it) to finish.
		while gen == _generation and worker.combat.state != CombatController.CombatState.READY:
			await get_tree().physics_frame
