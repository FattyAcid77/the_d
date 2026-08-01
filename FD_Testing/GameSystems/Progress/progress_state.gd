class_name ProgressState extends Node
## One state of the game. The NODE NAME is the state name.
## Everything it does is set in the inspector — or extend this script for
## custom code by overriding _enter()/_exit().

@export_group("On Enter")
## Nodes in these groups become visible + processing when this state starts.
## (Select any node -> Node dock -> Groups to put it in a group.)
@export var show_groups: Array[String] = []
## Nodes in these groups are hidden + stopped while this state is active.
@export var hide_groups: Array[String] = []
## Flags set when the state starts (e.g. ["act2_started"]).
@export var set_flags: Array[String] = []

@export_group("Auto Advance (optional)")
## When this flag becomes set, automatically go to `next_state`.
@export var auto_advance_when_flag: String = ""
@export var next_state: String = ""


func enter() -> void:
	for g in show_groups:
		_set_group_active(g, true)
	for g in hide_groups:
		_set_group_active(g, false)
	for f in set_flags:
		Flags.set_flag(f)
	_enter()


func exit() -> void:
	_exit()


func _set_group_active(group: String, active: bool) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if node is CanvasItem:
			node.visible = active
		node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


## Override these in a script that extends ProgressState for custom behavior.
func _enter() -> void:
	pass


func _exit() -> void:
	pass
