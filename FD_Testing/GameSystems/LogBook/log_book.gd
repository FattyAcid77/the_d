extends Node
## LogBook — add as an Autoload named "LogBook".
## The knowledge board, drawn as a clipboard: notes pinned on the paper,
## the world blurred behind it, sliding up from the bottom when opened.
##
## OPEN/CLOSE: the OPEN_ACTION input action (M as fallback), or LogBook.toggle()
## CONTENT: LogEntry / LogDeduction / LogComment .tres files in ENTRIES_DIR.
## Note art: LogEntry.note_icon (Notes/Note_1.png ...) sizes each card.

const ENTRIES_DIR := "res://FD_Testing/GameSystems/LogBook/Entries"
const OPEN_ACTION := "log"          # <-- your input action name
const FRAME_ART := "res://FD_Testing/GameSystems/LogBook/BOARD_UI.png"
const BLUR_SHADER := "res://FD_Testing/GameSystems/LogBook/blur_background.gdshader"

## The clipboard art is 640x360 and the writable paper sits here inside it
## (measured from BOARD_UI.png). Fractions of the art.
const ART_SIZE := Vector2(640, 360)
const PAPER_L := 0.3391
const PAPER_T := 0.0667
const PAPER_R := 0.6953
const PAPER_B := 0.9306

## How much of the screen the clipboard fills (1.0 = edge to edge).
@export var board_scale: float = 0.94
## Fine-tune the paper window inside the art: x, y, width, height fractions.
## Defaults measured from BOARD_UI.png; change if the artist redraws it.
@export var paper_rect := Rect2(PAPER_L, PAPER_T, PAPER_R - PAPER_L, PAPER_B - PAPER_T)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.5
const DEFAULT_CARD := Vector2(120, 90)

## How far a card can be dragged from home (ignored if player_can_rearrange).
const JIGGLE_RADIUS := 40.0
const SPRING_STIFFNESS := 140.0
const SPRING_DAMPING := 9.0

## How much empty space is allowed past the outermost note when panning.
const PAN_PADDING := 60.0

@export var slide_seconds: float = 0.42
## ON = the board is INFINITE: pan as far as you like in any direction.
## OFF = panning is limited to the notes plus a margin.
@export var infinite_board: bool = true
## ON = the player can drag notes anywhere (positions are remembered).
@export var player_can_rearrange: bool = false
## ON = comment boxes marked dev_only are drawn (turn OFF for release).
@export var show_dev_comments: bool = true

var entries: Array[LogEntry] = []
var deductions: Array[LogDeduction] = []
var comments: Array[LogComment] = []
var is_open: bool = false

var _layer: CanvasLayer
var _blur: ColorRect
var _root: Control          # slides up/down
var _frame: TextureRect
var _svc: SubViewportContainer   # clips the paper area
var _sv: SubViewport
var _board: Node2D          # pans/zooms inside the paper
var _lines: Node2D
var _fact_panel: PanelContainer
var _fact_title: Label
var _fact_text: RichTextLabel
var _toast: Label
var _tween: Tween

var _cards := {}
var _link_lines: Array = []
var _temp_lines: Array = []
var _comment_nodes: Array = []
var _active_deduction := ""
var _connections := {}
var _drag_card := {}
var _drag_moved := false
var _panning := false
var _was_paused := false
var _content_rect := Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_content()
	_build_ui()


func _load_content() -> void:
	entries.clear()
	deductions.clear()
	comments.clear()
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


# --- open / close (with the slide) ----------------------------------------

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
	_layout()
	_refresh()
	_layer.visible = true
	_blur.visible = true
	# start below the screen and glide up
	var h := get_viewport().get_visible_rect().size.y
	_root.position.y = h
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_root, "position:y", 0.0, slide_seconds)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_active_deduction = ""
	_fact_panel.visible = false
	var h := get_viewport().get_visible_rect().size.y
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_root, "position:y", h, slide_seconds * 0.8)
	_tween.tween_callback(func() -> void:
		_layer.visible = false
		get_tree().paused = _was_paused)


# --- layout ----------------------------------------------------------------

func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var s: float = minf(screen.y * board_scale / ART_SIZE.y, screen.x * board_scale / ART_SIZE.x)
	var frame_size := ART_SIZE * s
	var frame_pos := (screen - frame_size) * 0.5
	_frame.position = frame_pos
	_frame.size = frame_size
	# the paper window inside the clipboard art
	_svc.position = frame_pos + Vector2(paper_rect.position.x * frame_size.x,
			paper_rect.position.y * frame_size.y)
	_svc.size = Vector2(paper_rect.size.x * frame_size.x, paper_rect.size.y * frame_size.y)


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
			_fact_panel.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_HOME, KEY_SPACE]:
		# lost in the empty parts of an infinite board? snap back to the notes
		_center_board()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var inside: bool = _svc.get_global_rect().has_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			_panning = event.pressed and inside
		elif event.pressed and inside and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.1, event.position)
		elif event.pressed and inside and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.1, event.position)
	elif event is InputEventMouseMotion and _panning:
		_board.position += event.relative
		_clamp_pan()


func _process(delta: float) -> void:
	if not is_open:
		return
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if pan != Vector2.ZERO:
		_board.position -= pan * 500.0 * delta
		_clamp_pan()
	_spring_step(delta)
	_update_lines()


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var old: float = _board.scale.x
	var new_scale: float = clampf(old * factor, ZOOM_MIN, ZOOM_MAX)
	factor = new_scale / old
	var local := screen_point - _svc.global_position
	_board.position = local + (_board.position - local) * factor
	_board.scale = Vector2.ONE * new_scale
	_clamp_pan()


## Keeps the notes reachable without locking the view in place.
## The pan range is the content size plus a generous margin, so dragging
## always moves — even when only one note is pinned.
func _clamp_pan() -> void:
	if infinite_board:
		return          # no walls — pan forever in any direction
	if _svc == null:
		return
	var view: Vector2 = _svc.size
	if _content_rect.size == Vector2.ZERO:
		return
	var z: float = _board.scale.x
	var cmin: Vector2 = _content_rect.position * z
	var cmax: Vector2 = (_content_rect.position + _content_rect.size) * z
	var slack: Vector2 = view * 0.5 + Vector2(PAN_PADDING, PAN_PADDING)
	var min_p: Vector2 = view - cmax - slack
	var max_p: Vector2 = -cmin + slack
	_board.position.x = clampf(_board.position.x, min_p.x, max_p.x)
	_board.position.y = clampf(_board.position.y, min_p.y, max_p.y)


## Puts the middle of the notes in the middle of the paper.
func _center_board() -> void:
	if _svc == null or _content_rect.size == Vector2.ZERO:
		return
	var z: float = _board.scale.x
	var centre: Vector2 = (_content_rect.position + _content_rect.size * 0.5) * z
	_board.position = _svc.size * 0.5 - centre


# --- springy cards ---------------------------------------------------------

func _spring_step(delta: float) -> void:
	for c in _cards.values():
		var vel: Vector2 = c.vel
		vel += (c.target - c.offset) * SPRING_STIFFNESS * delta
		vel -= vel * SPRING_DAMPING * delta
		c.vel = vel
		c.offset += vel * delta
		var node: Control = c.node
		node.position = c.home + c.offset
		node.rotation = c.tilt + clampf(vel.x * 0.0005, -0.05, 0.05)


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
				Flags.set_flag("logbook_pos:" + id, c.home + c.target)
			_drag_card = {}
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and not _drag_card.is_empty() and _drag_card.id == id:
		var move: Vector2 = event.relative / _board.scale.x
		if move.length() > 0.0:
			_drag_moved = _drag_moved or event.relative.length() > 3.0
			var t: Vector2 = _drag_card.target + move
			if not player_can_rearrange and t.length() > JIGGLE_RADIUS:
				t = t.normalized() * JIGGLE_RADIUS
			_drag_card.target = t


# --- clicking --------------------------------------------------------------

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
		_refresh()
		_show_text(d.result_title, d.result_text)
	else:
		var c: Dictionary = _cards.get(d.id, {})
		if not c.is_empty():
			c.vel += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 800.0
		_show_toast(("%d wrong" % wrong) if wrong > 1 else "1 wrong")


# --- building --------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_blur = ColorRect.new()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BLUR_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(BLUR_SHADER)
		_blur.material = mat
		_blur.color = Color.WHITE
	else:
		_blur.color = Color(0.05, 0.05, 0.07, 0.85)   # fallback: plain dim
	_layer.add_child(_blur)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_frame = TextureRect.new()
	if ResourceLoader.exists(FRAME_ART):
		_frame.texture = load(FRAME_ART)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

	# A SubViewport is what really clips the notes to the paper:
	# Control.clip_contents does NOT clip Node2D children.
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_svc)

	_sv = SubViewport.new()
	_sv.transparent_bg = true
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svc.add_child(_sv)

	_board = Node2D.new()
	_sv.add_child(_board)
	_lines = Node2D.new()
	_board.add_child(_lines)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(-50, 16)
	_toast.visible = false
	_root.add_child(_toast)

	_fact_panel = PanelContainer.new()
	_fact_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_fact_panel.custom_minimum_size = Vector2(300, 0)
	_fact_panel.offset_left = -320
	_fact_panel.visible = false
	_root.add_child(_fact_panel)
	var vb := VBoxContainer.new()
	_fact_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	_fact_title = Label.new()
	_fact_title.add_theme_font_size_override("font_size", 20)
	_fact_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_fact_title)
	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.flat = true
	xbtn.pressed.connect(func() -> void: _fact_panel.visible = false)
	head.add_child(xbtn)
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
	for t in _temp_lines:
		t.queue_free()
	_temp_lines.clear()
	for cb in _comment_nodes:
		cb.queue_free()
	_comment_nodes.clear()

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
		lbl.text = cm.title
		lbl.position = Vector2(6, 2)
		lbl.modulate = Color(0.2, 0.15, 0.1, 0.8)
		box.add_child(lbl)
		_comment_nodes.append(box)

	for e in entries:
		if e.is_discovered():
			_make_card(e.id, e.board_position, false, e, null)
	for d in deductions:
		if d.is_solved() or _all_required_discovered(d):
			_make_card(d.id, d.board_position, true, null, d)

	var drawn := {}
	for e in entries:
		if not e.is_discovered():
			continue
		for other_id in e.links_to:
			_add_link_line(e.id, other_id, drawn, Color(0.35, 0.25, 0.18, 0.5))
	for d in deductions:
		if d.is_solved():
			for src in d.required_entries:
				_add_link_line(d.id, src, drawn, Color(0.75, 0.35, 0.15, 0.65))

	_recalc_content()
	_center_board()
	_clamp_pan()
	_refresh_card_visuals()


func _recalc_content() -> void:
	var r := Rect2()
	var first := true
	for c in _cards.values():
		var node: Control = c.node
		var cr := Rect2(c.home, node.size)
		if first:
			r = cr
			first = false
		else:
			r = r.merge(cr)
	_content_rect = r


func _all_required_discovered(d: LogDeduction) -> bool:
	for id in d.required_entries:
		var e := get_entry(id)
		if e == null or not e.is_discovered():
			return false
	return d.required_entries.size() > 0


func _add_link_line(a: String, b: String, drawn: Dictionary, color: Color) -> void:
	if not _cards.has(a) or not _cards.has(b):
		return
	var key := (a + "|" + b) if a < b else (b + "|" + a)
	if drawn.has(key):
		return
	drawn[key] = true
	var line := Line2D.new()
	line.width = 2.5
	line.default_color = color
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	_lines.add_child(line)
	_link_lines.append({"a": a, "b": b, "line": line})


func _update_lines() -> void:
	for l in _link_lines:
		if _cards.has(l.a) and _cards.has(l.b):
			l.line.set_point_position(0, _card_centre(l.a))
			l.line.set_point_position(1, _card_centre(l.b))
	if _active_deduction != "" and _cards.has(_active_deduction):
		var list: Array = _connections.get(_active_deduction, [])
		_ensure_temp_lines(list.size())
		var from := _card_centre(_active_deduction)
		for i in list.size():
			var id: String = list[i]
			if _cards.has(id):
				_temp_lines[i].visible = true
				_temp_lines[i].set_point_position(0, from)
				_temp_lines[i].set_point_position(1, _card_centre(id))
	else:
		for tl in _temp_lines:
			tl.visible = false


func _card_centre(id: String) -> Vector2:
	var c: Dictionary = _cards[id]
	var node: Control = c.node
	return node.position + node.size * 0.5


func _ensure_temp_lines(count: int) -> void:
	while _temp_lines.size() < count:
		var line := Line2D.new()
		line.width = 2.5
		line.default_color = Color(0.2, 0.45, 0.75, 0.8)
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		_lines.add_child(line)
		_temp_lines.append(line)
	for i in _temp_lines.size():
		_temp_lines[i].visible = i < count


func _make_card(id: String, home: Vector2, is_mystery: bool, e: LogEntry, d: LogDeduction) -> void:
	var saved: Variant = Flags.get_flag("logbook_pos:" + id, null)
	if player_can_rearrange and saved is Vector2:
		home = saved

	var card := Control.new()
	card.position = home
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_card_gui_input.bind(id))
	_board.add_child(card)

	var tilt := 0.0
	var data := {"id": id, "node": card, "home": home, "offset": Vector2.ZERO,
			"vel": Vector2.ZERO, "target": Vector2.ZERO, "tilt": 0.0}

	if is_mystery and d and not d.is_solved():
		data["deduction"] = d
		card.size = DEFAULT_CARD * 0.7
		var pin := Panel.new()
		pin.set_anchors_preset(Control.PRESET_FULL_RECT)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pin)
		var plus := Label.new()
		plus.text = "?"
		plus.add_theme_font_size_override("font_size", 34)
		plus.set_anchors_preset(Control.PRESET_FULL_RECT)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(plus)
		var count := Label.new()
		count.name = "Count"
		count.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		count.offset_top = -20.0
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(count)
	else:
		var icon: Texture2D = null
		var title_text := ""
		var scale_mul := 1.0
		if d:
			data["deduction"] = d
			icon = d.result_picture
			title_text = d.result_title
		else:
			data["entry"] = e
			icon = e.note_icon if e.note_icon else e.picture
			title_text = e.title
			scale_mul = e.icon_scale
			tilt = deg_to_rad(e.icon_tilt)
		if icon:
			# the note art decides the card's size — bigger note, bigger card
			card.size = Vector2(icon.get_width(), icon.get_height()) * scale_mul
			var tex := TextureRect.new()
			tex.texture = icon
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_SCALE
			tex.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			card.add_child(tex)
		else:
			card.size = DEFAULT_CARD
			var pin2 := Panel.new()
			pin2.set_anchors_preset(Control.PRESET_FULL_RECT)
			pin2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(pin2)
			var t := Label.new()
			t.text = title_text
			t.clip_text = true
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t.set_anchors_preset(Control.PRESET_FULL_RECT)
			t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(t)

	card.pivot_offset = card.size * 0.5
	card.rotation = tilt
	data["tilt"] = tilt
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
			node.modulate = Color(0.7, 1.0, 0.8) if _active_deduction == d.id else Color.WHITE
		elif c.has("entry") and _active_deduction != "":
			var list: Array = _connections.get(_active_deduction, [])
			node.modulate = Color(0.6, 0.85, 1.0) if list.has(c.id) else Color.WHITE
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
