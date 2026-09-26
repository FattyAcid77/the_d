@tool
extends EditorProperty
## A SoundHook's hooks as a table: what happens (picked from the target's real
## signals and animations) -> which sound. Same dictionary underneath, so old
## hooks open here unchanged. A key the target doesn't have shows in red.

const Library := preload("library.gd")
const SoundRow := preload("sound_row.gd")

var tools
var box: VBoxContainer
var header: Label
var add_button: Button
var rows: Array = []  # [{key, pick: OptionButton, sound: SoundRow}]
var choices: Array = []
var _target: Node = null
var _built := false


func _init(p_tools) -> void:
	tools = p_tools
	box = VBoxContainer.new()
	add_child(box)
	set_bottom_editor(box)


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	# target_path can change above; follow it
	if _built and _find_target() != _target:
		_rebuild()


func _update_property() -> void:
	_rebuild()


func _find_target() -> Node:
	var hook := get_edited_object() as Node
	if hook == null or not hook.is_inside_tree():
		return null
	var tp: NodePath = hook.get("target_path")
	return hook.get_node_or_null(tp) if not tp.is_empty() else hook.get_parent()


func _hooks() -> Dictionary:
	var v = get_edited_object().get(get_edited_property())
	return v if v != null else {}


func _rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
	rows.clear()
	_built = true
	_target = _find_target()
	choices = Library.hook_choices(_target)
	header = Label.new()
	header.modulate = Color(1, 1, 1, 0.6)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _target:
		var script_name := ""
		if _target.get_script():
			script_name = "  (%s)" % _target.get_script().resource_path.get_file()
		header.text = "Listens to %s%s" % [_target.name, script_name]
	else:
		header.text = "Put this under the node it should listen to, or set Target Path."
	box.add_child(header)
	var hooks := _hooks()
	for key in hooks.keys():
		_add_row(str(key), str(hooks[key]))
	add_button = Button.new()
	add_button.text = "Add hook"
	add_button.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add_button.pressed.connect(add_hook)
	box.add_child(add_button)
	_refresh_used()


# Two lines per hook so both halves stay readable in a narrow inspector:
#   [ what happens            v ] [remove]
#     plays [ sound id  mark  search  play ]
func _add_row(key: String, id: String) -> void:
	var hook_box := VBoxContainer.new()
	hook_box.add_theme_constant_override("separation", 2)
	box.add_child(hook_box)
	var line := HBoxContainer.new()
	hook_box.add_child(line)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.fit_to_longest_item = false
	pick.clip_text = true
	line.add_child(pick)
	var section := ""
	var found := false
	for c in choices:
		if c.section != section:
			section = c.section
			pick.add_separator(section)
		pick.add_item(c.label)
		var i := pick.item_count - 1
		pick.set_item_metadata(i, c.key)
		if c.key == key:
			pick.select(i)
			found = true
	if not found:
		# keep what's saved visible, flagged, so nothing is lost silently
		pick.add_separator("Not on this node")
		pick.add_item("%s  (not on this node)" % key)
		pick.set_item_metadata(pick.item_count - 1, key)
		pick.select(pick.item_count - 1)
		pick.add_theme_color_override("font_color", Color(1, 0.42, 0.42))
		pick.tooltip_text = "The target has no signal or animation called '%s'. Pick another." % key
	var remove := Button.new()
	remove.icon = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
	remove.tooltip_text = "Remove this hook"
	line.add_child(remove)
	var line2 := HBoxContainer.new()
	hook_box.add_child(line2)
	var plays := Label.new()
	plays.text = "   plays"
	plays.modulate = Color(1, 1, 1, 0.6)
	line2.add_child(plays)
	var sound := SoundRow.new(tools)
	line2.add_child(sound)
	sound.set_text(id)
	hook_box.add_child(HSeparator.new())
	var row := {"key": key, "pick": pick, "sound": sound}
	rows.append(row)
	pick.item_selected.connect(func(i): set_key(rows.find(row), str(pick.get_item_metadata(i))))
	sound.committed.connect(func(t): set_sound(rows.find(row), t))
	remove.pressed.connect(func(): remove_hook(rows.find(row)))


## A key already used by one row is greyed out in the others.
func _refresh_used() -> void:
	var used := rows.map(func(r): return r.key)
	for r in rows:
		var pick: OptionButton = r.pick
		for i in pick.item_count:
			if pick.is_item_separator(i):
				continue
			var k := str(pick.get_item_metadata(i))
			pick.set_item_disabled(i, k != r.key and used.has(k))
	add_button.disabled = _first_free() == ""
	add_button.tooltip_text = "Every signal and animation on this node is hooked already." if add_button.disabled else ""


func _first_free() -> String:
	var used := _hooks().keys()
	for c in choices:
		if not used.has(c.key):
			return c.key
	return ""


func add_hook() -> void:
	var k := _first_free()
	if k == "":
		return
	var d := _typed(_hooks())
	d[k] = ""
	emit_changed(get_edited_property(), d)


## Renames a row's key in place, keeping its sound and its position.
func set_key(row: int, key: String) -> void:
	var old: Dictionary = _hooks()
	var old_key := str(rows[row].key)
	if key == old_key or old.has(key):
		return
	var d: Dictionary[String, String] = {}
	for k in old.keys():
		if str(k) == old_key:
			d[key] = str(old[k])
		else:
			d[str(k)] = str(old[k])
	emit_changed(get_edited_property(), d)


func set_sound(row: int, id: String) -> void:
	var old: Dictionary = _hooks()
	var k := str(rows[row].key)
	if str(old.get(k, "")) == id:
		return
	var d := _typed(old)
	d[k] = id
	emit_changed(get_edited_property(), d)


func remove_hook(row: int) -> void:
	var d := _typed(_hooks())
	d.erase(str(rows[row].key))
	emit_changed(get_edited_property(), d)


func _typed(src: Dictionary) -> Dictionary[String, String]:
	var d: Dictionary[String, String] = {}
	for k in src.keys():
		d[str(k)] = str(src[k])
	return d


## The row's dropdown position of a key, for tests and tooling.
func choose_key(row: int, key: String) -> bool:
	var pick: OptionButton = rows[row].pick
	for i in pick.item_count:
		if not pick.is_item_separator(i) and str(pick.get_item_metadata(i)) == key:
			pick.select(i)
			pick.item_selected.emit(i)
			return true
	return false
