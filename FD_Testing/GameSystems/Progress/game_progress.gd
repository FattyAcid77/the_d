extends Node
## GameProgress — add as an Autoload named "GameProgress".
## Remembers WHERE the player is in the game (one current state name) and
## broadcasts changes. The actual per-level effects live in a
## GameStateMachine node inside each level (see game_state_machine.gd).
##
## Change state from anywhere:
##     GameProgress.goto_state("Act2")
##
## Read it:
##     GameProgress.current()            -> "Act2"
##     GameProgress.is_at("Act2")        -> true
##
## From DIALOG: a line with  action_name = "state", action_args = ["Act2"]
## changes the game state mid-conversation.
##
## The current state is stored in Flags under "game_state", so it persists
## with your save automatically (Flags.to_dict / from_dict).

signal state_changed(old_state: String, new_state: String)

const STATE_FLAG := "game_state"

## The state used when a fresh game has no state yet.
@export var initial_state: String = "Start"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func current() -> String:
	var v := str(Flags.get_flag(STATE_FLAG, ""))
	return v if v != "" else initial_state


func is_at(state_name: String) -> bool:
	return current() == state_name


func goto_state(state_name: String) -> void:
	var old := current()
	if old == state_name:
		return
	Flags.set_flag(STATE_FLAG, state_name)
	state_changed.emit(old, state_name)


func _on_dialog_action(action_name: String, args: Array) -> void:
	if action_name != "state":
		return
	if args.is_empty() or not (args[0] is String):
		push_error("'state' action needs args = [\"StateName\"].")
		return
	goto_state(args[0])
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
