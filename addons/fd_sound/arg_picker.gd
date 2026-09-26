@tool
extends HBoxContainer
## A row above a dialog action's args. Pick fills the first arg from a list:
## play_sound / play_music -> a sound, play_set -> a music set, music_layer /
## ambience_layer -> a layer, set_flag / clear_flag / toggle_flag -> a flag,
## open_window / close_window -> a window, give_item / take_item -> an item,
## kill -> a death cause, progress_stage -> a progress state.

const Library := preload("library.gd")
## Verbs whose first arg is a name, and which list it comes from.
const NAME_VERBS := {
	"set_flag": "flag", "clear_flag": "flag", "toggle_flag": "flag",
	"open_window": "window", "close_window": "window",
	"give_item": "item", "take_item": "item",
	"kill": "death", "progress_stage": "state",
}

var tools
var target: Object
var verb_prop := ""
var args_prop := ""
var pick_button: Button
var play_button: Button


func _init(p_target: Object, p_verb_prop: String, p_args_prop: String, p_tools) -> void:
	target = p_target
	verb_prop = p_verb_prop
	args_prop = p_args_prop
	tools = p_tools
	var l := Label.new()
	l.text = "Pick for this action"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(l)
	pick_button = Button.new()
	pick_button.text = "Pick"
	pick_button.tooltip_text = "Fills the first arg for sound, music, flag, window, item, death and state verbs"
	pick_button.pressed.connect(open_list)
	add_child(pick_button)
	play_button = Button.new()
	play_button.tooltip_text = "Hear the first arg"
	play_button.pressed.connect(toggle_play)
	add_child(play_button)


func _ready() -> void:
	var th := EditorInterface.get_editor_theme()
	pick_button.icon = th.get_icon("Search", "EditorIcons")
	play_button.icon = th.get_icon("Play", "EditorIcons")


func verb() -> String:
	var v := str(target.get(verb_prop)).strip_edges()
	return v.split(" ", false)[0] if v != "" else ""


func open_list() -> void:
	var lib = tools.library
	match verb():
		"play_sound":
			tools.pick("Sounds (SoundDef)", lib.sound_rows(), set_first_arg)
		"play_music":
			tools.pick("Music tracks (SoundDef)", lib.sound_rows(true), set_first_arg)
		"play_set":
			tools.pick("Music sets (MusicSet)", lib.set_rows(), set_first_arg,
					"No MusicSets found. Put them under Sound/Sets or Sounds/Resource.")
		"music_layer":
			tools.pick("Music layers", lib.layer_rows("Music"), set_first_arg)
		"ambience_layer":
			tools.pick("Ambience layers", lib.layer_rows("Ambience"), set_first_arg)
		_:
			var kind: String = NAME_VERBS.get(verb(), "")
			if kind == "":
				tools.pick("Nothing to pick", [], Callable(),
						"This verb has nothing to pick. Sound, music, flag, window, item, death and state verbs do.")
			else:
				tools.pick(tools.names.title(kind), tools.names.rows(kind), set_first_arg)


## Puts id in args[0], keeps the rest, and goes through undo like any edit.
func set_first_arg(id: String) -> void:
	var old: Array = target.get(args_prop).duplicate()
	var new_args: Array = old.duplicate()
	if new_args.is_empty():
		new_args.append(id)
	else:
		new_args[0] = id
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Pick sound for action")
	ur.add_do_property(target, args_prop, new_args)
	ur.add_undo_property(target, args_prop, old)
	ur.commit_action()


func toggle_play() -> void:
	var args: Array = target.get(args_prop)
	var first := str(args[0]) if not args.is_empty() else ""
	if tools.playing_id != "" or tools.playing_set != "":
		tools.stop()
		return
	match verb():
		"play_sound", "play_music":
			tools.play_sound(Library.first_id(first))
		"play_set":
			var s: Dictionary = tools.library.sets.get(first, {})
			if not s.is_empty():
				var on := []
				for l in s.layers:
					if l.on:
						on.append(l.name)
				if args.size() > 1:
					on = Array(str(args[1]).split(",", false)).map(func(x): return x.strip_edges())
				tools.play_set("arg:" + first, s.layers, on)
