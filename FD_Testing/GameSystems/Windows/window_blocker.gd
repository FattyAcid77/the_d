class_name WindowBlocker extends Area2D
## A thing INSIDE THE GAME that a popup window cannot be dragged over.
##
## Put one in your level around a rock, a door, a corpse — anything. When the
## player drags a popup window across their desktop and it reaches this spot
## in the game, the window STOPS dead, like it hit a wall, and its title and
## text change to whatever you set here.
##
## The window is on the desktop. The rock is in the level. WindowSpace does
## the maths that connects them, taking the camera into account — so if the
## camera moves, the blocked area moves with the rock, exactly as it should.
##
## SCENE SHAPE
##   WindowBlocker (Area2D, this script)
##   └── CollisionShape2D        <- draw the blocked area over the thing
##
## The CollisionShape2D is only used to work out the rectangle. Its collision
## layers don't matter and nothing physical ever touches it.

signal window_blocked(window: PopupWindow)
signal window_released(window: PopupWindow)

@export_group("What it does to the window")
## Physically stop the window. OFF = the window passes over freely and only
## the text changes.
@export var blocks: bool = true
## New title bar text while the window is touching this. Empty = unchanged.
@export var new_title: String = ""
## New body text while the window is touching this. Empty = unchanged.
@export_multiline var new_text: String = ""
## Put the old title and text back when the window is dragged away.
## OFF = the change sticks for good.
@export var restore_on_leave: bool = true

@export_group("Which windows")
## Only these window ids are affected. Empty = every window.
@export var only_window_ids: Array[String] = []
## These ids are never affected.
@export var ignore_window_ids: Array[String] = []

@export_group("Flags")
## The blocker only exists once this flag is set. Empty = always there.
@export var require_flag: String = ""
## Dead once this flag is set — windows pass over freely again.
@export var hide_flag: String = ""
## Flag set the first time a window is stopped here.
@export var set_flag: String = ""

@export_group("Feel")
## Play this the moment a window is stopped.
@export var bump_sound: AudioStream
@export var bump_volume_db: float = 0.0
## Shake the window this many pixels when it's stopped. 0 = no shake.
@export var bump_shake: float = 4.0
## Seconds before the same window can be bumped again (stops sound spam).
@export var bump_cooldown: float = 0.4

@export_group("Debug")
## Draw the blocked area in-game while you're building the level.
@export var show_in_game: bool = false

var _touching: Dictionary = {}      ## window -> {title, text}
var _cooldowns: Dictionary = {}     ## window -> seconds left
var _fired := false


func _ready() -> void:
	add_to_group("window_blockers")
	monitoring = false          # nothing physical ever touches this
	monitorable = false
	if not show_in_game:
		for c in get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.visible = false


func _process(delta: float) -> void:
	for w in _cooldowns.keys():
		_cooldowns[w] = _cooldowns[w] - delta


## Is this blocker switched on right now?
func is_active() -> bool:
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		return true
	if require_flag != "" and not flags.is_set(require_flag):
		return false
	if hide_flag != "" and flags.is_set(hide_flag):
		return false
	return true


## The area it covers, in WORLD coordinates, taken from the CollisionShape2D.
func world_rect() -> Rect2:
	for c in get_children():
		if c is CollisionShape2D and c.shape:
			var r: Rect2 = c.shape.get_rect() if c.shape.has_method("get_rect") \
					else Rect2(-Vector2.ONE * 16, Vector2.ONE * 32)
			return Rect2(global_position + c.position + r.position, r.size)
		if c is CollisionPolygon2D and c.polygon.size() > 1:
			var mn: Vector2 = c.polygon[0]
			var mx: Vector2 = c.polygon[0]
			for p in c.polygon:
				mn = mn.min(p)
				mx = mx.max(p)
			return Rect2(global_position + c.position + mn, mx - mn)
	# no shape drawn — a small default so it still does something
	return Rect2(global_position - Vector2(16, 16), Vector2(32, 32))


## Does this blocker apply to this window?
func affects(w: PopupWindow) -> bool:
	if w == null or w.def == null or not is_active():
		return false
	if ignore_window_ids.has(w.def.id):
		return false
	if not only_window_ids.is_empty() and not only_window_ids.has(w.def.id):
		return false
	return true


## Called by PopupWindow every frame while it overlaps this blocker.
func on_window_touch(w: PopupWindow) -> void:
	if _touching.has(w):
		return                       # already handled, don't re-apply

	_touching[w] = {"title": w.title, "text": w.get_body_text()}

	if new_title != "":
		w.title = tr(new_title)
	if new_text != "":
		w.set_body_text(tr(new_text))

	var flags := get_node_or_null("/root/Flags")
	if flags and set_flag != "" and not _fired:
		flags.set_flag(set_flag)
	_fired = true

	_bump(w)
	window_blocked.emit(w)


## Called by PopupWindow the frame it stops overlapping.
func on_window_leave(w: PopupWindow) -> void:
	if not _touching.has(w):
		return
	var old: Dictionary = _touching[w]
	if restore_on_leave and is_instance_valid(w):
		if new_title != "":
			w.title = old.get("title", w.title)
		if new_text != "":
			w.set_body_text(old.get("text", ""))
	_touching.erase(w)
	window_released.emit(w)


func _bump(w: PopupWindow) -> void:
	var left: float = _cooldowns.get(w, 0.0)
	if left > 0.0:
		return
	_cooldowns[w] = bump_cooldown

	if bump_sound:
		var p := AudioStreamPlayer.new()
		p.stream = bump_sound
		p.volume_db = bump_volume_db
		get_tree().root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

	if bump_shake > 0.0 and is_instance_valid(w):
		w.nudge(bump_shake)
