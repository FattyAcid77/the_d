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
	# Loud but survivable: a missing UI scene used to crash the autoload on
	# _ready, which takes the whole game down before the menu appears.
	if not ResourceLoader.exists(UI_SCENE_PATH):
		push_error("DialogManager: dialog UI scene missing at %s — dialog disabled." % UI_SCENE_PATH)
		return
	var packed := load(UI_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("DialogManager: %s is not a PackedScene — dialog disabled." % UI_SCENE_PATH)
		return
	_ui = packed.instantiate()
	add_child(_ui)
	_ui.finished.connect(_on_finished)


func start_dialog(dialog: Dialog, speaker_name: String = "", portrait: Texture2D = null) -> void:
	if is_active or dialog == null:
		return
	if _ui == null:
		push_warning("DialogManager: no dialog UI loaded — ignoring start_dialog().")
		return
	is_active = true
	dialog_started.emit()
	_ui.start(dialog, speaker_name, portrait)


## Called by DialogUI when a line has an action. You don't call this yourself.
##
## A built-in verb (see DialogV2/ACTIONS.md) runs immediately. Anything else
## is emitted as `action_requested` exactly as before, so your own custom
## actions keep working untouched.
func emit_action(action_name: String, args: Array, wait: bool) -> void:
	_waiting_action = wait

	if action_name == "wait":
		var secs := float(args[0]) if args.size() > 0 else 1.0
		_waiting_action = true
		await get_tree().create_timer(secs).timeout
		_waiting_action = false
		return

	var handled := DialogActions.run(get_tree(), action_name, args)

	# Always emit, handled or not, so your game can still listen in on
	# built-in verbs (for sound, screen shake, analytics, whatever).
	action_requested.emit(action_name, args)

	if handled and not wait:
		_waiting_action = false


## Force the current dialog to end early (used by the "end_dialog" action).
func stop() -> void:
	if _ui and _ui.has_method("finish"):
		_ui.finish()
	else:
		_on_finished()


## Call this from your action handler to resume a dialog that's waiting.
func finish_action() -> void:
	_waiting_action = false


func is_waiting_action() -> bool:
	return _waiting_action


func _on_finished() -> void:
	is_active = false
	_waiting_action = false
	dialog_finished.emit()
