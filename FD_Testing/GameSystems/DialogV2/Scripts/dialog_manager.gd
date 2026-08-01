extends Node
## DialogManager — add as an Autoload named "DialogManager".
## Owns one DialogUI for the whole game. Anything can start a conversation:
##
##     DialogManager.start_dialog(my_dialog, "Java", portrait_texture)
##
## And any line can ask your game to DO something via action_requested:
##
##     func _ready():
##         DialogManager.action_requested.connect(_on_dialog_action)
##     func _on_dialog_action(name: String, args: Array):
##         match name:
##             "give_item": inventory.add(args[0])
##             "play_cutscene":
##                 await my_cutscene()
##                 DialogManager.finish_action()   # only if wait_for_action was true

const UI_SCENE_PATH := "res://FD_Testing/GameSystems/DialogV2/dialog_ui.tscn"

signal dialog_started
signal dialog_finished
signal action_requested(action_name: String, args: Array)

var is_active: bool = false
var _ui: DialogUI
var _waiting_action: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = (load(UI_SCENE_PATH) as PackedScene).instantiate()
	add_child(_ui)
	_ui.finished.connect(_on_finished)


func start_dialog(dialog: Dialog, speaker_name: String = "", portrait: Texture2D = null) -> void:
	if is_active or dialog == null:
		return
	is_active = true
	dialog_started.emit()
	_ui.start(dialog, speaker_name, portrait)


## Called by DialogUI when a line has an action. You don't call this yourself.
func emit_action(action_name: String, args: Array, wait: bool) -> void:
	_waiting_action = wait
	action_requested.emit(action_name, args)


## Call this from your action handler to resume a dialog that's waiting.
func finish_action() -> void:
	_waiting_action = false


func is_waiting_action() -> bool:
	return _waiting_action


func _on_finished() -> void:
	is_active = false
	_waiting_action = false
	dialog_finished.emit()
