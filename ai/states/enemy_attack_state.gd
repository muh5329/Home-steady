extends EnemyState
## Performs a short attack string, then backs off/strafes for a cooldown
## so the player gets readable openings. Attackers take turns via the
## target's attack slots; those without a slot circle at a distance.

enum Phase { WAITING, STRIKING, COOLDOWN }

const WAIT_DISTANCE := 3.2

var _phase := Phase.WAITING
var _swings_left := 0
var _cooldown := 0.0
var _strafe_dir := 1.0


func enter(_message: Dictionary) -> void:
	ai.stop_moving()
	_phase = Phase.WAITING
	_strafe_dir = [-1.0, 1.0].pick_random()


func exit() -> void:
	ai.motor.set_facing_lock(&"ai", false)
	if ai.has_valid_target():
		ai.target.release_attack_slot(ai.combat)


func tick(delta: float) -> void:
	if not ai.has_valid_target():
		transition(&"Return")
		return
	var combat := ai.combat
	var in_reach := ai.distance_to_target() <= ai.definition.attack_range + 0.6
	match _phase:
		Phase.WAITING:
			if ai.target.claim_attack_slot(combat):
				ai.motor.set_facing_lock(&"ai", false)
				_phase = Phase.STRIKING
				_swings_left = randi_range(1, maxi(ai.definition.max_combo, 1))
			else:
				_circle(WAIT_DISTANCE)
		Phase.STRIKING:
			if not in_reach and combat.state == CombatController.CombatState.READY:
				ai.move_to(ai.target.global_position(), CharacterMotor.Gait.RUN)
			elif combat.state == CombatController.CombatState.READY:
				ai.stop_moving()
				if ai.try_ability():
					pass
				elif _swings_left > 0:
					ai.face_target()
					combat.request_light()
					_swings_left -= 1
				else:
					_start_cooldown()
			elif combat.can_chain() and _swings_left > 0 and in_reach:
				combat.request_light()
				_swings_left -= 1
		Phase.COOLDOWN:
			_cooldown -= delta
			_circle(2.4)
			if _cooldown <= 0.0:
				ai.stop_moving()
				ai.motor.set_facing_lock(&"ai", false)
				if ai.distance_to_target() <= ai.definition.attack_range + 1.0:
					enter({})
				else:
					transition(&"Chase")


func _start_cooldown() -> void:
	ai.target.release_attack_slot(ai.combat)
	_phase = Phase.COOLDOWN
	var c := ai.definition.attack_cooldown
	_cooldown = randf_range(c.x, c.y)


## Strafe around the target, keeping roughly `distance` away.
func _circle(distance: float) -> void:
	ai.motor.set_facing_lock(&"ai", true)
	ai.face_target()
	var to_target: Vector3 = ai.target.global_position() - ai.body.global_position
	to_target.y = 0.0
	var d := to_target.length()
	var n := to_target / maxf(d, 0.01)
	var side := n.cross(Vector3.UP) * _strafe_dir
	var radial := n * clampf((d - distance) * 0.8, -1.0, 1.0)
	ai.move_direction((side * 0.6 + radial).limit_length(1.0), CharacterMotor.Gait.WALK)
