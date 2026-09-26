class_name RadioCheck extends Area2D
## The PC (or TV) where the radio's number gets checked. No power (the fuse
## flag unset): a fail sound, nothing else. Powered: if the radio reads the
## wall's answer, set a flag and you're done. If not, a popup window opens
## with the mini-game and takes the mouse and keyboard. Lose it: the player
## dies (and the checkpoint reload rerolls the wall). Win it: the window
## closes and they try another date.
##
##   RadioCheck (Area2D)
##   ├── CollisionShape2D
##   └── Prompt              optional
##
## The mini-game scene goes in a PopupWindowDef with kind = PORTAL and
## portal_interactive on. Its root must emit the two signals named below.

signal no_power
signal passed
signal failed
signal minigame_won
signal minigame_lost

@export_group("The answer")
## Read the answer from a WallClues node so it's only typed once.
@export var wall: NodePath
## Or type it here (23 December = 23.12). Ignored when `wall` is set.
@export var answer: float = 23.12
## The radio must be this close. Exact = 0.0001.
@export var tolerance: float = 0.0001

@export_group("Flags")
## Set when the radio reads the answer.
@export var success_flag: String = "cctv_on"
## Only works once this flag is set (the fuse box, say).
@export var require_flag: String = "fusebox_solved"
## After success, interacting does nothing more.
@export var once: bool = true

@export_group("The mini-game")
## Id of a PopupWindowDef: kind PORTAL, portal_scene = the mini-game, portal_interactive on.
@export var minigame_window_id: String = ""
## Signals on the mini-game scene's root.
@export var won_signal: String = "won"
@export var lost_signal: String = "lost"
## Death cause on a lost game. Empty = no death.
@export var lose_death_cause: String = ""
@export var pause_game_during_minigame: bool = true

@export_group("Sounds")
## Ids from the sound library. Empty = the SoundMap entry for the moment.
@export var pass_sound_id: String = ""
@export var fail_sound_id: String = ""
## Interacting before the fuse is in: "fail_pc" or whatever the team names it.
@export var no_power_sound_id: String = ""

@export_group("The player")
@export var player_group: String = "Player"

var is_passed := false
var _player_in := false
var _window: Node = null
var _was_paused := false
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	SoundLink.attach(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	var flags := get_node_or_null("/root/Flags")
	if flags and success_flag != "" and flags.is_set(success_flag):
		is_passed = true


func _process(_delta: float) -> void:
	if _window != null or not _player_in:
		return
	if once and is_passed:
		return
	if InputAccess.just_pressed():
		check()


func expected() -> float:
	var w := get_node_or_null(wall) if not wall.is_empty() else null
	if w and w.has_method("answer_frequency"):
		return w.answer_frequency()
	return answer


## What the radio says right now, decimals included.
func radio_value() -> float:
	var rl := get_node_or_null("/root/RadioLink")
	if rl == null:
		return 0.0
	if rl.has_method("frequency_exact"):
		return rl.frequency_exact()
	return float(rl.frequency())


func check() -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags and require_flag != "" and not flags.is_set(require_flag):
		_play(no_power_sound_id)
		no_power.emit()
		return
	if absf(radio_value() - expected()) <= tolerance:
		is_passed = true
		if flags and success_flag != "":
			flags.set_flag(success_flag)
		_play(pass_sound_id)
		passed.emit()
	else:
		_play(fail_sound_id)
		failed.emit()
		_open_minigame()


func _open_minigame() -> void:
	if minigame_window_id == "":
		return
	var pw := get_node_or_null("/root/PopupWindows")
	if pw == null or not pw.has_method("open_id"):
		return
	_window = pw.open_id(minigame_window_id)
	if _window == null:
		return
	if pause_game_during_minigame:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_window.closed.connect(_on_window_closed, CONNECT_ONE_SHOT)
	if _window.has_method("focus_portal"):
		_window.focus_portal()
	var game: Node = _window.get("portal_root")
	if game == null:
		if _window.has_signal("portal_ready"):
			_window.portal_ready.connect(_hook_game, CONNECT_ONE_SHOT)
	else:
		_hook_game(game)


func _hook_game(game: Node) -> void:
	if game.has_signal(won_signal):
		game.connect(won_signal, _on_won)
	else:
		push_warning("RadioCheck '%s': mini-game has no signal '%s'." % [name, won_signal])
	if game.has_signal(lost_signal):
		game.connect(lost_signal, _on_lost)
	else:
		push_warning("RadioCheck '%s': mini-game has no signal '%s'." % [name, lost_signal])


func _on_won() -> void:
	minigame_won.emit()
	_close_window()


func _on_lost() -> void:
	minigame_lost.emit()
	var w := get_node_or_null(wall) if not wall.is_empty() else null
	if w and w.has_method("reshuffle"):
		w.reshuffle()
	_close_window()
	if lose_death_cause != "":
		var deaths := get_node_or_null("/root/Deaths")
		if deaths and deaths.has_method("kill"):
			deaths.kill(lose_death_cause)


func _close_window() -> void:
	if _window and is_instance_valid(_window) and _window.has_method("close_window"):
		_window.close_window()
	_on_window_closed()


func _on_window_closed(_def = null) -> void:
	if _window == null:
		return
	_window = null
	if pause_game_during_minigame:
		get_tree().paused = _was_paused


func _play(id: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd and id != "":
		snd.play_from(id, self)


func _is_player(body: Node2D) -> bool:
	return body != null and body.is_in_group(player_group)


func _on_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in = true
		if prompt:
			prompt.visible = not (once and is_passed)


func _on_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in = false
		if prompt:
			prompt.visible = false
