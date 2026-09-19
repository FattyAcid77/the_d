extends Node
## DialogManager - add as an Autoload named "DialogManager". Owns one DialogUI
## for the whole game.

const UI_SCENE_PATH := "res://FD_Testing/GameSystems/DialogV2/dialog_ui.tscn"

signal dialog_started
signal dialog_finished
signal action_requested(action_name: String, args: Array)

var is_active: bool = false
var _ui: DialogUI

## The NPC currently talking, if the caller passed one.
var speaker_node: Node = null
var _waiting_action: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Loud but survivable: a missing UI scene used to crash the autoload on _ready
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


## `speaker` is the NPC node doing the talking.
func start_dialog(dialog: Dialog, speaker_name: String = "", portrait: Texture2D = null,
		speaker: Node = null) -> void:
	if is_active or dialog == null:
		return
	if _ui == null:
		push_warning("DialogManager: no dialog UI loaded — ignoring start_dialog().")
		return
	is_active = true
	dialog_started.emit()
	speaker_node = speaker
	_face_player()
	_ui.start(dialog, speaker_name, portrait)


## Called by DialogUI when a line has an action.
func emit_action(action_name: String, args: Array, wait: bool) -> void:
	action_name = DialogActionStep.verb_of(action_name, "")
	_waiting_action = wait

	if action_name == "wait":
		var secs := float(args[0]) if args.size() > 0 else 1.0
		_waiting_action = true
		await get_tree().create_timer(secs).timeout
		_waiting_action = false
		return

	var handled := DialogActions.run(get_tree(), action_name, args)

	# Always emit, handled or not, so your game can still listen in on built-in verbs
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
	clear_line_animations()
	is_active = false
	_waiting_action = false
	dialog_finished.emit()


# --- animation, driven by dialog lines --------------------------------------

## Turns the speaker to look at Sami, if that NPC wants it.
func _face_player() -> void:
	if speaker_node == null or not speaker_node.has_method("face_position"):
		return
	var res = speaker_node.get("npc_resource")
	if res and not res.face_player_on_dialog:
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player:
		speaker_node.face_position(player.global_position)


## Called by DialogUI as each line begins.
func apply_line_animation(line: DialogLine) -> void:
	if line == null:
		return

	if line.animation != "" and speaker_node \
			and speaker_node.has_method("play_override"):
		speaker_node.play_override(line.animation, line.animation_hold)

	if line.player_animation != "":
		var player := get_tree().get_first_node_in_group("Player") as Node2D
		if player and player.has_method("play_override"):
			player.play_override(line.player_animation, line.player_animation_hold)
		elif player:
			# Sami is the other developer's scene, so we don't assume he has our override system.
			_play_on_plain_sprite(player, line.player_animation)


## Best-effort play on a node we don't own: find an AnimatedSprite2D under it and play
func _play_on_plain_sprite(node: Node, base: String) -> void:
	var spr := _find_animated_sprite(node)
	if spr == null or spr.sprite_frames == null:
		return
	for candidate in [base + "_down", base + "_Side", base]:
		if spr.sprite_frames.has_animation(candidate):
			spr.play(candidate)
			return
	push_warning("DialogManager: the player has no animation called '%s'." % base)


func _find_animated_sprite(node: Node) -> AnimatedSprite2D:
	for c in node.get_children():
		if c is AnimatedSprite2D:
			return c
		var deep := _find_animated_sprite(c)
		if deep:
			return deep
	return null


## Clears any held animation when the conversation ends, so nobody is left frozen mid-jump.
func clear_line_animations() -> void:
	if speaker_node and speaker_node.has_method("clear_override"):
		speaker_node.clear_override()
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player and player.has_method("clear_override"):
		player.clear_override()
	speaker_node = null
