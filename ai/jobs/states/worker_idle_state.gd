extends WorkerState
## Looks for work: deliver what's in hand, pick up loose produce, or claim
## a work target. Backs off between searches and says why it's idle.

const SEARCH_BACKOFF := 1.5

var _wander := 0.0
var _search_in := 0.0


func enter(_message: Dictionary) -> void:
	worker.steering.stop()
	worker.set_activity("Idle")
	_wander = randf_range(1.0, 3.0)
	_search_in = 0.0


func tick(delta: float) -> void:
	var w := worker
	if w.carry.carrying:
		transition(&"Deliver")
		return
	_search_in -= delta
	if _search_in <= 0.0:
		_search_in = SEARCH_BACKOFF
		if _search():
			return
	_wander -= delta
	if _wander <= 0.0:
		_wander = randf_range(3.0, 6.0)
		var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.0, 3.5)
		w.steering.move_to(w.home_position + offset, CharacterMotor.Gait.WALK)


## Returns true if it found something and transitioned.
func _search() -> bool:
	var w := worker
	var s := w.settlement()
	if s == null:
		w.set_activity("Idle — no settlement")
		return false
	if w.job == null:
		w.set_activity("Idle — no job")
		return false
	var radius := w.job.work_radius
	var loose := s.find_loose_item(w.job.gather_items, w.body.global_position, radius * 0.5)
	if loose and not w.should_skip(loose):
		transition(&"Collect", {"near": w.body.global_position, "radius": radius * 0.5})
		return true
	var target := s.find_work_target(w.job, w.home_position, radius, w, w.should_skip)
	if target and target.claim(w):
		transition(&"GoToWork", {"target": target})
		return true
	w.set_activity("Idle — no %s work nearby" % w.job.display_name.to_lower())
	return false
