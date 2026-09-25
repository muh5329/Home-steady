extends EnemyState
## Runs at the target until in attack range; gives up past the leash.


func tick(_delta: float) -> void:
	if not ai.has_valid_target() or (ai.distance_from_home() > ai.definition.leash_range and not ai.is_provoked()):
		transition(&"Return")
		return
	if ai.distance_to_target() <= ai.definition.attack_range:
		transition(&"Attack")
		return
	ai.move_to(ai.target.global_position(), CharacterMotor.Gait.RUN)
