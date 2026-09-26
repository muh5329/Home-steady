extends CompanionState
## Stays at the hold point; only fights what comes close to it.


func enter(_message: Dictionary) -> void:
	ai.set_activity("Holding position")


func tick(_delta: float) -> void:
	if ai.order == CompanionController.Order.FOLLOW:
		transition(&"Follow")
		return
	if ai.should_retreat():
		transition(&"Retreat")
		return
	if ai.health_ratio() >= CompanionController.RETREAT_HEALTH:
		var t := ai.pick_target()
		# A ranged companion only engages what it can shoot from here.
		if t and (not ai.is_ranged() or Targeting.has_line_of_sight(ai.combat, t)):
			transition(&"Attack", {"target": t})
			return
	if ai.steering.distance_to(ai.hold_position) > 1.2:
		ai.move_to(ai.hold_position, CharacterMotor.Gait.RUN)
	else:
		ai.steering.stop()
