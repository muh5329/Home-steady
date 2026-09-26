extends EnemyState
## Walks back home, dropping the target. Re-aggros if attacked nearby.


func enter(_message: Dictionary) -> void:
	ai.target = null
	ai.move_to(ai.home_position, CharacterMotor.Gait.RUN)
	# Leashing resets the fight: no chip-and-retreat, no lingering phases.
	ai.combat.health.set_current(ai.combat.health.max_health)
	var summoner := ai.body.get_node_or_null(^"Summoner") as Summoner
	if summoner:
		summoner.dismiss_all()


func tick(_delta: float) -> void:
	if ai.distance_from_home() < 1.0:
		transition(&"Idle")
		return
	# Only re-engage once back inside its territory.
	if ai.distance_from_home() < ai.definition.leash_range * 0.5:
		var seen := ai.find_target()
		if seen:
			ai.target = seen
			transition(&"Chase")
			return
	ai.move_to(ai.home_position, CharacterMotor.Gait.RUN)
