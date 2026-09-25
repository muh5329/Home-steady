extends WorkerState
## Picks up a loose produce item near a point.

## Logs are 1.5 m long; reach from any side.
const PICKUP_REACH := 1.7

var _near: Vector3
var _radius := 9.0
var _delay := 0.0
var _item: Carryable
var _picking := false
var _generation := 0


func enter(message: Dictionary) -> void:
	_generation += 1
	_near = message.get("near", worker.body.global_position)
	_radius = message.get("radius", 9.0)
	_delay = message.get("delay", 0.0)
	_item = null
	_picking = false
	worker.set_activity("Gathering")


func exit() -> void:
	_generation += 1
	worker.steering.stop()
	if is_instance_valid(_item) and worker.carry.carrying != _item:
		_item.release_claim(worker.carry)
	_item = null


func tick(delta: float) -> void:
	if _picking:
		return
	if _delay > 0.0:
		_delay -= delta
		return
	if worker.carry.carrying:
		transition(&"Deliver")
		return
	if _item == null or not is_instance_valid(_item) or not _item.is_available_for(worker.carry):
		_item = worker.settlement().find_loose_item(worker.job.gather_items, _near, _radius)
		if _item == null or worker.should_skip(_item) or not _item.claim(worker.carry):
			_item = null
			transition(&"Idle")
			return
	if worker.is_near(_item.global_position, PICKUP_REACH):
		worker.steering.stop()
		_pick_up(_generation)
	elif worker.is_stuck(_item.global_position):
		_item.release_claim(worker.carry)
		worker.blacklist(_item)
		_item = null
		transition(&"Idle")
	else:
		worker.approach(_item.global_position)


func _pick_up(gen: int) -> void:
	_picking = true
	var ok: bool = await worker.carry.pick_up(_item)
	if gen != _generation:
		return  # we left this state while picking up
	_picking = false
	transition(&"Deliver" if ok else &"Idle")
