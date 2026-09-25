class_name State
extends Node
## One state of a StateMachine. Subclasses override the hooks they need.
## `machine.context` is the object the states operate on (e.g. an
## EnemyController), so states stay reusable across actor types.

var machine: StateMachine


func enter(_message: Dictionary) -> void:
	pass


func exit() -> void:
	pass


## Called at the owner's think rate, not necessarily every frame.
func tick(_delta: float) -> void:
	pass


func transition(state_name: StringName, message: Dictionary = {}) -> void:
	machine.transition_to(state_name, message)
