class_name SoundSpy extends CanvasLayer
## F9 in a debug run: what the sound system is doing right now. Moments as
## they fire (green = has a sound, red = nothing mapped), every sound that
## starts, ids that don't exist, the music set and its layers, running loops.
## Sound adds it by itself in debug builds; exported release builds never have it.

## The key that shows and hides it. Change it here.
const KEY := KEY_F9
## The key that empties both lists for a fresh log, shown or hidden.
const CLEAR_KEY := KEY_F10
## Lines kept per list.
const KEEP := 8

var moments: Array = []  # [moment, cue, count], newest first
var plays: Array = []  # [id, found, count], newest first
var _snd: Node
var _panel: PanelContainer
var _text: RichTextLabel
var _dirty := false
var _keys := {}  # key -> [down last frame, already handled by _input]


func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_snd = get_parent()
	_snd.moment_fired.connect(_on_moment)
	_snd.sound_started.connect(_on_play)
	_snd.music_changed.connect(func(_s): _dirty = true)
	if _snd.beds:
		_snd.beds.set_changed.connect(func(_c, _s): _dirty = true)
		_snd.beds.layer_changed.connect(func(_c, _l, _o): _dirty = true)
	_build()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY or k.keycode == CLEAR_KEY:
		_press(k.keycode)
		_keys[k.keycode] = [true, true]
		get_viewport().set_input_as_handled()


func _press(key: int) -> void:
	if key == KEY:
		visible = not visible
		_dirty = true
	else:
		clear()


## Empties the moment and sound lists. Music, ambience and loops stay: they
## show what's playing now, not a history.
func clear() -> void:
	moments.clear()
	plays.clear()
	_dirty = true


func _process(_delta: float) -> void:
	# A popup window can hold the keyboard; the global key state still sees it.
	for key in [KEY, CLEAR_KEY]:
		var st: Array = _keys.get(key, [false, false])
		var down := Input.is_key_pressed(key)
		if down and not st[0] and not st[1]:
			_press(key)
		_keys[key] = [down, false]
	if visible and _dirty:
		_dirty = false
		_text.text = _render()


func _on_moment(moment: String, cue: String) -> void:
	_push(moments, [moment, cue, 1])


func _on_play(id: String, found: bool) -> void:
	_push(plays, [id, found, 1])


## Same line as the newest one: count it instead of repeating it.
func _push(list: Array, entry: Array) -> void:
	if not list.is_empty() and list[0][0] == entry[0] and list[0][1] == entry[1]:
		list[0][2] += 1
	else:
		list.push_front(entry)
		if list.size() > KEEP:
			list.pop_back()
	_dirty = true


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_to_group("no_mirror")
	_panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.78)
	box.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", box)
	# top right, as tall as what it says
	_panel.anchor_left = 0.55
	_panel.anchor_right = 1.0
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_panel)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 11)
	_text.add_theme_font_size_override("bold_font_size", 11)
	_panel.add_child(_text)


func _render() -> String:
	var t := "[b]SOUND SPY[/b]  [color=#888]F9 hide, F10 clear[/color]\n"
	t += "[color=#8ab4ff]music[/color]     %s\n" % _bed_line("Music")
	t += "[color=#8ab4ff]ambience[/color]  %s\n" % _bed_line("Ambience")
	var loops: Array = _snd._loops.keys()
	t += "[color=#8ab4ff]loops[/color]     %s\n" % (", ".join(loops) if not loops.is_empty() else "[color=#666]-[/color]")

	t += "\n[b]moments[/b]\n"
	if moments.is_empty():
		t += "[color=#666]nothing yet[/color]\n"
	for m in moments:
		var times := "  x%d" % m[2] if m[2] > 1 else ""
		if m[1] == "":
			t += "[color=#ff6b6b]%s[/color] [color=#888]nothing mapped%s[/color]\n" % [m[0], times]
		else:
			t += "[color=#7cfc8a]%s[/color] -> %s[color=#888]%s[/color]\n" % [m[0], m[1], times]

	t += "\n[b]sounds[/b]\n"
	if plays.is_empty():
		t += "[color=#666]nothing yet[/color]\n"
	for p in plays:
		var times := "  x%d" % p[2] if p[2] > 1 else ""
		if p[1]:
			t += "> %s[color=#888]%s[/color]\n" % [p[0], times]
		else:
			t += "[color=#ff6b6b]x %s[/color] [color=#888]not in the library%s[/color]\n" % [p[0], times]
	return t


## "set_id [on layers]" for a bed, or the plain music track, or "-".
func _bed_line(category: String) -> String:
	var beds: Node = _snd.beds
	var s: MusicSet = beds.current_set(category) if beds else null
	if s:
		var on: Array = []
		for l in s.layer_names():
			if beds.is_layer_on(category, l):
				on.append(l)
		return "%s [color=#888][%s][/color]" % [s.id, ", ".join(on)]
	if category == "Music":
		var st: AudioStream = _snd.current_music()
		if st:
			var n := st.resource_path.get_file()
			return n if n != "" else "(track)"
	return "[color=#666]-[/color]"
