class_name NumberBoard extends Area2D
## The board in the room. It holds the numbers the statue gave while SAD,
## jumbled up, and the player drags the tiles into the right order.
##
## TWO PHASES
##   1. COLLECTING — while the statue is sad and saying a real number, walk
##      to the board and press interact to WRITE it down. The very first
##      number is written automatically, to teach what the board is for.
##   2. ORDERING — once the tiles are on the board, open it and drag them
##      into the right order. Correct order = solved.
##
## Scene shape:
##   NumberBoard (Area2D, this script)
##   ├── CollisionShape2D
##   ├── Sprite2D      (the board art)
##   └── Prompt        (optional, shown when the player is near)

signal number_written(text: String)
signal solved

@export_group("Puzzle")
## The correct order, left to right. These must be numbers the statue says
## in its SAD answers, e.g. ["20", "45", "17", "88"].
@export var solution: PackedStringArray = []

## Numbers already printed on the board when the game starts (jumbled).
## Leave empty to start blank and collect everything from the statue.
@export var starting_numbers: PackedStringArray = []

## Write the FIRST real number automatically (the tutorial nudge).
@export var auto_write_first: bool = true

@export var solved_flag: String = "number_board_solved"

@export_group("Look")
@export var board_title: String = "BOARD"
@export var tile_size := Vector2(84, 84)
@export var tile_gap: float = 12.0

var written: PackedStringArray = []     ## what's on the board, in order
var pending: PackedStringArray = []     ## offered by the statue, not written yet
var is_open: bool = false
var is_solved: bool = false

var _player_in := false
var _layer: CanvasLayer
var _panel: PanelContainer
var _row: Control
var _msg: Label
var _tiles: Array = []
var _drag_tile: Control = null
var _drag_from: int = -1
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	written = starting_numbers.duplicate()
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	_build_ui()
	if Flags.is_set(solved_flag):
		is_solved = true


func _process(_delta: float) -> void:
	if is_open or not _player_in or DialogManager.is_active:
		return
	if Input.is_action_just_pressed("interact"):
		# writing a pending number takes priority over opening the board
		if pending.size() > 0:
			_write_next()
		else:
			open()


# --- taking numbers from the statue ---------------------------------------

## Called by RadioStatue when it gives a real (sad) answer.
func offer_numbers(numbers: PackedStringArray) -> void:
	for n in numbers:
		if written.has(n) or pending.has(n):
			continue
		pending.append(n)
	# the very first one writes itself, so the player learns the board exists
	if auto_write_first and written.is_empty() and pending.size() > 0:
		_write_next()


func _write_next() -> void:
	if pending.is_empty():
		return
	var n: String = pending[0]
	pending.remove_at(0)
	written.append(n)
	number_written.emit(n)
	print("NumberBoard: wrote '%s' (%d on the board)" % [n, written.size()])
	if is_open:
		_rebuild_tiles()


# --- the board UI ----------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	get_tree().paused = true
	_rebuild_tiles()
	_msg.text = "" if not is_solved else "SOLVED"
	_layer.visible = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_layer.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 70
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 260)
	_panel.position = Vector2(-280, -130)
	_layer.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	_panel.add_child(vb)

	var title := Label.new()
	title.text = board_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	_row = Control.new()
	_row.custom_minimum_size = Vector2(0, tile_size.y + 20)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_row)

	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 18)
	vb.add_child(_msg)

	var hint := Label.new()
	hint.text = "drag the tiles to reorder    —    Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.55)
	vb.add_child(hint)

	_layer.visible = false


func _rebuild_tiles() -> void:
	for t in _tiles:
		t.queue_free()
	_tiles.clear()
	var total: float = written.size() * tile_size.x + maxf(0.0, written.size() - 1) * tile_gap
	var start_x: float = (_row.size.x - total) * 0.5
	for i in written.size():
		var tile := _make_tile(written[i], i)
		tile.position = Vector2(start_x + i * (tile_size.x + tile_gap), 10)
		_row.add_child(tile)
		_tiles.append(tile)


func _make_tile(text: String, index: int) -> Control:
	var b := Panel.new()
	b.size = tile_size
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.gui_input.connect(_on_tile_input.bind(index))
	var l := Label.new()
	l.text = text
	l.size = tile_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	return b


func _on_tile_input(event: InputEvent, index: int) -> void:
	if is_solved:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = index
			_drag_tile = _tiles[index]
			_drag_tile.modulate = Color(0.7, 0.9, 1.0)
		else:
			if _drag_tile:
				_drag_tile.modulate = Color.WHITE
			var to := _tile_under_mouse()
			if to >= 0 and to != _drag_from:
				_swap(_drag_from, to)
			_drag_tile = null
			_drag_from = -1


func _tile_under_mouse() -> int:
	var m := _row.get_local_mouse_position()
	for i in _tiles.size():
		var t: Control = _tiles[i]
		if Rect2(t.position, t.size).has_point(m):
			return i
	return -1


func _swap(a: int, b: int) -> void:
	var tmp: String = written[a]
	written[a] = written[b]
	written[b] = tmp
	_rebuild_tiles()
	_check()


func _check() -> void:
	if is_solved or solution.is_empty():
		return
	if written.size() != solution.size():
		return
	for i in solution.size():
		if written[i] != solution[i]:
			return
	is_solved = true
	Flags.set_flag(solved_flag)
	_msg.text = "SOLVED"
	solved.emit()
	print("NUMBER BOARD SOLVED — flag '%s' raised." % solved_flag)


func _on_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = true
		if prompt:
			prompt.visible = true


func _on_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body is Player:
		_player_in = false
		if prompt:
			prompt.visible = false
