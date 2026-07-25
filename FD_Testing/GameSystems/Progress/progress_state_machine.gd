class_name ProgressStateMachine extends Node
## Put ONE of these in each level scene, with ProgressState children — your
## "empty node per state" idea:
##
##   ProgressStateMachine
##   ├── Start          (ProgressState)
##   ├── Met_Java       (ProgressState)
##   ├── Statue_Solved  (ProgressState)
##   └── Act2           (ProgressState)
##
## The child NODE NAME is the state name. When the level loads, the machine
## finds the state matching GameProgress.current() and enters it. When
## GameProgress.goto_state() is called, it exits the old and enters the new.
##
## A level that doesn't have a node for the current state simply applies
## nothing — so levels only need the states that matter to them.

var _active: ProgressState = null


func _ready() -> void:
	GameProgress.state_changed.connect(_on_state_changed)
	Flags.flag_changed.connect(_on_flag_changed)
	_enter_state(GameProgress.current())


func _get_state(state_name: String) -> ProgressState:
	var node := get_node_or_null(NodePath(state_name))
	return node if node is ProgressState else null


func _enter_state(state_name: String) -> void:
	var next := _get_state(state_name)
	if _active:
		_active.exit()
	_active = next
	if _active:
		_active.enter()


func _on_state_changed(_old: String, new_state: String) -> void:
	_enter_state(new_state)


## Auto-advance: if the active state has a flag condition, watch for it.
func _on_flag_changed(_flag: String, _value: Variant) -> void:
	if _active == null:
		return
	if _active.auto_advance_when_flag == "" or _active.next_state == "":
		return
	if Flags.is_set(_active.auto_advance_when_flag):
		GameProgress.goto_state(_active.next_state)
