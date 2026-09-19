class_name DialogLine extends Resource
## One thing a character says. BBCode is allowed in `text` (e.g.

@export_multiline var text: String = ""

## Optional speaker name override.
@export var speaker_name: String = ""

## Cue when the line appears: "paper", "delay(1) scream", "loop drone", "stop(0.3) drone".
## For a sound on a specific word, write [sfx:scream] inside the text itself.
@export var sound_id: String = ""

## Only show this line if this flag is set.
@export var show_if_flag: String = ""

## HIDE this line once this flag is set.
@export var hide_if_flag: String = ""

## Flags to set the moment this line runs (e.g.
@export var set_flags: Array[String] = []

## Words in this line that can become clickable topics.
@export var keywords: Array[DialogKeyword] = []

## Player choice buttons.
@export var choices: Array[DialogChoice] = []

@export_group("Animation")
## The animation the speaker plays on this line, e.g.
@export var animation: String = ""

## on = keep looping it until another line changes it, or the dialog ends.
@export var animation_hold: bool = false

## Same, but for sami - so a line can make him react, not just the NPC.
@export var player_animation: String = ""
@export var player_animation_hold: bool = false


@export_group("Camera")
## Tween the active Camera2D to a point while this line plays (cutscene feel).
@export var move_camera: bool = false
@export var camera_target: Vector2 = Vector2.ZERO
@export var camera_time: float = 1.0

@export_group("Action")
## Pick the verb. The bracket is the args it expects.
@export_enum(
	"set_flag  [flag]",
	"clear_flag  [flag]",
	"toggle_flag  [flag]",
	"give_item  [type; amount]",
	"take_item  [type; amount]",
	"open_window  [window id]",
	"close_window  [window id]",
	"close_all_windows",
	"log_entry  [entry id]",
	"log_open",
	"heal  [amount]",
	"hurt  [amount]",
	"bleed",
	"stop_bleeding",
	"kill  [cause id]",
	"radio_tune  [hz]",
	"radio_open",
	"play_sound  [cue]",
	"play_music  [id; fade]",
	"stop_music  [fade]",
	"play_set  [set id; layers]",
	"stop_set  [Music|Ambience]",
	"music_layer  [layer; on|off|auto]",
	"ambience_layer  [layer; on|off|auto]",
	"progress_stage  [state]",
	"play_cutscene  [path]",
	"cutscene  [path]",
	"checkpoint  [number]",
	"prescription_show",
	"prescription_entry",
	"state  [state]",
	"wait  [seconds]",
	"end_dialog",
	"custom  (type the name below)"
) var action_name: String = ""
## Only used when action_name is custom. Emitted as action_requested(name, args).
@export var custom_action: String = ""
@export var action_args: Array = []
## Pause the dialog until DialogManager.finish_action() is called.
@export var wait_for_action: bool = false
## More actions on the same line, run in order after the first.
@export var more_actions: Array[DialogActionStep] = []


## Every action on this line as {verb, args, wait}, first one first.
func actions() -> Array:
	var out := []
	var v := DialogActionStep.verb_of(action_name, custom_action)
	if v != "":
		out.append({"verb": v, "args": action_args, "wait": wait_for_action})
	for step in more_actions:
		if step == null:
			continue
		var sv := step.verb()
		if sv != "":
			out.append({"verb": sv, "args": step.args, "wait": step.wait})
	return out
