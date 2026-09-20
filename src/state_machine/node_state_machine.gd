class_name NodeStateMachine
extends Node

@export var initial_node_state: NodeState
var node_states: Dictionary = {}
var current_node_state: NodeState
var current_node_state_name := ""

func _ready() -> void:
	for child in get_children():
		if child is NodeState:
			node_states[child.name.to_lower()] = child
			child.transition.connect(transition_to)
	if initial_node_state:
		transition_to(initial_node_state.name.to_lower())

func _process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_process(delta)

func _physics_process(delta: float) -> void:
	if current_node_state:
		current_node_state._on_physics_process(delta)
		current_node_state._on_next_transitions()

func transition_to(state_name: String) -> void:
	var key := state_name.to_lower()
	if current_node_state_name == key:
		return
	var next: NodeState = node_states.get(key)
	if not next:
		return
	if current_node_state:
		current_node_state._on_exit()
	# Set the current state before enter, so an immediate transition is safe.
	current_node_state = next
	current_node_state_name = key
	next._on_enter()
