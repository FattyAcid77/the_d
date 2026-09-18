class_name State extends Node

## Base class for every player state.
##
## A "state" is just a Node that knows how to run ONE mode of the player:
## standing still, walking, dragging an object, or being frozen during a
## dialog. Concrete states override only the hooks they care about.

## Ask the StateMachine to switch to another state, by name (case-insensitive).
## Example: transitioned.emit("move")
signal transitioned(next_state_name: String)

## Filled in by the StateMachine when the game starts. Gives every state a
## typed reference to the player so it can read input, move, and animate.
var player: Sami20


## Called once, right when the StateMachine switches INTO this state.
func enter() -> void:
	pass


## Called once, right when the StateMachine switches OUT of this state.
func exit() -> void:
	pass


## Forwarded from the StateMachine's _unhandled_input (button presses, etc.).
func handle_input(_event: InputEvent) -> void:
	pass


## Forwarded from _process — visuals / non-physics logic.
func update(_delta: float) -> void:
	pass


## Forwarded from _physics_process — movement lives here.
func physics_update(_delta: float) -> void:
	pass
