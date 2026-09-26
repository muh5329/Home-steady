extends CompanionState
## Badly hurt: falls back behind the player, away from the nearest threat,
## until rest has restored some health. Fights back only if cornered.

const CORNERED_DISTANCE := 1.8

var _time := 0.0


func enter(_message: Dictionary) -> void:
	_time = 0.0
	ai.set_activity("Retreating!")
	ai.target = null


func tick(delta: float) -> void:
	_time += delta
	if ai.health_ratio() >= CompanionController.RECOVERED_HEALTH:
		transition(&"Hold" if ai.order == CompanionController.Order.HOLD else &"Follow")
		return
	var threat := Targeting.nearest_hostile_around(ai.combat, ai.body.global_position, 10.0)
	if threat == null:
		# Safe: stay with the player (or the hold point) and rest.
		var home := ai.hold_position if ai.order == CompanionController.Order.HOLD else ai.formation_point()
		if ai.steering.distance_to(home) > 1.6:
			ai.move_to(home, CharacterMotor.Gait.RUN)
		else:
			ai.steering.stop()
		return
	if _time > 4.0 and ai.steering.distance_to(threat.global_position()) < CORNERED_DISTANCE:
		transition(&"Attack", {"target": threat, "cornered": true})
		return
	var leader := ai.leader()
	var anchor := leader.global_position if leader else ai.body.global_position
	var away := NavSteering.flat(anchor - threat.global_position())
	if away.length_squared() < 0.01:
		away = NavSteering.flat(ai.body.global_position - threat.global_position())
	ai.move_to(anchor + away.normalized() * 5.0, CharacterMotor.Gait.SPRINT)
