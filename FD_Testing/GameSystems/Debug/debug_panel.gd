class_name DebugPanel extends CanvasLayer
## F11 in a debug run: put the game in any state without replaying it. See,
## set and clear flags, jump to a checkpoint or progress state, give items,
## heal or kill the player, open popup windows. The game pauses while it's open.
## Flags adds it in debug builds; exported release builds never have it.

## The key that opens and closes it (Esc closes too). Change it here.
const KEY := KEY_F11

var is_open := false
var tabs: TabContainer
var search: LineEdit
var set_box: VBoxContainer
var unset_box: VBoxContainer
var jump_box: VBoxContainer
var items_box: VBoxContainer
var player_box: VBoxContainer
var windows_box: VBoxContainer
## Flag names found in the project's files, plus every flag seen this run.
var known_flags: Array[String] = []
var _root: Control
var _was_paused := false
var _was_mouse := Input.MOUSE_MODE_VISIBLE
var _scanned := false
var _dirty := false
var _keys := {}  # key -> [down last frame, already handled by _input]


func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var flags := get_node_or_null("/root/Flags")
	if flags:
		flags.flag_changed.connect(_on_flag_changed)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY or (is_open and k.keycode == KEY_ESCAPE):
		_press(k.keycode)
		_keys[k.keycode] = [true, true]
		get_viewport().set_input_as_handled()
	elif is_open and k.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()  # keep TAB away from the Board


func _process(_delta: float) -> void:
	# A popup window can hold the keyboard, and then _input never sees the key.
	# The global key state still does, so watch it too.
	for key in [KEY, KEY_ESCAPE]:
		var st: Array = _keys.get(key, [false, false])
		var down := Input.is_key_pressed(key)
		if down and not st[0] and not st[1] and (key == KEY or is_open):
			_press(key)
		_keys[key] = [down, false]
	if is_open and _dirty:
		_dirty = false
		fill_flags()


func _press(key: int) -> void:
	if key == KEY_ESCAPE or is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	if _root == null:
		_build()
	if not _scanned:
		_scanned = true
		_scan_project()
	is_open = true
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_was_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	search.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _was_mouse


func refresh() -> void:
	fill_flags()
	_fill_jump()
	_fill_items()
	_fill_player()
	_fill_windows()


func _on_flag_changed(flag: String, _value: Variant) -> void:
	if not known_flags.has(flag) and not flag.begins_with("logbook_pos:"):
		known_flags.append(flag)
		known_flags.sort()
	_dirty = true


# --- building ------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.add_to_group("no_mirror")
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing reaches the game
	var th := Theme.new()
	th.default_font_size = clampi(roundi(get_viewport().get_visible_rect().size.y / 34.0), 10, 18)
	_root.theme = th
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_right = 0.92
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.08, 0.96)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var col := VBoxContainer.new()
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "DEBUG   F11 or Esc closes. The game is paused."
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Close", close))

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)

	var flags_tab := _tab("Flags")
	var bar := HBoxContainer.new()
	flags_tab.add_child(bar)
	search = LineEdit.new()
	search.placeholder_text = "search, or type a new flag and press Enter to set it"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_t): fill_flags())
	search.text_submitted.connect(func(t): set_typed(t))
	bar.add_child(search)
	bar.add_child(_button("Set", func(): set_typed(search.text)))
	bar.add_child(_button("Clear all", clear_all_flags))
	flags_tab.add_child(_heading("Set now  (click one to clear it)"))
	set_box = VBoxContainer.new()
	flags_tab.add_child(set_box)
	flags_tab.add_child(_heading("Not set  (click one to set it)"))
	unset_box = VBoxContainer.new()
	flags_tab.add_child(unset_box)

	jump_box = _tab("Jump")
	items_box = _tab("Items")
	player_box = _tab("Player")
	windows_box = _tab("Windows")


## A tab page that scrolls; returns the box to fill.
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	return b


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.55, 0.7, 1.0)
	return l


func _note(box: Container, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.55)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- flags -------------------------------------------------------------------------

func fill_flags() -> void:
	if set_box == null:
		return
	_clear(set_box)
	_clear(unset_box)
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		_note(set_box, "No Flags autoload.")
		return
	var now: Dictionary = flags.to_dict()
	var f := search.text.strip_edges().to_lower()
	var names: Array = now.keys()
	names.sort()
	for n in names:
		if f != "" and not str(n).to_lower().contains(f):
			continue
		var v: Variant = now[n]
		var text := str(n) if typeof(v) == TYPE_BOOL and v else "%s = %s" % [n, v]
		var flag := str(n)
		set_box.add_child(_button("x  " + text, func(): flags.clear_flag(flag)))
	if set_box.get_child_count() == 0:
		_note(set_box, "None." if f == "" else "None match.")
	var shown := 0
	for n in known_flags:
		if now.has(n) or (f != "" and not n.to_lower().contains(f)):
			continue
		if shown >= 300:
			_note(unset_box, "More... type to narrow it down.")
			break
		var flag := n
		unset_box.add_child(_button("+  " + n, func(): flags.set_flag(flag)))
		shown += 1
	if shown == 0:
		_note(unset_box, "None." if f == "" else "None match. Enter sets '%s' anyway." % search.text.strip_edges())


func set_typed(text: String) -> void:
	var n := text.strip_edges()
	var flags := get_node_or_null("/root/Flags")
	if n == "" or flags == null:
		return
	flags.set_flag(n)
	search.text = ""
	fill_flags()


func clear_all_flags() -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		return
	for n in flags.to_dict().keys():
		flags.clear_flag(str(n))  # one by one, so everything listening hears it
	fill_flags()


## Flag names from the project's text files (a run from the editor). An
## exported build has no text files; there it lists the flags seen this run
## and the ones the game makes from items, deaths and windows.
func _scan_project() -> void:
	var found := {}
	var files: Array[String] = []
	_walk("res://", files)
	var prop := RegEx.create_from_string("(?m)^([a-z_]*flag[a-z_]*) = (.*)$")
	var call := RegEx.create_from_string("(?:set_flag|toggle_flag|clear_flag|is_set)\\(\\s*\"([^\"]+)\"\\s*[,)]")
	var verb := RegEx.create_from_string("(?:action_name|action) = \"(?:set_flag|clear_flag|toggle_flag)")
	var args := RegEx.create_from_string("(?m)^(?:action_args|args) = [^\\n]*?\"([^\"]*)\"")
	var quoted := RegEx.create_from_string("\"([^\"]+)\"")
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		if not text.contains("flag") and not text.contains("is_set"):
			continue
		for m in call.search_all(text):
			found[m.get_string(1)] = true
		if path.ends_with(".gd"):
			continue
		for m in prop.search_all(text):
			var key := m.get_string(1)
			if key.contains("prefix") or key == "flag_layers":
				continue
			for q in quoted.search_all(m.get_string(2)):
				found[q.get_string(1)] = true
		for section in text.split("\n["):
			if verb.search(section):
				var a := args.search(section)
				if a and a.get_string(1) != "":
					found[a.get_string(1)] = true
	for kind in [["MedicalItems", "items", "type", "item:"], ["Deaths", "causes", "id", "died_of:"],
			["PopupWindows", "defs", "id", "window_seen:"]]:
		var node := get_node_or_null("/root/" + str(kind[0]))
		if node:
			for r in node.get(kind[1]):
				if r:
					found[str(kind[3]) + str(r.get(kind[2]))] = true
	for n in found:
		if not known_flags.has(n):
			known_flags.append(n)
	known_flags.sort()


func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir.path_join(n)
		if d.current_is_dir():
			if not n.begins_with(".") and p != "res://addons":
				_walk(p, out)
		elif n.get_extension() in ["tscn", "tres", "gd"]:
			out.append(p)
		n = d.get_next()


# --- jump ----------------------------------------------------------------------------

func _fill_jump() -> void:
	_clear(jump_box)
	jump_box.add_child(_heading("Checkpoints  (sets that checkpoint's flags and loads its scene)"))
	var pres := get_node_or_null("/root/Prescription")
	var cps: Array = []
	if pres:
		cps = pres.checkpoints.filter(func(c): return c != null)
		cps.sort_custom(func(a, b): return a.number < b.number)
	for c in cps:
		var n: int = c.number
		var label := "#%d  %s  (state %s)" % [n, c.title, c.state_name]
		jump_box.add_child(_button(label, func(): jump_to_checkpoint(n)))
	if cps.is_empty():
		_note(jump_box, "No checkpoints.")

	var gp := get_node_or_null("/root/GameProgress")
	var now := str(gp.current()) if gp else ""
	jump_box.add_child(_heading("Progress states in this scene  (now: %s)" % (now if now != "" else "none")))
	var states := _scene_states()
	for s in states:
		var st := s
		var mark := "> " if st == now else "   "
		jump_box.add_child(_button(mark + st, func(): goto_state(st)))
	if states.is_empty():
		_note(jump_box, "No ProgressStateMachine in this scene.")

	jump_box.add_child(_heading("This room"))
	jump_box.add_child(_button("Reload this room  (flags stay as they are)", reload_room))


func _scene_states() -> Array[String]:
	var out: Array[String] = []
	var scene := get_tree().current_scene
	if scene == null:
		return out
	for m in scene.find_children("*", "Node", true, false):
		if m is ProgressStateMachine:
			for c in m.get_children():
				if c is ProgressState and not out.has(String(c.name)):
					out.append(String(c.name))
	return out


func jump_to_checkpoint(number: int) -> void:
	close()
	var pres := get_node_or_null("/root/Prescription")
	if pres:
		pres.apply(number)


func goto_state(state: String) -> void:
	var gp := get_node_or_null("/root/GameProgress")
	if gp:
		gp.goto_state(state)
	_fill_jump()


func reload_room() -> void:
	close()
	get_tree().reload_current_scene()


# --- items ---------------------------------------------------------------------------

func _fill_items() -> void:
	_clear(items_box)
	var reg := get_node_or_null("/root/MedicalItems")
	var bag := get_node_or_null("/root/Bag")
	if reg == null or bag == null:
		_note(items_box, "Needs the MedicalItems and Bag autoloads.")
		return
	items_box.add_child(_heading("In the Bag / give or take one"))
	for item in reg.items:
		if item == null:
			continue
		var it: MedicalItem = item
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s  (%s)   x%d" % [it.display_name, it.type, bag.count_of(it.type)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_button(" +1 ", func():
			bag.add(it, 1)
			_fill_items()))
		row.add_child(_button(" -1 ", func():
			bag.remove(it.type, 1)
			_fill_items()))
		items_box.add_child(row)
	if reg.items.is_empty():
		_note(items_box, "No items found.")


# --- player ----------------------------------------------------------------------------

func _fill_player() -> void:
	_clear(player_box)
	var player := get_tree().get_first_node_in_group("Player")
	player_box.add_child(_heading("Player: %s" % (player.name if player else "none in this scene")))
	for pair in [["Heal fully", "heal", [99999]], ["Stop bleeding", "stop_bleeding", []],
			["Hurt 1", "hurt", [1]], ["Start bleeding", "bleed", []]]:
		var verb: String = pair[1]
		var args: Array = pair[2]
		var b := _button(pair[0], func(): DialogActions.run(get_tree(), verb, args))
		b.disabled = player == null
		player_box.add_child(b)
	var deaths := get_node_or_null("/root/Deaths")
	player_box.add_child(_heading("Die of...  (closes this and shows the death screen)"))
	if deaths == null:
		_note(player_box, "No Deaths autoload.")
		return
	for c in deaths.causes:
		if c == null:
			continue
		var id: String = c.id
		player_box.add_child(_button("%s   %s" % [id, c.label], func(): die_of(id)))


func die_of(cause_id: String) -> void:
	close()
	var deaths := get_node_or_null("/root/Deaths")
	if deaths:
		deaths.kill(cause_id)


# --- windows ---------------------------------------------------------------------------

func _fill_windows() -> void:
	_clear(windows_box)
	var pw := get_node_or_null("/root/PopupWindows")
	if pw == null:
		_note(windows_box, "No PopupWindows autoload.")
		return
	windows_box.add_child(_heading("Open a popup window  (close this panel to see it move)"))
	var kinds := ["text", "portal", "image", "sound"]
	for d in pw.defs:
		if d == null:
			continue
		var id: String = d.id
		var open_now := " (open)" if pw.is_open(id) else ""
		windows_box.add_child(_button("%s   %s%s" % [id, kinds[clampi(d.kind, 0, 3)], open_now], func():
			pw.open_id(id)
			_take_focus_back.call_deferred()
			_fill_windows()))
	windows_box.add_child(_button("Close all windows", func():
		pw.close_all()
		_fill_windows()))


## A new popup window takes the keyboard; without this F11 and Esc would go
## to it and the panel couldn't be closed.
func _take_focus_back() -> void:
	get_tree().root.grab_focus()
