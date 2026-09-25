class_name EnemyState
extends State
## Base for monster AI states; `ai` is the EnemyController.

var ai: EnemyController:
	get: return machine.context as EnemyController
