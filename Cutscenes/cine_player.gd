@tool
class_name CinePlayer
extends CanvasLayer
## A whole cutscene in one node: a sprite-sheet animation, a timeline of
## beats, and a dialogue box. Everything is set in the Inspector.
##
## TO MAKE ONE:
##   1. Duplicate `cine_player.tscn` and rename it.
##   2. Drop your PNG into `sheet`, set `frame_count` and `fps`.
##   3. Fill in `steps`. Each step is a CineStep — see cine_step.gd.
##   4. Drop an Area2D in the level and drag it into `trigger_area`.
## No script edits, ever.
##
## ARABIC WORKS OUT OF THE BOX. Godot's default font has Arabic glyphs, and
## direction is handled in `_ready()`. You only need to touch the font if you
## want a different look (Box/Text and Box/Name -> Theme Overrides -> Fonts);
## check any replacement actually has Arabic glyphs, or you get empty boxes.
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

@export_group("Picture")
## The sprite sheet. Must be a vertical strip of equal frames.
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
## Frames per second the strip plays at.
@export var fps: float = 10.0
## Repeat the strip until the timeline runs out, instead of stopping on the
## last frame.
@export var loop: bool = false

@export_group("Timeline")
@export var steps: Array[CineStep] = []:
	set(value):
		steps = value
		update_configuration_warnings()
## Seconds to linger after the last beat and the animation have both ended.
@export var extra_time: float = 0.5
## Characters per second for the typewriter.
@export var type_speed: float = 30.0

@export_group("Playing")
## Walk into this and the cutscene starts. Leave empty to start it yourself
## by calling `play()`.
@export var trigger_area: Area2D
## Let the player hold the skip key to end it early.
@export var skippable: bool = true
## Name of a flag that remembers this cutscene was seen, e.g. "saw_door".
## Leave empty to let it replay every time. Note: flags reset when the game
## is closed, because nothing in the project saves them yet.
@export var seen_id: String = ""

@onready var art: Sprite2D = $Art
@onready var top_bar: ColorRect = $TopBar
@onready var bottom_bar: ColorRect = $BottomBar
@onready var fade: ColorRect = $Fade
@onready var box: Control = $Box
@onready var name_label: Label = $Box/Name
## A plain Label, not a RichTextLabel, on purpose. Label has a real
## horizontal_alignment property that aligns physically, so Arabic sits against
## the right edge with its punctuation on the left. RichTextLabel can only be
## aligned with BBCode, and BBCode alignment is logical — "right" there means
## "end of line", which in RTL is the left side, i.e. exactly wrong.
@onready var text_label: Label = $Box/Text

var _queue: Array[CineStep] = []
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep running while we pause the game
	_apply_sheet()

	# Set here with the engine's own constant rather than as a number in the
	# .tscn, because the numeric values are not what you'd guess — AUTO is 0.
	# AUTO reads the line and picks the direction itself, which puts Arabic
	# against the right edge with its punctuation on the left. Forcing a
	# direction by hand is what threw "..." to the wrong end of the line.
	text_label.text_direction = Control.TEXT_DIRECTION_AUTO
	name_label.text_direction = Control.TEXT_DIRECTION_AUTO
	if Engine.is_editor_hint():
		return

	visible = false
	box.visible = false
	fade.color.a = 0.0
	_set_bars(0.0)
	set_process(false)

	# A scene change mid-cutscene must not leave the game paused and the
	# player frozen. This is the safety net for every path we didn't think of.
	tree_exiting.connect(_finish)

	if trigger_area != null:
		trigger_area.body_entered.connect(_on_body_entered)
	elif get_tree().current_scene == self:
		play()  # this scene was run on its own with F6


#region /// playing

## Start the cutscene. Safe to call twice — the second call does nothing.
func play() -> void:
	if _started or _finished:
		return
	if seen_id != "" and Flags.is_set(seen_id):
		return
	if not _validate():
		return

	_queue = steps.duplicate()
	_queue.sort_custom(func(a: CineStep, b: CineStep) -> bool: return a.at_time < b.at_time)

	_cam = get_viewport().get_camera_2d()
	if _cam != null:
		_cam_home = _cam.position  # local, so we can put it back exactly

	_was_paused = get_tree().paused
	get_tree().paused = true
	_freeze_player(true)

	_started = true
	visible = true
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

	if _t >= _end_time():
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


func _run(step: CineStep) -> void:
	match step.kind:
		CineStep.Kind.SAY:
			_say(step)
		CineStep.Kind.CAMERA:
			_pan(step)
		CineStep.Kind.MOVE:
			_move(step)
		CineStep.Kind.FADE:
			_slide(fade, "color:a", step.amount, step.duration)
		CineStep.Kind.LETTERBOX:
			_slide_bars(step.amount, step.duration)
		CineStep.Kind.SOUND:
			Audio.play_ui_audio(step.sound)
		CineStep.Kind.FLAG:
			Flags.set_flag(step.flag_name)


## Ends the cutscene early. Flags still get set, so the world doesn't end up
## in a half-finished state just because someone skipped.
func _skip_to_end() -> void:
	while _next < _queue.size():
		if _queue[_next].kind == CineStep.Kind.FLAG:
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

	if is_inside_tree():
		get_tree().paused = _was_paused  # put it back, don't assume it was false
	_freeze_player(false)
	if _cam != null and is_instance_valid(_cam):
		_cam.position = _cam_home

	if seen_id != "":
		Flags.set_flag(seen_id)
	finished.emit()

#endregion


#region /// beats

func _say(step: CineStep) -> void:
	if step.text.is_empty():
		box.visible = false
		return
	name_label.text = step.speaker
	name_label.visible = step.speaker != ""
	# Plain assignment. Do NOT wrap this in alignment tags, and do not force a
	# text_direction here — `_ready()` sets AUTO, which was measured to be the
	# only setting that keeps trailing punctuation ("...", ".") on the left of
	# an Arabic line. Alignment comes from the label's horizontal_alignment.
	text_label.text = step.text
	text_label.visible_characters = 0
	box.visible = true
	_typing = true
	_typed = 0.0
	_holding = step.hold


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


func _pan(step: CineStep) -> void:
	if _cam == null or not is_instance_valid(_cam):
		push_warning("%s: CAMERA step skipped, no active Camera2D." % name)
		return
	# The camera has limit_left/right/top/bottom set from the map bounds, so a
	# target outside those limits will silently clamp. If a pan looks like it
	# stopped short, that's why.
	_slide(_cam, "global_position", step.to_position, step.duration)


func _move(step: CineStep) -> void:
	var node: Node2D = _resolve(step.target) as Node2D
	if node == null:
		push_warning("%s: MOVE step skipped, '%s' is not a Node2D." % [name, step.target])
		return
	_slide(node, "global_position", step.to_position, step.duration)


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


#region /// picture

func _apply_sheet() -> void:
	if art == null or not is_instance_valid(art):
		return
	art.texture = sheet
	art.vframes = maxi(1, frame_count)
	art.frame = 0


func _update_frame() -> void:
	if sheet == null or frame_count <= 1 or fps <= 0.0:
		return
	var f: int = int(_t * fps)
	if loop:
		f = f % frame_count
	art.frame = clampi(f, 0, frame_count - 1)


## The cutscene ends when both the last beat and the animation are done.
func _end_time() -> float:
	var last: float = 0.0
	for step in _queue:
		last = maxf(last, step.at_time)
	var anim: float = 0.0
	if not loop and frame_count > 1 and fps > 0.0:
		anim = float(frame_count) / fps
	return maxf(last, anim) + extra_time

#endregion


#region /// helpers and complaints

## Duck-typed on purpose: any player with these flags works, and a level with
## no player at all is fine too. Matches how deaths.gd does it.
func _freeze_player(frozen: bool) -> void:
	for node in get_tree().get_nodes_in_group("Player"):
		if "input_enabled" in node:
			node.input_enabled = not frozen
		if "can_move" in node:
			node.can_move = not frozen


## Paths in a step are written as seen from the level, not from this node.
func _resolve(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var from: Node = get_parent()
	if from == null:
		from = self
	return from.get_node_or_null(path)


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
		var step: CineStep = steps[i]
		if step == null:
			out.append("Step %d is empty — pick a CineStep for it." % i)
			continue
		match step.kind:
			CineStep.Kind.MOVE:
				if step.target.is_empty():
					out.append("Step %d (MOVE) has no target node." % i)
			CineStep.Kind.SOUND:
				if step.sound == null:
					out.append("Step %d (SOUND) has no sound." % i)
			CineStep.Kind.FLAG:
				if step.flag_name.is_empty():
					out.append("Step %d (FLAG) has no flag name." % i)
	return out


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		play()

#endregion
