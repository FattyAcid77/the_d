@tool
extends VBoxContainer
## Top of a MusicSet's inspector: tick the stems, press play, hear the mix.
## Ticks start on on_by_default. Changing them while it plays fades live.

const Library := preload("library.gd")

var tools
var music_set: Resource
var play_button: Button
var _checks := {}


func _init(p_set: Resource, p_tools) -> void:
	music_set = p_set
	tools = p_tools
	var title := Label.new()
	title.text = "Preview this set"
	add_child(title)
	for l in Library.layers_of(music_set):
		var cb := CheckBox.new()
		cb.text = l.name if l.stream else "%s  (no audio file)" % l.name
		cb.button_pressed = l.on
		cb.disabled = l.stream == null
		cb.toggled.connect(func(on): if tools.playing_set == _key(): tools.set_layer(l.name, on))
		add_child(cb)
		_checks[l.name] = cb
	play_button = Button.new()
	play_button.text = "Play the ticked layers"
	play_button.pressed.connect(toggle_play)
	add_child(play_button)
	if _checks.is_empty():
		var hint := Label.new()
		hint.text = "Add layers below (each with a name and a stem) to preview them."
		hint.modulate = Color(1, 1, 1, 0.6)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(hint)
	add_child(HSeparator.new())


func _ready() -> void:
	play_button.icon = EditorInterface.get_editor_theme().get_icon("Play", "EditorIcons")


func toggle_play() -> void:
	if tools.playing_set == _key():
		tools.stop()
		return
	var on := []
	for n in _checks:
		if _checks[n].button_pressed:
			on.append(n)
	tools.play_set(_key(), Library.layers_of(music_set), on)


func _key() -> String:
	return "set:%d" % music_set.get_instance_id()


func check_box(layer: String) -> CheckBox:
	return _checks.get(layer)
