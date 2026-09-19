@tool
class_name CutSceneMaker_v1Player
extends CanvasLayer
## A whole cutscene in one node: a sprite-sheet animation, a timeline of
## beats, and a dialogue box. Everything is set in the Inspector.
##
## TO MAKE ONE:
##   1. Duplicate `cine_player.tscn` and rename it.
##   2. Drop your PNG into `sheet`, set `frame_count` and `fps`.
##   3. Open the "Cutscene" dock at the bottom and drag markers onto the
##      timeline. Scrub the playhead to see any moment of the scene.
##   4. Drop an Area2D in the level and drag it into `trigger_area`.
##
## ARABIC WORKS OUT OF THE BOX. Direction is set to AUTO in `_ready()`, which
## keeps trailing punctuation ("...", ".") on the left of an Arabic line.
## Forcing RTL by hand throws it to the wrong end — that was measured.
##
## IT ALWAYS GIVES CONTROL BACK. Every exit path — finishing, skipping, an
## error, or the scene changing underneath it — goes through `_finish()`,
## which unpauses, unfreezes the player, and puts the camera back.

signal finished

## Held for this long, the skip action ends the whole cutscene. A tap only
## advances one line, so mashing the key to read faster can't skip by accident.
const SKIP_HOLD: float = 0.75
const SKIP_ACTION: StringName = &"interact"

## How tall each cinematic bar is at full strength, in viewport pixels.
const BAR_HEIGHT: float = 36.0

enum ArtFit { FILL, FIT, NONE }

@export_group("Picture")
## The sprite sheet. A vertical strip by default; set `columns` for a grid.
@export var sheet: Texture2D:
	set(value):
		sheet = value
		_apply_sheet()
		update_configuration_warnings()
## How many frames are in the strip.
@export var frame_count: int = 1:
	set(value):
		frame_count = maxi(1, value)
		_apply_sheet()
		update_configuration_warnings()
## Columns in the sheet. 1 is a plain vertical strip. Use more when the strip
## would be too tall to load and the frames wrap into columns instead. Frames
## are read left to right, row by row.
@export var columns: int = 1:
	set(value):
		columns = maxi(1, value)
		_apply_sheet()
		update_configuration_warnings()
## Rows in the sheet. 0 works it out from `frame_count`, which is right unless
## the sheet is padded out with whole blank rows.
@export var rows: int = 0:
	set(value):
		rows = maxi(0, value)
		_apply_sheet()
		update_configuration_warnings()
## Frames per second the strip plays at.
@export var fps: float = 10.0:
	set(value):
		fps = maxf(0.0, value)
## Repeat the strip until the timeline runs out.
@export var loop: bool = false
## How the picture is sized against the screen.
##   FILL  covers the whole screen, cropping whatever overflows (default)
##   FIT   shows the whole frame, leaving bars if the shape does not match
##   NONE  leaves the Art node's scale exactly as you set it by hand
@export var art_fit: ArtFit = ArtFit.FILL:
	set(value):
		art_fit = value
		_apply_sheet()

@export_group("Timeline")
@export var steps: Array[CutSceneMaker_v1Step] = []:
	set(value):
		steps = value
		update_configuration_warnings()
## Seconds to linger after the last beat and the animation have both ended.
@export var extra_time: float = 0.5
## Characters per second for the typewriter.
@export var type_speed: float = 30.0

@export_group("Playing")
## Walk into this and the cutscene starts. Leave empty to call `play()`.
@export var trigger_area: Area2D
## Start the moment the scene loads. Use this for a cutscene that IS the
## scene, or a test scene — without it, a nested CutSceneMaker_v1Player just sits there
## waiting for a trigger area or a call to play().
@export var autoplay: bool = false
## Let the player hold the skip key to end it early.
@export var skippable: bool = true
## Only play once this flag is written. Empty = no requirement.
@export var require_flag: String = ""
## Flag written when this ends, and checked before it starts, so it plays once.
@export var seen_id: String = ""

@export_group("Ending")
## Where this cutscene can go when it finishes. Checked TOP TO BOTTOM — the
## first exit whose flags pass is taken, so put the specific ones first and a
## plain fallback last. Empty list = just end and stay where you are.
@export var next_scenes: Array[CutSceneMaker_v1Next] = []:
	set(value):
		next_scenes = value
		update_configuration_warnings()

## Editor only. Scrub this to see the cutscene at any moment. Has no effect
## at runtime. The timeline dock drives it for you.
@export_range(0.0, 60.0, 0.01) var preview_time: float = 0.0:
	set(value):
		preview_time = value
		if Engine.is_editor_hint():
			preview_at(value)

@onready var art: Sprite2D = $Art
@onready var top_bar: ColorRect = $TopBar
@onready var bottom_bar: ColorRect = $BottomBar
@onready var fade: ColorRect = $Fade
@onready var box: Control = $Box
@onready var text_label: Label = $Box/Text
@onready var sfx: AudioStreamPlayer = $Sfx

var _queue: Array[CutSceneMaker_v1Step] = []
var _t: float = 0.0
var _next: int = 0
var _started: bool = false
var _finished: bool = false
var _holding: bool = false
var _typing: bool = false
var _typed: float = 0.0
var _skip_held: float = 0.0
var _was_paused: bool = false
var _bars: float = 0.0
var _cam: Camera2D = null
var _cam_home: Vector2 = Vector2.ZERO
var _line_timer: Tween = null
var _preview_cam: Camera2D = null
var _preview_cam_home: Vector2 = Vector2.ZERO
var _preview_homes: Dictionary = {}   # moved node -> its untouched position
## True when _finish() is running because the node is being removed, rather
## than because the cutscene reached its end. Changing scene in that case
## would fight whatever is already tearing the tree down.
var _exiting: bool = false
var _walker: Node = null           # character a MOVE step is walking right now
var _walker_sprite: Node = null
var _walk_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while we pause the game
	_apply_sheet()

	# Set with the engine's own constant, not a number in the .tscn — the
	# numeric values are not what you'd guess (AUTO is 0). AUTO reads the line
	# and picks the direction itself, which is the only setting that keeps
	# Arabic punctuation on the correct side.
	text_label.text_direction = Control.TEXT_DIRECTION_AUTO

	if Engine.is_editor_hint():
		preview_at(preview_time)
		return

	visible = false
	box.visible = false
	fade.color.a = 0.0
	_set_bars(0.0)
	set_process(false)

	# A scene change mid-cutscene must not leave the game paused and the
	# player frozen. This is the safety net for every path we didn't think of.
	tree_exiting.connect(_on_tree_exiting)

	get_viewport().size_changed.connect(_fit_art)
	_fit_art()

	if trigger_area != null:
		trigger_area.body_entered.connect(_on_body_entered)
	elif autoplay or get_tree().current_scene == self:
		# `current_scene == self` only catches a cutscene run directly with F6.
		# A CutSceneMaker_v1Player sitting inside a bigger scene is NOT the current scene,
		# so it needs `autoplay` or it will never start on its own.
		play()


#region /// playing

## Start the cutscene. Safe to call twice — the second call does nothing.
func play() -> void:
	if _started or _finished:
		return
	if require_flag != "" and not Flags.is_set(require_flag):
		return
	if seen_id != "" and Flags.is_set(seen_id):
		return
	if not _validate():
		return

	_queue = sorted_steps()

	_cam = find_camera()
	if _cam != null:
		_cam_home = _cam.position  # local, so we can put it back exactly

	_was_paused = get_tree().paused
	get_tree().paused = true
	_freeze_player(true)

	_started = true
	visible = true
	box.visible = false
	fade.color.a = 0.0
	_set_bars(0.0)
	set_process(true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _started or _finished:
		return

	if _typing:
		_typed += delta * type_speed
		text_label.visible_characters = int(_typed)
		if _typed >= float(text_label.get_total_character_count()):
			_stop_typing()

	if skippable and InputMap.has_action(SKIP_ACTION):
		if Input.is_action_pressed(SKIP_ACTION):
			_skip_held += delta
			if _skip_held >= SKIP_HOLD:
				_skip_to_end()
				return
		else:
			_skip_held = 0.0

	if _holding:
		return

	_t += delta
	_update_frame()

	while _next < _queue.size() and _queue[_next].at_time <= _t:
		_run(_queue[_next])
		_next += 1
		if _holding:
			return

	if _t >= end_time():
		_finish()


## Advancing a line is event-driven, not polled, so a quick tap between two
## frames is never dropped. Holding to skip stays in `_process`, because that
## one needs to measure time.
func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _started or _finished or not _holding:
		return
	if event.is_action_pressed(SKIP_ACTION):
		_advance()
		get_viewport().set_input_as_handled()


func _run(step: CutSceneMaker_v1Step) -> void:
	match step.kind:
		CutSceneMaker_v1Step.Kind.SAY:
			_say(step)
		CutSceneMaker_v1Step.Kind.CAMERA:
			_pan(step)
		CutSceneMaker_v1Step.Kind.MOVE:
			_move(step)
		CutSceneMaker_v1Step.Kind.FADE:
			_slide(fade, "color:a", step.amount, step.duration)
		CutSceneMaker_v1Step.Kind.LETTERBOX:
			_slide_bars(step.amount, step.duration)
		CutSceneMaker_v1Step.Kind.SOUND:
			_play_sound(step)
		CutSceneMaker_v1Step.Kind.FLAG:
			Flags.set_flag(step.flag_name)


## Ends the cutscene early. Flags still get written, so the world doesn't end
## up half-updated just because someone skipped.
func _skip_to_end() -> void:
	while _next < _queue.size():
		if _queue[_next].kind == CutSceneMaker_v1Step.Kind.FLAG:
			Flags.set_flag(_queue[_next].flag_name)
		_next += 1
	_finish()


## The single exit. Every path ends here, and it only ever runs once.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)

	if not _started:
		return  # never ran, so there is nothing to hand back

	_holding = false
	_typing = false
	visible = false
	# Audio does not care that the layer is hidden, so without this a sound
	# would keep playing after the cutscene is over. Stopping here makes the
	# behaviour match what the timeline's end marker shows.
	sfx.stop()

	if is_inside_tree():
		get_tree().paused = _was_paused  # put it back, don't assume it was false
	_stand()
	_freeze_player(false)
	if _cam != null and is_instance_valid(_cam):
		_cam.position = _cam_home

	if seen_id != "":
		Flags.set_flag(seen_id)
	finished.emit()

	if not _exiting:
		_go_to_next()


func _on_tree_exiting() -> void:
	_exiting = true
	_finish()


## Picks the first exit whose flags pass and changes to it. Deferred, because
## swapping the scene from inside a finish callback would pull the tree out
## from under the code still running.
func _go_to_next() -> void:
	var exit: CutSceneMaker_v1Next = pick_next()
	if exit == null or exit.scene == null:
		return
	get_tree().change_scene_to_packed.call_deferred(exit.scene)


## The exit that would be taken right now, or null. Public so the timeline
## dock can show you which branch is currently live.
func pick_next() -> CutSceneMaker_v1Next:
	for exit in next_scenes:
		if exit != null and exit.can_take():
			return exit
	return null

#endregion


#region /// beats

func _say(step: CutSceneMaker_v1Step) -> void:
	# Any pending auto-hide belongs to the previous line, so drop it first or
	# it will yank this new line off the screen early.
	if _line_timer != null and _line_timer.is_valid():
		_line_timer.kill()
		_line_timer = null

	if step.text.is_empty():
		box.visible = false
		return
	text_label.text = subtitle_of(step)
	text_label.visible_characters = 0
	box.visible = true
	_typing = true
	_typed = 0.0
	_holding = step.hold

	# A line that does not wait for the player can instead be given a length on
	# the timeline: it shows for `duration`, then takes itself away.
	if step.is_timed_line():
		_line_timer = create_tween()
		_line_timer.tween_interval(step.duration)
		_line_timer.tween_callback(func() -> void: box.visible = false)


## God of War style: no box, no name plate — the speaker is folded into one
## centred line, e.g. "Atreus: Hraezlyr." Centring also sidesteps the whole
## left/right alignment problem, since it reads correctly in any language.
func subtitle_of(step: CutSceneMaker_v1Step) -> String:
	if step.speaker.is_empty():
		return step.text
	return "%s: %s" % [step.speaker, step.text]


## Plays a SOUND step, cutting it short if the clip was trimmed on the
## timeline. The stop is scheduled on a tween created by this node, which is
## PROCESS_MODE_ALWAYS, so it still fires while the game is paused.
func _play_sound(step: CutSceneMaker_v1Step) -> void:
	if step.sound == null:
		return
	sfx.stop()
	sfx.stream = step.sound
	sfx.play()
	if step.is_trimmed():
		var t: Tween = create_tween()
		t.tween_interval(step.duration)
		t.tween_callback(sfx.stop)


## First press finishes the typewriter, second press moves on.
func _advance() -> void:
	if _typing:
		_stop_typing()
		return
	_holding = false
	box.visible = false


func _stop_typing() -> void:
	_typing = false
	text_label.visible_characters = -1  # -1 means "show everything"


func _pan(step: CutSceneMaker_v1Step) -> void:
	if _cam == null or not is_instance_valid(_cam):
		push_warning("%s: CAMERA step skipped, no active Camera2D." % name)
		return
	_slide(_cam, "global_position", step.to_position, step.duration)


func _move(step: CutSceneMaker_v1Step) -> void:
	var node: Node = _resolve(step.target)
	if node == null:
		push_warning("%s: MOVE skipped — no node named '%s' inside this cutscene or in the level around it." % [name, step.target])
		return
	# Node2D and Control both have global_position; anything else has no
	# position to slide, so say so rather than failing silently.
	if not (node is Node2D or node is Control):
		push_warning("%s: MOVE skipped — '%s' is a %s, which has no position." % [name, step.target, node.get_class()])
		return
	_walk(node, step.to_position, step.duration)
	_slide(node, "global_position", step.to_position, step.duration)


## A MOVE on someone who can walk turns them the right way and runs their walk
## animation. Their sprite is let through the pause, or it would slide frozen.
func _walk(node: Node, to: Vector2, seconds: float) -> void:
	if not ("direction" in node and node.has_method("SetDirection") and node.has_method("UpdateAnimation")):
		return
	var dir: Vector2 = to - node.global_position
	if dir == Vector2.ZERO:
		return
	# An earlier walk must not stand him up in the middle of this one.
	if _walk_tween != null and _walk_tween.is_valid():
		_walk_tween.kill()
	_stand()

	_walker = node
	_walker_sprite = node.get("anim")
	if _walker_sprite != null:
		_walker_sprite.process_mode = Node.PROCESS_MODE_ALWAYS

	node.direction = Vector2(signf(dir.x), 0.0) if absf(dir.x) >= absf(dir.y) else Vector2(0.0, signf(dir.y))
	node.SetDirection()
	node.UpdateAnimation("Walk")
	# UpdateAnimation ignores a name that is already showing, even when it is
	# sitting stopped on one frame, so start it again by hand.
	if _walker_sprite != null:
		_walker_sprite.play()

	if seconds <= 0.0:
		_stand()
		return
	_walk_tween = create_tween()
	_walk_tween.tween_interval(seconds)
	_walk_tween.tween_callback(_stand)


## Back to standing, and the sprite goes back to obeying the pause.
func _stand() -> void:
	if _walker != null and is_instance_valid(_walker):
		_walker.UpdateAnimation("Idle")
	if _walker_sprite != null and is_instance_valid(_walker_sprite):
		_walker_sprite.process_mode = Node.PROCESS_MODE_INHERIT
	_walker = null
	_walker_sprite = null


## Tweens are created by this node, and this node is PROCESS_MODE_ALWAYS, so
## they keep running while the cutscene has the game paused.
func _slide(node: Object, property: String, to: Variant, seconds: float) -> void:
	if seconds <= 0.0:
		node.set_indexed(property, to)
		return
	create_tween().tween_property(node, property, to, seconds)


func _slide_bars(to: float, seconds: float) -> void:
	if seconds <= 0.0:
		_set_bars(to)
		return
	create_tween().tween_method(_set_bars, _bars, to, seconds)


func _set_bars(amount: float) -> void:
	_bars = amount
	var h: float = BAR_HEIGHT * amount
	top_bar.offset_bottom = h
	bottom_bar.offset_top = -h

#endregion


#region /// editor preview

## Puts the scene into the state it would be in at `t` seconds. Used by the
## timeline dock and the Preview Time slider.
##
## Holds are ignored here on purpose: `at_time` is treated as absolute, so
## scrubbing shows you where a beat sits on the strip. At runtime a held line
## stops the clock, which shifts everything after it.
func preview_at(t: float) -> void:
	if art == null or not is_instance_valid(art):
		return

	art.frame = frame_at(t)
	_set_bars(_channel_at(CutSceneMaker_v1Step.Kind.LETTERBOX, t))
	fade.color.a = _channel_at(CutSceneMaker_v1Step.Kind.FADE, t)
	_preview_camera(t)
	_preview_moves(t)

	var line: CutSceneMaker_v1Step = say_at(t)
	if line == null:
		box.visible = false
	else:
		box.visible = true
		text_label.text = subtitle_of(line)
		text_label.visible_characters = -1
	visible = true


## Puts everything the preview borrowed back where it was: the camera, and
## every node a MOVE step slid. The dock calls this the moment you stop
## dragging, so a scrub can never be saved into the scene.
func end_preview() -> void:
	if _preview_cam != null and is_instance_valid(_preview_cam):
		_preview_cam.global_position = _preview_cam_home
	_preview_cam = null
	for node in _preview_homes.keys():
		if is_instance_valid(node):
			node.global_position = _preview_homes[node]
	_preview_homes.clear()


## Moves the real Camera2D to where it would be at `t`, so scrubbing shows
## camera work instead of leaving it invisible until you press play.
##
## The camera's starting spot is remembered on the first scrub of a drag and
## handed back by `end_preview()`.
func _preview_camera(t: float) -> void:
	var cam: Camera2D = find_camera()
	if cam == null:
		return
	if cam != _preview_cam:
		_preview_cam = cam
		_preview_cam_home = cam.global_position
	cam.global_position = camera_at(t, _preview_cam_home)


## Where the camera sits at `t`, solved from the CAMERA steps.
func camera_at(t: float, from: Vector2) -> Vector2:
	return _solve_position(_steps_of_kind(CutSceneMaker_v1Step.Kind.CAMERA), t, from)


## Walks a list of position steps and returns where the thing is at `t`.
## Shared by CAMERA and MOVE: both chain from wherever the previous step left
## off, and both interpolate when `t` lands mid-slide.
func _solve_position(list: Array, t: float, from: Vector2) -> Vector2:
	var pos: Vector2 = from
	for step in list:
		if t >= step.at_time + step.duration:
			pos = step.to_position
		elif t > step.at_time:
			var k: float = (t - step.at_time) / maxf(step.duration, 0.0001)
			pos = pos.lerp(step.to_position, k)
			break
		else:
			break
	return pos


func _steps_of_kind(kind: int) -> Array:
	var out: Array = []
	for step in sorted_steps():
		if step.kind == kind:
			out.append(step)
	return out


## Same idea as the camera preview, but for every node a MOVE step targets.
## Several MOVE steps on one node chain together, exactly like at runtime.
##
## Each node's untouched position is remembered the first time it is previewed,
## so scrubbing back to 0 returns everything to where you left it.
func _preview_moves(t: float) -> void:
	var by_node: Dictionary = {}
	for step in _steps_of_kind(CutSceneMaker_v1Step.Kind.MOVE):
		var node: Node = _resolve(step.target)
		if node == null or not (node is Node2D or node is Control):
			continue
		if not by_node.has(node):
			by_node[node] = []
		by_node[node].append(step)

	for node in by_node.keys():
		if not is_instance_valid(node):
			continue
		if not _preview_homes.has(node):
			_preview_homes[node] = node.global_position
		node.global_position = _solve_position(by_node[node], t, _preview_homes[node])


## The camera a CAMERA step will drive. Uses the active one at runtime; in the
## editor there is no "active" camera, so it falls back to the first Camera2D
## in the scene around this cutscene.
func find_camera() -> Camera2D:
	if is_inside_tree():
		var active: Camera2D = get_viewport().get_camera_2d()
		if active != null:
			return active
	var root: Node = get_parent()
	return _first_camera(root) if root != null else null


func _first_camera(n: Node) -> Camera2D:
	for child in n.get_children():
		if child is Camera2D:
			return child
		var found: Camera2D = _first_camera(child)
		if found != null:
			return found
	return null


## Which sheet frame is showing at `t`.
func frame_at(t: float) -> int:
	if sheet == null or frame_count <= 1 or fps <= 0.0:
		return 0
	var f: int = int(t * fps)
	if loop:
		f = f % frame_count
	return clampi(f, 0, frame_count - 1)


## The SAY step that would be on screen at `t`, or null if the box is hidden.
func say_at(t: float) -> CutSceneMaker_v1Step:
	var found: CutSceneMaker_v1Step = null
	for step in sorted_steps():
		if step.kind != CutSceneMaker_v1Step.Kind.SAY or step.at_time > t:
			continue
		if step.text.is_empty():
			found = null                       # an empty line hides the box
		elif step.is_timed_line() and t > step.at_time + step.duration:
			found = null                       # this line has already timed out
		else:
			found = step
	return found


## Value of a fading channel (FADE / LETTERBOX) at `t`, interpolated mid-slide
## so scrubbing through a fade actually looks like a fade.
func _channel_at(kind: int, t: float) -> float:
	var value: float = 0.0
	for step in sorted_steps():
		if step.kind != kind:
			continue
		if t >= step.at_time + step.duration:
			value = step.amount
		elif t > step.at_time:
			var k: float = (t - step.at_time) / maxf(step.duration, 0.0001)
			value = lerpf(value, step.amount, k)
			break
		else:
			break
	return value


## Steps in time order. The exported array keeps whatever order you typed.
func sorted_steps() -> Array[CutSceneMaker_v1Step]:
	var out: Array[CutSceneMaker_v1Step] = []
	for step in steps:
		if step != null:
			out.append(step)
	out.sort_custom(func(a: CutSceneMaker_v1Step, b: CutSceneMaker_v1Step) -> bool: return a.at_time < b.at_time)
	return out


## The cutscene ends when both the last beat and the animation are done.
func end_time() -> float:
	var last: float = 0.0
	for step in steps:
		if step != null:
			last = maxf(last, step.at_time + step.span())
	var anim: float = 0.0
	if not loop and frame_count > 1 and fps > 0.0:
		anim = float(frame_count) / fps
	return maxf(last, anim) + extra_time

#endregion


#region /// picture

func _apply_sheet() -> void:
	if art == null or not is_instance_valid(art):
		return
	art.texture = sheet
	art.hframes = maxi(1, columns)
	art.vframes = _sheet_rows()
	art.frame = 0
	_fit_art()


## How many rows the sheet is cut into.
func _sheet_rows() -> int:
	if rows > 0:
		return rows
	return maxi(1, ceili(float(frame_count) / float(maxi(1, columns))))


## Scales the picture to the screen so a sheet does not have to be authored at
## exactly the game's resolution. Without this you must work the scale out by
## hand for every new sheet, which is the one sum this system was meant to
## spare you.
func _fit_art() -> void:
	if art == null or not is_instance_valid(art):
		return
	if art_fit == ArtFit.NONE or sheet == null or frame_count < 1:
		return
	var frame_w: float = float(sheet.get_width()) / float(maxi(1, columns))
	var frame_h: float = float(sheet.get_height()) / float(_sheet_rows())
	if frame_w <= 0.0 or frame_h <= 0.0:
		return

	var view: Vector2 = _view_size()
	var sx: float = view.x / frame_w
	var sy: float = view.y / frame_h
	var factor: float = maxf(sx, sy) if art_fit == ArtFit.FILL else minf(sx, sy)
	art.scale = Vector2(factor, factor)
	art.position = view * 0.5


## The area the picture actually has to cover.
##
## NOT the design size. The project stretches with aspect "expand", so on any
## window that is not 16:9 the visible area grows sideways past 640x360 — and a
## picture fitted to the design size leaves a bar down the edge.
##
## In the editor there is no game window to measure, so the design size is the
## only sane answer there.
func _view_size() -> Vector2:
	var design := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 640)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 360)))
	if Engine.is_editor_hint() or not is_inside_tree():
		return design
	var win: Window = get_window()
	if win == null or design.x <= 0.0 or design.y <= 0.0:
		return design
	var px := Vector2(win.size)
	if px.x <= 1.0 or px.y <= 1.0:
		return design
	# A CanvasLayer has no get_viewport_rect(), and the window is in real
	# pixels, so convert: the canvas is scaled by the SMALLER of the two
	# ratios, and dividing back out gives the visible area in design units.
	var factor: float = minf(px.x / design.x, px.y / design.y)
	if factor <= 0.0:
		return design
	return px / factor


func _update_frame() -> void:
	if sheet == null or frame_count <= 1 or fps <= 0.0:
		return
	art.frame = frame_at(_t)

#endregion


#region /// helpers and complaints

## Duck-typed on purpose: any player with these flags works, and a level with
## no player at all is fine too.
func _freeze_player(frozen: bool) -> void:
	for node in get_tree().get_nodes_in_group("Player"):
		if "input_enabled" in node:
			node.input_enabled = not frozen
		if "can_move" in node:
			node.can_move = not frozen


## Finds the node a MOVE step points at.
##
## Looks INSIDE the cutscene first, then in the level around it. Inside is the
## common case — anything you want to slide across a full-screen cutscene has
## to be a child of this CanvasLayer, because a CanvasLayer draws in screen
## space and level nodes are not in the same coordinate system.
func _resolve(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var found: Node = get_node_or_null(path)
	if found != null:
		return found
	var parent: Node = get_parent()
	if parent != null:
		return parent.get_node_or_null(path)
	return null


## Refuses to start on broken data, and says exactly which step is broken.
func _validate() -> bool:
	var problems: PackedStringArray = _problems()
	for problem in problems:
		push_error("%s: %s" % [name, problem])
	return problems.is_empty()


## Shown as a yellow warning triangle on the node in the scene tree, so you
## find the mistake while building instead of at runtime.
func _get_configuration_warnings() -> PackedStringArray:
	return _problems()


func _problems() -> PackedStringArray:
	var out: PackedStringArray = []
	if sheet != null and frame_count < 1:
		out.append("frame_count must be at least 1.")
	for i in steps.size():
		var step: CutSceneMaker_v1Step = steps[i]
		if step == null:
			out.append("Step %d is empty — pick a CutSceneMaker_v1Step for it." % i)
			continue
		match step.kind:
			CutSceneMaker_v1Step.Kind.MOVE:
				if step.target.is_empty():
					out.append("Step %d (MOVE) has no target node." % i)
			CutSceneMaker_v1Step.Kind.SOUND:
				if step.sound == null:
					out.append("Step %d (SOUND) has no sound." % i)
			CutSceneMaker_v1Step.Kind.FLAG:
				if step.flag_name.is_empty():
					out.append("Step %d (FLAG) has no flag name." % i)
	for j in next_scenes.size():
		if next_scenes[j] == null:
			out.append("Exit %d is empty — pick a CutSceneMaker_v1Next for it." % j)
	return out


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		play()

#endregion
