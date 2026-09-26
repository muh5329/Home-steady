class_name CompanionState
extends State
## Base for companion states; `ai` is the CompanionController.

var ai: CompanionController:
	get: return machine.context as CompanionController
