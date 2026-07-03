class_name StateMachine extends Node

## A tiny node-based finite state machine.
##
## Drop State nodes as children, pick the starting one in the inspector, and
## this machine forwards input / process / physics to whichever state is
## currently active. States request a change by emitting their `transitioned`
## signal — they never switch each other directly.

## Which child state to start in. Drag a State node here in the inspector.
@export var initial_state: State

## The state running right now.
var current_state: State

## Lowercased node name -> State node, so we can switch states by string.
var _states: Dictionary = {}


func _ready() -> void:
	# Children get _ready before their parent, so the player (our owner) is not
	# fully ready yet. Wait for it so states can safely touch the player.
	if not owner.is_node_ready():
		await owner.ready

	for child in get_children():
		if child is State:
			_states[child.name.to_lower()] = child
			child.player = owner as Sami20
			child.transitioned.connect(_on_state_transitioned)

	current_state = initial_state
	if current_state:
		current_state.enter()


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## Runs whenever the active state emits `transitioned`.
func _on_state_transitioned(next_state_name: String) -> void:
	var next_state := _states.get(next_state_name.to_lower()) as State
	if next_state == null:
		push_warning("StateMachine: no state named '%s'" % next_state_name)
		return
	if next_state == current_state:
		return

	current_state.exit()
	next_state.enter()
	current_state = next_state
