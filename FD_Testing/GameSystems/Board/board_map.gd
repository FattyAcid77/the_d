class_name BoardMap extends Control
## The map tab. Rooms appear as he finds them, and the little Sami tracks
## where he actually is inside the room he's standing in.

const ART_DIR := "res://FD_Testing/GameSystems/Map/Rooms/Art/"
const BOARD_PATH := ART_DIR + "MAP_BOARD.png"
const MARKER_PATH := ART_DIR + "MAP_MARKER.png"

## The green board with no rooms on it.
var background: Texture2D
## The little Sami who shows where he is.
var marker: Texture2D
## Where the marker's "feet" are inside its own image
@export var marker_anchor: Vector2 = Vector2(4, 8)

@export_group("The marker")
## Gentle bob so he's easy to spot on a busy map.
@export var bob_pixels: float = 1.0
@export var bob_speed: float = 2.5
## Seconds for the marker to glide to a new spot.
@export var marker_smooth: float = 0.12

@export_group("Undiscovered rooms")
## Draw rooms he hasn't found as a faint ghost instead of hiding them.
@export var show_unknown_ghost: bool = false
@export var ghost_modulate: Color = Color(1, 1, 1, 0.09)

@export_group("Labels")
## Write the current room's name on the map.
@export var show_room_name: bool = true
@export var room_name_position: Vector2 = Vector2(320, 330)
@export var room_name_size: int = 9
@export var room_name_color: Color = Color(0.85, 0.9, 0.82, 0.85)
@export var room_name_font: Font

@export_group("The paper it lives on")
## The clipboard's paper area, in canvas pixels.
@export var paper_rect: Rect2 = Rect2(220, 45, 224, 288)

@export_group("Panning and zoom")
## Drag the map around with the mouse.
@export var can_pan: bool = true
## Mouse wheel zoom.
@export var can_zoom: bool = true
@export var zoom_min: float = 0.6
@export var zoom_max: float = 3.0
@export var zoom_step: float = 0.12
## A little slack past the strict limit only when zoomed
@export var pan_padding: float = 6.0
## Double-click (or call recenter()) to snap back to Sami.
@export var double_click_recenters: bool = true

@export_group("Debug")
## Outline each room's rectangle as read from its art.
@export var show_rects: bool = false

var _t := 0.0
var _marker_at := Vector2(-1, -1)
var _pan := Vector2.ZERO
var _zoom := 1.0
var _dragging := false
var _last_mouse := Vector2.ZERO


func _ready() -> void:
	# Sized to the clipboard paper, not the whole canvas, with clipping on.
	position = paper_rect.position
	size = paper_rect.size
	clip_contents = true
	# stop so the map can be dragged.
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(BOARD_PATH):
		background = load(BOARD_PATH) as Texture2D
	else:
		push_error("BoardMap: missing %s" % BOARD_PATH)
	if ResourceLoader.exists(MARKER_PATH):
		marker = load(MARKER_PATH) as Texture2D


func refresh() -> void:
	_marker_at = Vector2(-1, -1)  # snap on reopen, don't glide in
	_clamp_pan()  # never reopen in a drifted position
	queue_redraw()


# --- dragging the map ------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and double_click_recenters:
				recenter()
				accept_event()
				return
			_dragging = can_pan and event.pressed
			_last_mouse = event.position
			accept_event()
		elif can_zoom and event.pressed and event.button_index in \
				[MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var dir := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			_zoom_at(event.position, dir)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_pan += event.position - _last_mouse
		_last_mouse = event.position
		_clamp_pan()
		queue_redraw()
		accept_event()


## Zooms towards the mouse, so the bit you're pointing at stays put.
func _zoom_at(at: Vector2, dir: float) -> void:
	var before := _zoom
	_zoom = clampf(_zoom * (1.0 + zoom_step * dir), zoom_min, zoom_max)
	if is_equal_approx(before, _zoom):
		return
	_pan = at - (at - _pan) * (_zoom / before)
	_clamp_pan()
	queue_redraw()


## The map board's own rectangle on the 640x360 canvas
func _content_rect() -> Rect2:
	if background:
		var img := background.get_image()
		if img:
			var u := img.get_used_rect()
			if u.size.x > 0:
				return Rect2(u.position, u.size)
	return Rect2(Vector2.ZERO, Vector2(640, 360))


## Keeps the map on the paper.
func _clamp_pan() -> void:
	var c := _content_rect()
	var lo := paper_rect.position - c.position * _zoom  # keep left/top in
	var hi := paper_rect.end - c.end * _zoom  # keep right/bottom in
	var pad := Vector2(pan_padding, pan_padding)

	# x - if the map fits across, it is pinned dead centre and does not move at all.
	if lo.x <= hi.x:
		_pan.x = (lo.x + hi.x) * 0.5
	else:
		_pan.x = clampf(_pan.x, hi.x - pad.x, lo.x + pad.x)  # zoomed in: pan
	# y
	if lo.y <= hi.y:
		_pan.y = (lo.y + hi.y) * 0.5
	else:
		_pan.y = clampf(_pan.y, hi.y - pad.y, lo.y + pad.y)


## Back to 1:1, centred on Sami.
func recenter() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_clamp_pan()
	_marker_at = Vector2(-1, -1)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


## Where the marker should be right now, on the map canvas.
func _target() -> Vector2:
	var mr := get_node_or_null("/root/MapRooms")
	if mr == null:
		return Vector2(-1, -1)
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return Vector2(-1, -1)
	return mr.player_map_position(player.global_position)


func _draw() -> void:
	# Everything below is drawn through the pan/zoom transform
	draw_set_transform(_pan - paper_rect.position, 0.0, Vector2(_zoom, _zoom))
	if background:
		draw_texture(background, Vector2.ZERO)

	var mr := get_node_or_null("/root/MapRooms")
	if mr == null:
		return

	# every room he has found, stacked at (0,0)
	for room in mr.rooms:
		if room.art == null:
			continue
		var known: bool = bool(mr.is_discovered(room.id))
		if known:
			draw_texture(room.art, Vector2.ZERO)
		elif show_unknown_ghost:
			draw_texture(room.art, Vector2.ZERO, ghost_modulate)

		if show_rects and known:
			draw_rect(room.rect_on_map(), Color(0, 1, 1, 0.8), false, 1.0)

	# the little Sami
	var want := _target()
	if want.x >= 0.0:
		if _marker_at.x < 0.0 or marker_smooth <= 0.0:
			_marker_at = want
		else:
			_marker_at = _marker_at.lerp(want,
					clampf(get_process_delta_time() / marker_smooth, 0.0, 1.0))

		var bob := Vector2(0, sin(_t * bob_speed) * bob_pixels)
		if marker:
			draw_texture(marker, (_marker_at - marker_anchor + bob).round())
		else:
			draw_circle(_marker_at + bob, 2.0, Color(1, 0.9, 0.3))

	if show_room_name and mr.current_room != "":
		var def = mr.get_room(mr.current_room)
		if def and def.display_name != "":
			var f := room_name_font if room_name_font else ThemeDB.fallback_font
			draw_string(f, room_name_position, tr(def.display_name),
					HORIZONTAL_ALIGNMENT_CENTER, 200, room_name_size, room_name_color)
