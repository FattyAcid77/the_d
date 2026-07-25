extends Node
## LogBook v2 — add as an Autoload named "LogBook".
## The knowledge board: entry cards revealed by Flags, springy draggable
## cards, and DEDUCTION puzzles (connect entries to a mystery "+" card).
##
## OPEN/CLOSE: the OPEN_ACTION input action (add it in the Input Map);
## if the action doesn't exist, M works as a fallback. Or LogBook.toggle().
##
## CONTENT: put LogEntry and LogDeduction .tres files in ENTRIES_DIR.
##
## BOARD: drag empty space / arrows = pan, wheel / + - = zoom.
## Cards can be dragged a little around their home (springy, JIGGLE_RADIUS).
## Click a mystery "+" card to activate it, then click entries to connect.

const ENTRIES_DIR := "res://FD_Testing/GameSystems/LogBook/Entries"
const OPEN_ACTION := "log"          # <-- your input action name
const CARD_SIZE := Vector2(150, 110)
const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.2

## How far a card can be dragged away from its home position
## (ignored when player_can_rearrange is ON).
const JIGGLE_RADIUS := 50.0
## Spring feel: higher stiffness = snappier, higher damping = less wobble.
const SPRING_STIFFNESS := 140.0
const SPRING_DAMPING := 9.0

## ON = the player can drag cards ANYWHERE and their positions are
## remembered (saved through Flags). OFF = cards only jiggle near home.
@export var player_can_rearrange: bool = false

## ON = comment boxes marked dev_only are drawn (for you while organizing).
## Turn OFF for the shipped game.
@export var show_dev_comments: bool = true

var entries: Array[LogEntry] = []
var deductions: Array[LogDeduction] = []
var comments: Array[LogComment] = []
var is_open: bool = false

var _layer: CanvasLayer
var _board: Node2D
var _lines: Node2D
var _fact_panel: PanelContainer
var _fact_title: Label
var _fact_text: RichTextLabel
var _toast: Label

# cards: id -> {node, home, offset, vel, target, entry?, deduction?, dragging}
var _cards := {}
var _link_lines: Array = []            # {a, b, line}
var _active_deduction: String = ""     # id of the mystery card being filled
var _connections := {}                 # deduction id -> Array[entry ids]
var _drag_card: Dictionary = {}
var _drag_moved := false
var _panning := false
var _was_paused := false
var _centered := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_content()
	_build_ui()


func _load_content() -> void:
	entries.clear()
	deductions.clear()
	var dir := DirAccess.open(ENTRIES_DIR)
	if dir == null:
		push_warning("LogBook: no entries folder at %s" % ENTRIES_DIR)
		return
	for file in dir.get_files():
		if file.get_extension() != "tres" and file.get_extension() != "res":
			continue
		var r := load(ENTRIES_DIR + "/" + file)
		if r is LogEntry:
			entries.append(r)
		elif r is LogDeduction:
			deductions.append(r)
		elif r is LogComment:
			comments.append(r)


func get_entry(id: String) -> LogEntry:
	for e in entries:
		if e.id == id:
			return e
	return null


func get_deduction(id: String) -> LogDeduction:
	for d in deductions:
		if d.id == id:
			return d
	return null


# --- open / close ----------------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or DialogManager.is_active or Cutscene.is_playing:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	if not _centered:
		_board.position = get_viewport().get_visible_rect().size * 0.5 - CARD_SIZE * 0.5
		_centered = true
	_refresh()
	_layer.visible = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_active_deduction = ""
	_fact_panel.visible = false
	_layer.visible = false
	get_tree().paused = _was_paused


# --- input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pressed_log := false
	if InputMap.has_action(OPEN_ACTION):
		pressed_log = event.is_action_pressed(OPEN_ACTION)
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed_log = event.physical_keycode == KEY_M
	if pressed_log:
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		if _fact_panel.visible:
			_fact_panel.visible = false      # Esc closes the note first...
		else:
			close()                          # ...then the book
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_panning = event.pressed        # only reaches here if no card took it
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.1, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.1, event.position)
	elif event is InputEventMouseMotion and _panning:
		_board.position += event.relative


func _process(delta: float) -> void:
	if not is_open:
		return
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_board.position -= pan * 600.0 * delta
	if Input.is_key_pressed(KEY_EQUAL):
		_zoom_at(1.0 + 1.5 * delta, get_viewport().get_visible_rect().size * 0.5)
	if Input.is_key_pressed(KEY_MINUS):
		_zoom_at(1.0 - 1.5 * delta, get_viewport().get_visible_rect().size * 0.5)
	_spring_step(delta)
	_update_lines()


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var old := _board.scale.x
	var new_scale: float = clampf(old * factor, ZOOM_MIN, ZOOM_MAX)
	factor = new_scale / old
	_board.position = screen_point + (_board.position - screen_point) * factor
	_board.scale = Vector2.ONE * new_scale


# --- the springy cards -----------------------------------------------------

func _spring_step(delta: float) -> void:
	for c in _cards.values():
		var target: Vector2 = c.target
		var vel: Vector2 = c.vel
		vel += (target - c.offset) * SPRING_STIFFNESS * delta
		vel -= vel * SPRING_DAMPING * delta
		c.vel = vel
		c.offset += vel * delta
		var node: Control = c.node
		node.position = c.home + c.offset
		node.rotation = clampf(vel.x * 0.0006, -0.06, 0.06)   # the jiggle


func _card_gui_input(event: InputEvent, id: String) -> void:
	var c: Dictionary = _cards[id]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_card = c
			_drag_moved = false
		else:
			if not _drag_moved:
				_card_clicked(id)
			elif player_can_rearrange:
				# remember where the player left this card (survives saves)
				Flags.set_flag("logbook_pos:" + id, c.home + c.target)
			_drag_card = {}
		_layer.get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _drag_card.is_empty() and _drag_card.id == id:
		var move: Vector2 = event.relative / _board.scale.x
		if move.length() > 0.0:
			_drag_moved = _drag_moved or event.relative.length() > 3.0
			var t: Vector2 = _drag_card.target + move
			if not player_can_rearrange and t.length() > JIGGLE_RADIUS:
				t = t.normalized() * JIGGLE_RADIUS
			_drag_card.target = t


# --- clicking: facts / deduction connecting --------------------------------

func _card_clicked(id: String) -> void:
	var c: Dictionary = _cards[id]
	if c.has("deduction"):
		var d: LogDeduction = c.deduction
		if d.is_solved():
			_show_text(d.result_title, d.result_text)
		else:
			_active_deduction = "" if _active_deduction == d.id else d.id
			_refresh_card_visuals()
		return
	# a normal entry card
	if _active_deduction != "":
		_toggle_connection(_active_deduction, id)
	else:
		var e: LogEntry = c.entry
		var lines: Array[String] = []
		for f in e.known_facts():
			lines.append("•  " + f.text)
		_show_text(e.title, "\n\n".join(lines))


func _toggle_connection(ded_id: String, entry_id: String) -> void:
	if not _connections.has(ded_id):
		_connections[ded_id] = []
	var list: Array = _connections[ded_id]
	if list.has(entry_id):
		list.erase(entry_id)
	else:
		list.append(entry_id)
	_refresh_card_visuals()
	var d := get_deduction(ded_id)
	if d and list.size() == d.needed():
		_evaluate(d)


func _evaluate(d: LogDeduction) -> void:
	var list: Array = _connections.get(d.id, [])
	var wrong := 0
	for id in list:
		if not d.required_entries.has(id):
			wrong += 1
	if wrong == 0:
		Flags.set_flag(d.result_flag)
		_active_deduction = ""
		_connections.erase(d.id)
		_show_toast("!")
		_refresh()
		_show_text(d.result_title, d.result_text)
	else:
		var c: Dictionary = _cards.get(d.id, {})
		if not c.is_empty():
			c.vel += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 900.0
		_show_toast(str(wrong) + " wrong" if wrong > 1 else "1 wrong")


# --- building / refreshing -------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)

	_board = Node2D.new()
	_layer.add_child(_board)
	_lines = Node2D.new()
	_board.add_child(_lines)

	var hint := Label.new()
	hint.text = "drag space: move   wheel: zoom   click card: read   click +: connect mode   Esc: close"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(12, -30)
	hint.modulate = Color(1, 1, 1, 0.55)
	_layer.add_child(hint)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-60, 24)
	_toast.visible = false
	_layer.add_child(_toast)

	_fact_panel = PanelContainer.new()
	_fact_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_fact_panel.custom_minimum_size = Vector2(320, 0)
	_fact_panel.offset_left = -340
	_fact_panel.visible = false
	_layer.add_child(_fact_panel)
	var vb := VBoxContainer.new()
	_fact_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	_fact_title = Label.new()
	_fact_title.add_theme_font_size_override("font_size", 20)
	_fact_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_fact_title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.pressed.connect(func() -> void: _fact_panel.visible = false)
	head.add_child(close_btn)
	_fact_text = RichTextLabel.new()
	_fact_text.bbcode_enabled = true
	_fact_text.fit_content = true
	_fact_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_fact_text)

	_layer.visible = false


func _refresh() -> void:
	for c in _cards.values():
		c.node.queue_free()
	_cards.clear()
	for l in _link_lines:
		l.line.queue_free()
	_link_lines.clear()
	for cb in _comment_nodes:
		cb.queue_free()
	_comment_nodes.clear()

	# comment boxes first, so they sit behind everything
	for cm in comments:
		if cm.dev_only and not show_dev_comments:
			continue
		var box := ColorRect.new()
		box.color = cm.color
		box.position = cm.position
		box.size = cm.size
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(box)
		_board.move_child(box, 0)
		var lbl := Label.new()
		lbl.text = cm.title + ("  [dev]" if cm.dev_only else "")
		lbl.position = Vector2(8, 4)
		lbl.modulate = Color(1, 1, 1, 0.8)
		box.add_child(lbl)
		_comment_nodes.append(box)

	for e in entries:
		if e.is_discovered():
			_make_card(e.id, e.board_position, false, e, null)

	for d in deductions:
		if d.is_solved():
			_make_card(d.id, d.board_position, true, null, d)
		elif _all_required_discovered(d):
			_make_card(d.id, d.board_position, true, null, d)

	# permanent link lines (entry<->entry, and solved deductions to sources)
	var drawn := {}
	for e in entries:
		if not e.is_discovered():
			continue
		for other_id in e.links_to:
			_add_link_line(e.id, other_id, drawn, Color(1, 1, 1, 0.35))
	for d in deductions:
		if d.is_solved():
			for src in d.required_entries:
				_add_link_line(d.id, src, drawn, Color(0.95, 0.75, 0.35, 0.55))

	_refresh_card_visuals()


func _all_required_discovered(d: LogDeduction) -> bool:
	for id in d.required_entries:
		var e := get_entry(id)
		if e == null or not e.is_discovered():
			return false
	return d.required_entries.size() > 0


func _add_link_line(a: String, b: String, drawn: Dictionary, color: Color) -> void:
	if not _cards.has(a) or not _cards.has(b):
		return
	var key := a + "|" + b if a < b else b + "|" + a
	if drawn.has(key):
		return
	drawn[key] = true
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	_lines.add_child(line)
	_link_lines.append({"a": a, "b": b, "line": line})


func _update_lines() -> void:
	for l in _link_lines:
		if _cards.has(l.a) and _cards.has(l.b):
			l.line.set_point_position(0, _cards[l.a].node.position + CARD_SIZE * 0.5)
			l.line.set_point_position(1, _cards[l.b].node.position + CARD_SIZE * 0.5)
	# live connection lines while filling a deduction
	if _active_deduction != "" and _cards.has(_active_deduction):
		var list: Array = _connections.get(_active_deduction, [])
		_ensure_temp_lines(list.size())
		var from: Vector2 = _cards[_active_deduction].node.position + CARD_SIZE * 0.5
		for i in list.size():
			var id: String = list[i]
			if _cards.has(id):
				_temp_lines[i].visible = true
				_temp_lines[i].set_point_position(0, from)
				_temp_lines[i].set_point_position(1, _cards[id].node.position + CARD_SIZE * 0.5)
	else:
		for tl in _temp_lines:
			tl.visible = false


var _temp_lines: Array = []
var _comment_nodes: Array = []

func _ensure_temp_lines(count: int) -> void:
	while _temp_lines.size() < count:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.4, 0.85, 1.0, 0.8)
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		_lines.add_child(line)
		_temp_lines.append(line)
	for i in _temp_lines.size():
		_temp_lines[i].visible = i < count


func _make_card(id: String, home: Vector2, is_mystery: bool, e: LogEntry, d: LogDeduction) -> void:
	# a player-rearranged position wins over the authored home
	var saved: Variant = Flags.get_flag("logbook_pos:" + id, null)
	if player_can_rearrange and saved is Vector2:
		home = saved
	var card := Panel.new()
	card.position = home
	card.size = CARD_SIZE
	card.pivot_offset = CARD_SIZE * 0.5
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_card_gui_input.bind(id))
	_board.add_child(card)

	var data := {"id": id, "node": card, "home": home, "offset": Vector2.ZERO,
			"vel": Vector2.ZERO, "target": Vector2.ZERO}

	if is_mystery and d and not d.is_solved():
		data["deduction"] = d
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 44)
		plus.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(plus)
		var count := Label.new()
		count.name = "Count"
		count.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		count.offset_top = -24.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(count)
	else:
		var title_text := ""
		var strip_color := Color.WHITE
		var pic: Texture2D = null
		if d:                              # a SOLVED deduction card
			data["deduction"] = d
			title_text = d.result_title
			strip_color = d.result_color
			pic = d.result_picture
		else:
			data["entry"] = e
			title_text = e.title
			strip_color = e.color
			pic = e.picture
		var strip := ColorRect.new()
		strip.color = strip_color
		strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
		strip.offset_bottom = 6.0
		card.add_child(strip)
		if pic:
			var img := TextureRect.new()
			img.texture = pic
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.set_anchors_preset(Control.PRESET_FULL_RECT)
			img.offset_top = 8.0
			img.offset_bottom = -26.0
			card.add_child(img)
		var title := Label.new()
		title.text = title_text
		title.clip_text = true
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		title.offset_top = -24.0
		card.add_child(title)

	_cards[id] = data


func _refresh_card_visuals() -> void:
	for id in _cards:
		var c: Dictionary = _cards[id]
		var node: Control = c.node
		if c.has("deduction") and not (c.deduction as LogDeduction).is_solved():
			var d: LogDeduction = c.deduction
			var connected: int = _connections.get(d.id, []).size()
			var count_label := node.get_node_or_null("Count") as Label
			if count_label:
				count_label.text = "%d / %d" % [connected, d.needed()]
			node.modulate = Color(0.6, 1.0, 0.8) if _active_deduction == d.id else Color.WHITE
		elif c.has("entry") and _active_deduction != "":
			var list: Array = _connections.get(_active_deduction, [])
			node.modulate = Color(0.55, 0.9, 1.0) if list.has(c.id) else Color.WHITE
		else:
			node.modulate = Color.WHITE


func _show_text(title: String, text: String) -> void:
	_fact_title.text = title
	_fact_text.text = text
	_fact_panel.visible = true


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.visible = true
	var t := get_tree().create_timer(1.6, true, false, true)
	t.timeout.connect(func() -> void: _toast.visible = false)
