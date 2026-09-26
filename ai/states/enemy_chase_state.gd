extends EnemyState
## Runs at the target until in attack range; gives up past the leash, or
## when it has lost sight of the target for a while (it went through a
## locked door, round a corner, up out of the crypt).

const LOSE_TRACK_SECONDS := 5.0

var _unseen := 0.0


func enter(_message: Dictionary) -> void:
	_unseen = 0.0


func tick(delta: float) -> void:
	if not ai.has_valid_target() or (ai.distance_from_home() > ai.definition.leash_range and not ai.is_provoked()):
		transition(&"Return")
		return
	_unseen = 0.0 if Targeting.has_line_of_sight(ai.combat, ai.target) else _unseen + delta
	if _unseen > LOSE_TRACK_SECONDS:
		transition(&"Return")
		return
	if ai.distance_to_target() <= ai.definition.attack_range \
			and (ai.definition.attack_state == &"Attack" or Targeting.has_line_of_sight(ai.combat, ai.target)):
		transition(ai.definition.attack_state)
		return
	ai.move_to(ai.target.global_position(), CharacterMotor.Gait.RUN)
