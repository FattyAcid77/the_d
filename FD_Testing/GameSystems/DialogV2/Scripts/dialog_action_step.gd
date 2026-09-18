class_name DialogActionStep extends Resource
## One extra action on a DialogLine. Same three fields as the line's own
## action; put as many of these in `more_actions` as you like, they run in
## order after the first one.

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
) var action: String = ""
## Only used when `action` is custom. Emitted as action_requested(name, args).
@export var custom_action: String = ""
@export var args: Array = []
## Pause the dialog until DialogManager.finish_action() is called.
@export var wait: bool = false


func verb() -> String:
	return DialogActionStep.verb_of(action, custom_action)


## "set_flag  [flag]" -> "set_flag"; "custom ..." -> the custom name.
static func verb_of(label: String, custom: String) -> String:
	var t := label.strip_edges()
	if t == "":
		return ""
	var first := t.split(" ", false)[0]
	if first == "custom":
		return custom.strip_edges()
	return first
