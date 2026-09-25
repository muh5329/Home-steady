class_name StateMachine
extends Node
## Minimal finite state machine. States are child nodes; the owner decides
## how often to call tick() (enabling distance-based AI throttling).

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var context: Object
var current: State
var _states: Dictionary = {}  # StringName -> State


func _ready() -> void:
	for child in get_children():
		if child is State:
			_states[StringName(child.name)] = child
			child.machine = self


## Must be called by the owner once its context is ready.
func start(ctx: Object) -> void:
	context = ctx
	current = initial_state if initial_state else get_child(0) as State
	current.enter({})


func tick(delta: float) -> void:
	if current:
		current.tick(delta)


func transition_to(state_name: StringName, message: Dictionary = {}) -> void:
	var next: State = _states.get(state_name)
	if next == null:
		push_error("StateMachine: no state '%s'" % state_name)
		return
	var previous := current.name if current else &""
	if current:
		current.exit()
	current = next
	current.enter(message)
	state_changed.emit(previous, next.name)


func current_name() -> StringName:
	return current.name if current else &""
