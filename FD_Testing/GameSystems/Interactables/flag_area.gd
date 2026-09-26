class_name FlagArea extends Area2D
## Sets flags when something happens here: Sami walks in or out, presses
## interact, or tunes the radio to a number. It can also play a sound and run
## any dialog verb (open a window, give an item, start music...).

signal triggered

## What makes it fire.
@export_enum("Walk in", "Walk out", "Press interact", "Radio tuned") var fires_on: int = 0

@export_group("What it does")
## Flags set when it fires.
@export var set_flags: Array[String] = []
## Flags cleared when it fires.
@export var clear_flags: Array[String] = []
## Id or cue from the sound library, e.g. "door_creak" or "delay(1) scream".
@export var sound_id: String = ""
## Any dialog verb, run in order. wait and delay pause before the next step.
@export var actions: Array[DialogActionStep] = []

@export_group("Radio")
## The number the radio has to read, decimals included.
@export var radio_frequency: float = 23.12
## How close counts. 0.0001 = exact.
@export var radio_tolerance: float = 0.0001
## Only counts while Sami stands inside the area.
@export var radio_player_inside: bool = true
## Only counts while the radio is open on screen.
@export var radio_must_be_open: bool = false
## Seconds the radio has to stay on the number.
@export var radio_hold_seconds: float = 0.0

@export_group("When")
## Only works once this flag is set.
@export var require_flag: String = ""
## Dead once this flag is set.
@export var hide_flag: String = ""
## Fires once, then it's done for good (remembered with done_flag).
@export var once_only: bool = true
## Flag that marks it done. Empty = one made from the node's path.
@export var done_flag: String = ""
## Seconds before it can fire again, when once_only is off.
@export var cooldown: float = 0.0

@export_group("The player")
@export var player_group: String = "Player"

enum { WALK_IN, WALK_OUT, INTERACT, RADIO }

var _player_in := false
var _cool := 0.0
var _hold := 0.0
var _radio_latched := false
var _done := ""
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	SoundLink.attach(self)
	_done = done_flag if done_flag != "" else "flagarea:" + str(get_path())
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if fires_on == RADIO:
		# the radio screen may pause the game
		process_mode = Node.PROCESS_MODE_ALWAYS
	_show_prompt()


func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta
	match fires_on:
		INTERACT:
			if _player_in and InputAccess.just_pressed() and not _dialog_running():
				fire()
		RADIO:
			_check_radio(delta)


## Can it fire right now?
func is_armed() -> bool:
	var flags := get_node_or_null("/root/Flags")
	if flags:
		if require_flag != "" and not flags.is_set(require_flag):
			return false
		if hide_flag != "" and flags.is_set(hide_flag):
			return false
		if once_only and flags.is_set(_done):
			return false
	return _cool <= 0.0


## Fire from code (a cutscene, another node). Same checks as the trigger.
func fire() -> bool:
	if not is_armed():
		return false
	_cool = cooldown
	var flags := get_node_or_null("/root/Flags")
	if flags:
		if once_only:
			flags.set_flag(_done)
		for f in set_flags:
			if f != "":
				flags.set_flag(f)
		for f in clear_flags:
			if f != "":
				flags.clear_flag(f)
	if sound_id != "":
		var snd := get_node_or_null("/root/Sound")
		if snd:
			snd.cue(sound_id, self)
	triggered.emit()
	_show_prompt()
	_run_actions()
	return true


func _run_actions() -> void:
	for step in actions:
		if step == null:
			continue
		var verb := step.verb()
		if verb == "":
			continue
		if verb == "wait" or verb == "delay":
			var secs := float(step.args[0]) if step.args.size() > 0 else 1.0
			await get_tree().create_timer(secs, true).timeout
			if not is_instance_valid(self) or not is_inside_tree():
				return
			continue
		# verbs DialogActions doesn't know (checkpoint, state, custom) go to
		# whoever listens for dialog actions, same as from a dialog line
		if not DialogActions.run(get_tree(), verb, step.args):
			var dm := get_node_or_null("/root/DialogManager")
			if dm:
				dm.action_requested.emit(verb, step.args)


func _check_radio(delta: float) -> void:
	if not _radio_on_number():
		_hold = 0.0
		_radio_latched = false
		return
	if _radio_latched:
		return  # already fired for this tuning; it has to leave the number first
	_hold += delta
	if _hold >= radio_hold_seconds and fire():
		_radio_latched = true


func _radio_on_number() -> bool:
	if radio_player_inside and not _player_in:
		return false
	var rl := get_node_or_null("/root/RadioLink")
	if rl == null:
		return false
	if radio_must_be_open and not rl.is_open():
		return false
	var hz: float = rl.frequency_exact() if rl.has_method("frequency_exact") else float(rl.frequency())
	return absf(hz - radio_frequency) <= radio_tolerance


func _dialog_running() -> bool:
	var dm := get_node_or_null("/root/DialogManager")
	return dm != null and dm.is_active


func _show_prompt() -> void:
	if prompt:
		prompt.visible = _player_in and fires_on in [INTERACT, RADIO] and is_armed()


func _is_player(body: Node2D) -> bool:
	return body != null and body.is_in_group(player_group)


func _on_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_in = true
	_show_prompt()
	if fires_on == WALK_IN:
		fire()


func _on_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_in = false
	_show_prompt()
	if fires_on == WALK_OUT:
		fire()
