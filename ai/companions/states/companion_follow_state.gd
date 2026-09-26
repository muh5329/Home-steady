extends CompanionState
## Keeps to a formation slot beside/behind the player; engages threats
## around the player.

const SLACK := 1.6  # don't shuffle for tiny offsets


func enter(_message: Dictionary) -> void:
	ai.set_activity("Following")


func tick(_delta: float) -> void:
	if ai.order == CompanionController.Order.HOLD:
		transition(&"Hold")
		return
	if ai.should_retreat():
		transition(&"Retreat")
		return
	if ai.health_ratio() >= CompanionController.RETREAT_HEALTH:
		var t := ai.pick_target()
		if t:
			transition(&"Attack", {"target": t})
			return
	var leader_d := ai.distance_to_leader()
	if leader_d > CompanionController.TELEPORT_DISTANCE:
		ai.teleport_to_leader()
		return
	var goal := ai.formation_point()
	var d := ai.steering.distance_to(goal)
	if d <= SLACK:
		ai.steering.stop()
		return
	var gait := CharacterMotor.Gait.WALK
	if d > 7.0 or leader_d > 8.0:
		gait = CharacterMotor.Gait.SPRINT
	elif d > 3.0:
		gait = CharacterMotor.Gait.RUN
	ai.move_to(goal, gait)
