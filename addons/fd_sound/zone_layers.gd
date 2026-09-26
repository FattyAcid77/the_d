@tool
extends EditorProperty
## A MusicZone's layers as tick boxes, read from the zone's own music_set, with
## a play button to hear the room's mix. Names the set no longer has show in red.

const Library := preload("library.gd")

var tools
var box: VBoxContainer
var play_button: Button
var _set_ref: Resource = null
var _checks := {}  # layer name -> CheckBox


func _init(p_tools) -> void:
	tools = p_tools
	box = VBoxContainer.new()
	add_child(box)
	set_bottom_editor(box)


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	# the set can change in the field above; follow it
	var obj := get_edited_object()
	if obj and obj.get("music_set") != _set_ref:
		_rebuild()


func _update_property() -> void:
	_rebuild()


func _current() -> Array:
	var v = get_edited_object().get(get_edited_property())
	return Array(v) if v != null else []


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
	_checks.clear()
	var obj := get_edited_object()
	if obj == null:
		return
	_set_ref = obj.get("music_set")
	var layers := Library.layers_of(_set_ref)
	var chosen := _current()
	if _set_ref == null:
		var hint := Label.new()
		hint.text = "Pick a music_set above; its layers show up here."
		hint.modulate = Color(1, 1, 1, 0.6)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(hint)
		return
	for l in layers:
		var cb := CheckBox.new()
		cb.text = l.name
		cb.button_pressed = chosen.has(l.name)
		cb.toggled.connect(func(on): _toggle(l.name, on))
		box.add_child(cb)
		_checks[l.name] = cb
	var names := layers.map(func(l): return l.name)
	for n in chosen:
		if not names.has(n):
			var cb := CheckBox.new()
			cb.text = "%s  (not in this set)" % n
			cb.button_pressed = true
			cb.add_theme_color_override("font_color", Color(1, 0.42, 0.42))
			cb.toggled.connect(func(on): _toggle(n, on))
			box.add_child(cb)
			_checks[n] = cb
	play_button = Button.new()
	play_button.text = "Hear this room's mix"
	play_button.icon = EditorInterface.get_editor_theme().get_icon("Play", "EditorIcons")
	play_button.pressed.connect(toggle_play)
	box.add_child(play_button)


func _toggle(layer: String, on: bool) -> void:
	var out: Array[String] = []
	for n in _current():
		out.append(str(n))
	if on and not out.has(layer):
		out.append(layer)
	elif not on:
		out.erase(layer)
	emit_changed(get_edited_property(), out)
	if tools.playing_set == _key():
		tools.set_layer(layer, on)


func toggle_play() -> void:
	if tools.playing_set == _key():
		tools.stop()
		return
	tools.play_set(_key(), Library.layers_of(_set_ref), _current())


func _key() -> String:
	return "zone:%d" % get_edited_object().get_instance_id()


func check_box(layer: String) -> CheckBox:
	return _checks.get(layer)
