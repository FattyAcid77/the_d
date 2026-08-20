@tool
extends Control
## The Radio dock — the whole radio puzzle, built by clicking.
##
##   DIAL      the same 530..1700 the player turns. Every signal is drawn where
##             it actually sits on it, and the shaded band around each one is
##             how close the player has to get before they catch it. Two bands
##             touching is the mistake you cannot see any other way, so it
##             turns red.
##   LIST      every signal in the game. Add, rename, delete.
##   FORM      sliders and dropdowns. Fields a kind does not use are hidden,
##             the same way a cutscene step hides the ones its Kind ignores.
##
## Save writes `radio_puzzle.tres`. "Place in scene" drops the matching node
## into the level that is open, already pointed at the selected signal — walk
## it to where the puzzle is and that is the whole job.

const PUZZLE_PATH: String = "res://3MK-File/RadioMaker/radio_puzzle.tres"
const SIGNAL_SCENE: String = "res://3MK-File/RadioMaker/radio_signal.tscn"

const REWARD_NAMES: PackedStringArray = [
	"Show a node", "Hide a node", "Mark a puzzle solved", "Set a flag",
]
## What the one value box is asking for, per reward. Same order as above.
const REWARD_HINTS: PackedStringArray = [
	"Node to show", "Node to hide", "Puzzle id", "Flag name",
]
const REWARD_PLACEHOLDERS: PackedStringArray = [
	"e.g. ../Door", "e.g. ../Door", "e.g. beam_puzzle", "e.g. radio_heard",
]

const DIAL_H: float = 104.0
const SIDE_TINT: Color = Color("4aa3ff")
const BAD_TINT: Color = Color("ff5a5a")
const OK_TINT: Color = Color("7ddc84")
const DIM: Color = Color("8a8a8a")

var undo: EditorUndoRedoManager

var _puzzle: RadioMaker_v1Puzzle
var _index: int = -1
## True while the form is being filled from the data, so writing back is
## suppressed and a box being filled cannot fight the person typing in it.
var _loading: bool = false

var _dial: Control
var _list: ItemList
var _form: VBoxContainer
var _warnings: RichTextLabel
var _said: Label

var _name_box: LineEdit
var _type_box: OptionButton
var _freq_slider: HSlider
var _freq_label: Label
var _freq_row: HBoxContainer
var _reach_slider: HSlider
var _reach_label: Label
var _order_box: SpinBox
var _order_row: HBoxContainer
var _puzzle_box: LineEdit
var _reward_box: OptionButton
var _value_box: LineEdit
var _value_name: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 340)
	_load()
	_build()
	_refresh_list()
	if _puzzle.entries.is_empty():
		_select(-1)
	else:
		_list.select(0)
		_select(0)


#region /// the file

func _load() -> void:
	if ResourceLoader.exists(PUZZLE_PATH):
		var res := ResourceLoader.load(PUZZLE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is RadioMaker_v1Puzzle:
			_puzzle = res
			return
	_puzzle = RadioMaker_v1Puzzle.new()


func _save() -> bool:
	var err := ResourceSaver.save(_puzzle, PUZZLE_PATH)
	if err != OK:
		_say("Could not save (error %d)." % err, BAD_TINT)
		return false
	_say("Saved.", OK_TINT)
	return true


func _say(text: String, tint: Color) -> void:
	_said.text = text
	_said.modulate = tint

#endregion


#region /// layout

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(0, DIAL_H)
	_dial.draw.connect(_draw_dial)
	root.add_child(_dial)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_right())

	_warnings = RichTextLabel.new()
	_warnings.bbcode_enabled = true
	_warnings.fit_content = true
	_warnings.custom_minimum_size = Vector2(0, 62)
	root.add_child(_warnings)

	var bar := HBoxContainer.new()
	root.add_child(bar)
	bar.add_child(_button("Save", _save_pressed,
		"Write every signal to radio_puzzle.tres."))
	bar.add_child(_button("Place in scene", _place,
		"Drop this signal's node into the level that is open, already pointed at it. Then just drag it where the puzzle is."))
	_said = Label.new()
	bar.add_child(_said)


func _build_left() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(240, 0)
	var head := Label.new()
	head.text = "Signals"
	head.add_theme_color_override("font_color", DIM)
	side.add_child(head)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_select)
	side.add_child(_list)

	var row := HBoxContainer.new()
	side.add_child(row)
	row.add_child(_button("Add", _add, "Make a new signal."))
	row.add_child(_button("Delete", _delete, "Remove the selected signal."))
	return side


func _build_right() -> Control:
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 6)

	_name_box = LineEdit.new()
	_name_box.placeholder_text = "e.g. statue_hum"
	_name_box.text_changed.connect(func(_t: String) -> void: _write())
	_form.add_child(_row("Name", _name_box))

	_type_box = OptionButton.new()
	_type_box.add_item("SIDE  -  silent until the player tunes to it")
	_type_box.add_item("MAIN  -  opens the radio by itself when nearby")
	_type_box.item_selected.connect(func(_i: int) -> void: _write())
	_form.add_child(_row("Kind", _type_box))

	_freq_slider = HSlider.new()
	_freq_slider.min_value = RadioMaker_v1Puzzle.MIN_HZ
	_freq_slider.max_value = RadioMaker_v1Puzzle.MAX_HZ
	_freq_slider.step = RadioMaker_v1Puzzle.STEP_HZ
	_freq_slider.value_changed.connect(func(_v: float) -> void: _write())
	_freq_label = Label.new()
	_freq_label.custom_minimum_size = Vector2(72, 0)
	_freq_row = _row("Frequency", _freq_slider, _freq_label)
	_form.add_child(_freq_row)

	_reach_slider = HSlider.new()
	_reach_slider.min_value = 50
	_reach_slider.max_value = 1500
	_reach_slider.step = 10
	_reach_slider.value_changed.connect(func(_v: float) -> void: _write())
	_reach_label = Label.new()
	_reach_label.custom_minimum_size = Vector2(72, 0)
	_form.add_child(_row("Reach", _reach_slider, _reach_label))

	_order_box = SpinBox.new()
	_order_box.max_value = 99
	_order_box.value_changed.connect(func(_v: float) -> void: _write())
	_order_row = _row("Order", _order_box)
	_form.add_child(_order_row)

	_puzzle_box = LineEdit.new()
	_puzzle_box.placeholder_text = "GameState id, so it goes quiet once solved (optional)"
	_puzzle_box.text_changed.connect(func(_t: String) -> void: _write())
	_form.add_child(_row("Puzzle id", _puzzle_box))

	_form.add_child(HSeparator.new())

	_reward_box = OptionButton.new()
	for reward_name in REWARD_NAMES:
		_reward_box.add_item(reward_name)
	_reward_box.item_selected.connect(func(_i: int) -> void: _write())
	_form.add_child(_row("When caught", _reward_box))

	_value_box = LineEdit.new()
	_value_box.text_changed.connect(func(_t: String) -> void: _write())
	_value_name = Label.new()
	_value_name.custom_minimum_size = Vector2(120, 0)
	_value_name.add_theme_color_override("font_color", DIM)
	var vrow := HBoxContainer.new()
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(120, 0)
	vrow.add_child(spacer)
	vrow.add_child(_value_name)
	_value_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vrow.add_child(_value_box)
	_form.add_child(vrow)
	return _form


## One labelled row of the form. `extra` sits after the control when given.
func _row(label: String, control: Control, extra: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var tag := Label.new()
	tag.text = label
	tag.custom_minimum_size = Vector2(120, 0)
	tag.add_theme_color_override("font_color", DIM)
	row.add_child(tag)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	if extra != null:
		row.add_child(extra)
	return row


func _button(text: String, handler: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(handler)
	return b

#endregion


#region /// the list and the form

func _refresh_list() -> void:
	var keep: int = _index
	_list.clear()
	for e in _puzzle.entries:
		var id: String = str(e.get("id", ""))
		var tail: String = ("MAIN" if int(e.get("type", 1)) == 0
			else "%d Hz" % int(e.get("frequency", 0)))
		_list.add_item("%s      %s" % [id if id != "" else "(unnamed)", tail])
	if keep >= 0 and keep < _list.item_count:
		_list.select(keep)
	_dial.queue_redraw()
	_refresh_warnings()


func _refresh_warnings() -> void:
	var problems: PackedStringArray = _puzzle.problems()
	if problems.is_empty():
		_warnings.text = "[color=#7ddc84]Nothing wrong. Every signal is reachable, and no two can be mistaken for each other.[/color]"
		return
	var lines: PackedStringArray = []
	for p in problems:
		lines.append("[color=#ffb27d]-  %s[/color]" % p)
	_warnings.text = "\n".join(lines)


func _select(index: int) -> void:
	_index = index
	var has: bool = index >= 0 and index < _puzzle.entries.size()
	_form.visible = has
	if not has:
		return
	var e: Dictionary = _puzzle.entries[index]
	_loading = true
	_name_box.text = str(e.get("id", ""))
	_type_box.selected = 1 if int(e.get("type", 1)) == 0 else 0
	_freq_slider.value = int(e.get("frequency", 630))
	_reach_slider.value = float(e.get("radius", 400.0))
	_order_box.value = int(e.get("order", 0))
	_puzzle_box.text = str(e.get("puzzle_id", ""))
	_reward_box.selected = int(e.get("reward", 0))
	_value_box.text = str(e.get("reward_value", ""))
	_loading = false
	_sync_form()
	_dial.queue_redraw()


## Write the form back into the selected signal. Every box calls this.
func _write() -> void:
	if _loading or _index < 0 or _index >= _puzzle.entries.size():
		return
	var e: Dictionary = _puzzle.entries[_index]
	e["id"] = _name_box.text.strip_edges()
	e["type"] = 0 if _type_box.selected == 1 else 1
	e["frequency"] = int(_freq_slider.value)
	e["radius"] = float(_reach_slider.value)
	e["order"] = int(_order_box.value)
	e["puzzle_id"] = _puzzle_box.text.strip_edges()
	e["reward"] = _reward_box.selected
	e["reward_value"] = _value_box.text.strip_edges()
	_sync_form()
	_refresh_list()
	_say("Unsaved changes.", DIM)


## Show only what this kind of signal actually uses, and say what the one value
## box wants. Same idea as a cutscene step hiding the fields its Kind ignores.
func _sync_form() -> void:
	var is_side: bool = _type_box.selected == 0
	_freq_row.visible = is_side
	_order_row.visible = not is_side
	_freq_label.text = "%d Hz" % int(_freq_slider.value)
	_reach_label.text = "%d px" % int(_reach_slider.value)
	var kind: int = clampi(_reward_box.selected, 0, REWARD_HINTS.size() - 1)
	_value_name.text = REWARD_HINTS[kind]
	_value_box.placeholder_text = REWARD_PLACEHOLDERS[kind]


func _add() -> void:
	_puzzle.entries.append(RadioMaker_v1Puzzle.blank("signal_%d" % (_puzzle.entries.size() + 1)))
	_index = _puzzle.entries.size() - 1
	_refresh_list()
	_list.select(_index)
	_select(_index)


func _delete() -> void:
	if _index < 0 or _index >= _puzzle.entries.size():
		return
	_puzzle.entries.remove_at(_index)
	_index = mini(_index, _puzzle.entries.size() - 1)
	_refresh_list()
	if _index >= 0:
		_list.select(_index)
	_select(_index)

#endregion


#region /// putting one in the level

func _save_pressed() -> void:
	_save()


## Drop the selected signal's node into the open level. Saves first, otherwise
## the node would look for a name that is not in the file yet.
func _place() -> void:
	if _index < 0 or _index >= _puzzle.entries.size():
		_say("Pick a signal first.", BAD_TINT)
		return
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		_say("Open the level you want it in first.", BAD_TINT)
		return
	if not _save():
		return
	var id: String = str(_puzzle.entries[_index].get("id", ""))
	var node: Node2D = load(SIGNAL_SCENE).instantiate()
	node.signal_id = id
	node.name = id if id != "" else "RadioSignal"
	undo.create_action("Place radio signal")
	undo.add_do_method(root, "add_child", node, true)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_reference(node)
	undo.add_undo_method(root, "remove_child", node)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	_say("Placed \"%s\" — now drag it to where the puzzle is." % id, OK_TINT)

#endregion


#region /// the dial

## Where a frequency sits across the strip.
func _x_of(hz: int, width: float) -> float:
	var x: float = remap(float(hz), float(RadioMaker_v1Puzzle.MIN_HZ),
		float(RadioMaker_v1Puzzle.MAX_HZ), 8.0, width - 8.0)
	return clampf(x, 8.0, width - 8.0)


func _draw_dial() -> void:
	var w: float = _dial.size.x
	var axis: float = DIAL_H - 26.0
	var font := ThemeDB.fallback_font

	_dial.draw_line(Vector2(8.0, axis), Vector2(w - 8.0, axis), DIM, 1.0)
	for hz in range(RadioMaker_v1Puzzle.MIN_HZ, RadioMaker_v1Puzzle.MAX_HZ + 1, 100):
		var tick: float = _x_of(hz, w)
		_dial.draw_line(Vector2(tick, axis), Vector2(tick, axis + 5.0), DIM, 1.0)
		if (hz - RadioMaker_v1Puzzle.MIN_HZ) % 200 == 0:
			_dial.draw_string(font, Vector2(tick - 14.0, axis + 20.0),
				str(hz), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM)

	# Which signals sit inside each other's catch band, so they can go red.
	var clashing: Dictionary = {}
	for i in _puzzle.entries.size():
		for j in range(i + 1, _puzzle.entries.size()):
			var a: Dictionary = _puzzle.entries[i]
			var b: Dictionary = _puzzle.entries[j]
			if int(a.get("type", 1)) != 1 or int(b.get("type", 1)) != 1:
				continue
			if absi(int(a.get("frequency", 0)) - int(b.get("frequency", 0))) < RadioMaker_v1Puzzle.BAND:
				clashing[i] = true
				clashing[j] = true

	for i in _puzzle.entries.size():
		var e: Dictionary = _puzzle.entries[i]
		if int(e.get("type", 1)) != 1:
			continue   # MAIN is never tuned to, so it does not belong on a dial
		var hz: int = int(e.get("frequency", 0))
		var tint: Color = BAD_TINT if clashing.has(i) else SIDE_TINT
		if i == _index:
			tint = tint.lightened(0.35)
		var lo: float = _x_of(hz - RadioMaker_v1Puzzle.BAND, w)
		var hi: float = _x_of(hz + RadioMaker_v1Puzzle.BAND, w)
		var top: float = axis - 46.0
		_dial.draw_rect(Rect2(lo, top, hi - lo, 46.0), Color(tint, 0.16))
		var x: float = _x_of(hz, w)
		_dial.draw_line(Vector2(x, top), Vector2(x, axis), tint, 2.0)
		_dial.draw_string(font, Vector2(x - 30.0, top - 4.0),
			str(e.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)

#endregion
