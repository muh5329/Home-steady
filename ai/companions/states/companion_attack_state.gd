extends CompanionState
## Fights the chosen target. Melee companions take turns via the target's
## attack slots and swing short combos; ranged companions keep their
## distance, need a clear line and back off when rushed. Abilities are
## used whenever one is ready and in range.

enum Phase { APPROACH, STRIKE, RECOVER }

const RANGED_BACK_OFF := 4.0
const RANGED_PREFERRED := 9.0

var _phase := Phase.APPROACH
var _swings_left := 0
var _recover := 0.0
var _cornered := false
var _strafe := 1.0


func enter(message: Dictionary) -> void:
	ai.target = message.get("target")
	_cornered = message.get("cornered", false)
	_phase = Phase.APPROACH
	_strafe = [-1.0, 1.0].pick_random()
	ai.mark_combat()
	_update_activity()


func exit() -> void:
	ai.motor.set_facing_lock(&"ai", false)
	if ai.target and is_instance_valid(ai.target):
		ai.target.release_attack_slot(ai.combat)
	ai.target = null


func tick(delta: float) -> void:
	if not _cornered and ai.should_retreat():
		transition(&"Retreat")
		return
	if not _still_worth_fighting():
		var next := ai.pick_target()
		if next and ai.distance_to_leader() < CompanionController.LEASH:
			exit()
			enter({"target": next})
			return
		transition(&"Hold" if ai.order == CompanionController.Order.HOLD else &"Follow")
		return
	var threat := ai.current_threat()
	if threat and threat != ai.target:
		exit()
		enter({"target": threat})  # defend: whoever is hurting the party
		return
	ai.mark_combat()
	if ai.try_ability():
		return
	if ai.is_ranged():
		_tick_ranged()
	else:
		_tick_melee(delta)


func _still_worth_fighting() -> bool:
	if not ai.has_target():
		return false
	if ai.order == CompanionController.Order.HOLD:
		return NavSteering.flat(ai.target.global_position() - ai.hold_position).length() \
			< CompanionController.HOLD_ENGAGE_RADIUS * 1.5
	return ai.distance_to_leader() < CompanionController.LEASH


func _tick_ranged() -> void:
	var combat := ai.combat
	var d := ai.distance_to_target()
	var target_pos := ai.target.global_position()
	if d > ai.attack_reach() or not Targeting.has_line_of_sight(combat, ai.target):
		ai.motor.set_facing_lock(&"ai", false)
		if ai.order == CompanionController.Order.HOLD:
			transition(&"Hold")  # holding means holding: no chasing for a shot
			return
		ai.move_to(target_pos, CharacterMotor.Gait.RUN)
		return
	# In range with a clear shot: face and shoot; step back if rushed.
	ai.motor.set_facing_lock(&"ai", true)
	ai.motor.face(target_pos - ai.body.global_position)
	if d < RANGED_BACK_OFF:
		var away := NavSteering.flat(ai.body.global_position - target_pos).normalized()
		ai.steering.move_direction(away, CharacterMotor.Gait.WALK)
	else:
		ai.steering.stop()
	if combat.state == CombatController.CombatState.READY:
		combat.request_light()


func _tick_melee(delta: float) -> void:
	var combat := ai.combat
	var target := ai.target
	var d := ai.distance_to_target()
	var reach := ai.attack_reach()
	match _phase:
		Phase.APPROACH:
			if d > reach + 2.5:
				ai.motor.set_facing_lock(&"ai", false)
				ai.move_to(target.global_position(), CharacterMotor.Gait.RUN)
			elif target.claim_attack_slot(combat) or _cornered:
				ai.motor.set_facing_lock(&"ai", false)
				_phase = Phase.STRIKE
				_swings_left = randi_range(2, 3)
			else:
				_circle(3.0)
		Phase.STRIKE:
			if combat.state == CombatController.CombatState.READY:
				if d > reach:
					ai.move_to(target.global_position(), CharacterMotor.Gait.RUN)
				elif _swings_left > 0:
					ai.steering.stop()
					ai.motor.face(target.global_position() - ai.body.global_position, true)
					combat.request_light()
					_swings_left -= 1
				else:
					target.release_attack_slot(combat)
					_phase = Phase.RECOVER
					_recover = randf_range(0.5, 1.0)
			elif combat.can_chain() and _swings_left > 0 and d <= reach + 0.6:
				combat.request_light()
				_swings_left -= 1
		Phase.RECOVER:
			_recover -= delta
			_circle(2.4)
			if _recover <= 0.0:
				ai.steering.stop()
				ai.motor.set_facing_lock(&"ai", false)
				_phase = Phase.APPROACH


## Strafe around the target at roughly `distance`, facing it.
func _circle(distance: float) -> void:
	ai.motor.set_facing_lock(&"ai", true)
	var to_target := NavSteering.flat(ai.target.global_position() - ai.body.global_position)
	ai.motor.face(to_target)
	var d := to_target.length()
	var n := to_target / maxf(d, 0.01)
	var side := n.cross(Vector3.UP) * _strafe
	var radial := n * clampf((d - distance) * 0.8, -1.0, 1.0)
	ai.steering.move_direction((side * 0.6 + radial).limit_length(1.0), CharacterMotor.Gait.WALK)


func _update_activity() -> void:
	var definition = ai.target.body.get(&"definition") if ai.has_target() else null
	var n: String = definition.display_name if definition is GameData else "an enemy"
	ai.set_activity("Fighting %s" % n)
