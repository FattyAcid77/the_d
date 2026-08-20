@tool
extends Control
## The Cutscene dock — a clip timeline you build by dragging.
##
##   PALETTE     seven coloured chips. Drag one onto the timeline to create it.
##   FILMSTRIP   every sheet frame, drawn where it lands in time.
##   RULER       seconds, with the playhead.
##   TRACKS      one row per action type. Clips that overlap in time stack onto
##               sub-lanes inside their row, so nothing is ever hidden behind
##               anything else.
##
## Everything snaps to whole sprite frames, so you never type a number: drop a
## clip on frame 7 and it IS frame 7. Dragging the playhead calls
## `CutSceneMaker_v1Player.preview_at()`, so the viewport shows that exact moment.

const STRIP_H := 58.0
const RULER_H := 18.0
const LANE_H := 36.0
## Strip at the top of every lane where the clip's name is drawn, so a label
## is never hidden underneath an overlapping clip.
const LABEL_H := 14.0
const LANE_GAP := 4.0
const GUTTER := 76.0
const PAD_R := 10.0
const MIN_CLIP_W := 16.0
const EDGE_GRAB := 6.0
## Width of the strip on the right where a cutscene's exits are shown.
const EXIT_W := 168.0
const EXIT_H := 62.0

## Fixed top-to-bottom row order. A clip's Kind decides its row, always, so
## blocks never hop rows while you drag them.
const ROW_ORDER: Array = [
	CutSceneMaker_v1Step.Kind.SAY,
	CutSceneMaker_v1Step.Kind.CAMERA,
	CutSceneMaker_v1Step.Kind.MOVE,
	CutSceneMaker_v1Step.Kind.FADE,
	CutSceneMaker_v1Step.Kind.LETTERBOX,
	CutSceneMaker_v1Step.Kind.SOUND,
	CutSceneMaker_v1Step.Kind.FLAG,
]

enum Grab { NONE, BODY, EDGE_L, EDGE_R }

var undo: EditorUndoRedoManager

var _cine: CutSceneMaker_v1Player = null
var _time: float = 0.0
var _selected: CutSceneMaker_v1Step = null

var _drag: CutSceneMaker_v1Step = null
var _grab: int = Grab.NONE
var _grab_dt: float = 0.0
var _was_time: float = 0.0
var _was_dur: float = 0.0
var _was_lane: int = 0
var _scrubbing: bool = false
## When on, a scrub stays applied so you can park the playhead and study the
## framing. Off (the default) hands everything back the moment you let go.
var _hold_preview: bool = false

# Layout, rebuilt whenever anything is drawn or hit-tested.
var _row_top: Array[float] = []   # y of each row
var _row_lanes: Array[int] = []   # how many sub-lanes each row needed
## Cached exit pictures, so the sheet of a branch target is only read once
## instead of on every redraw.
var _thumbs: Dictionary = {}

var _canvas: Control
var _scroll: ScrollContainer
var _palette: HBoxContainer
var _hint: Label
var _readout: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 320)
	_build()


func set_target(cine: CutSceneMaker_v1Player) -> void:
	if _cine == cine:
		return
	if _cine != null and is_instance_valid(_cine):
		_cine.end_preview()   # never leave the old scene displaced
	_cine = cine
	_selected = null
	_time = 0.0
	_refresh()


func _refresh() -> void:
	var has: bool = _cine != null
	_hint.visible = not has
	_scroll.visible = has
	_palette.visible = has
	if has:
		_cine.preview_at(_time)
	_update_readout()
	_canvas.queue_redraw()


func _update_readout() -> void:
	if _cine == null:
		_readout.text = ""
		return
	_readout.text = "frame %d / %d    t = %.2fs    length %.2fs" % [
		_cine.frame_at(_time), maxi(_cine.frame_count - 1, 0), _time, _cine.end_time()]


## How much time the view spans. Not the same as the cutscene's length: a
## sound can run past the end of the cutscene, and you still need to see where
## it finishes, so the view stretches to fit the longest clip.
func _duration() -> float:
	if _cine == null:
		return 1.0
	var longest: float = _cine.end_time()
	for step in _cine.steps:
		if step != null:
			longest = maxf(longest, step.at_time + step.display_span())
	return maxf(longest, 0.5)


## Seconds per sprite frame — the grid everything snaps to. Falls back to a
## 0.1s grid when there is no sheet to snap against.
func _frame_step() -> float:
	if _cine == null or _cine.fps <= 0.0 or _cine.frame_count <= 1:
		return 0.1
	return 1.0 / _cine.fps


func _snap(t: float) -> float:
	return maxf(0.0, snappedf(t, _frame_step()))


#region /// layout

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := HBoxContainer.new()
	root.add_child(bar)

	var drag_hint := Label.new()
	drag_hint.text = "  Drag onto the timeline:  "
	bar.add_child(drag_hint)

	_palette = HBoxContainer.new()
	bar.add_child(_palette)
	for kind in ROW_ORDER:
		_palette.add_child(_chip(kind))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	bar.add_child(_button("|<", func() -> void: _set_time(0.0), "Go to start"))
	bar.add_child(_button(">|", func() -> void: _set_time(_duration()), "Go to end"))
	bar.add_child(_button("Delete", _delete_selected, "Delete the selected clip (or press Delete)"))
	bar.add_child(_button("Tidy rows", _tidy_rows, "Auto-arrange every row so no clips overlap. Only runs when you click it."))

	var hold := CheckButton.new()
	hold.text = "Hold preview"
	hold.tooltip_text = "On: camera and moved nodes STAY where you scrubbed. Careful, saving while scrubbed saves those positions. Off: everything snaps back when you release."
	hold.toggled.connect(_on_hold_toggled)
	bar.add_child(hold)

	_readout = Label.new()
	bar.add_child(_readout)

	_hint = Label.new()
	_hint.text = "Select a CutSceneMaker_v1Player node to edit its timeline."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_hint)

	# Rows grow when clips stack, so the tracks can outgrow the dock. Scrolling
	# vertically keeps every lane reachable without shrinking anything.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.focus_mode = Control.FOCUS_CLICK
	_canvas.draw.connect(_draw_timeline)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.set_drag_forwarding(Callable(), _can_drop, _drop)
	_scroll.add_child(_canvas)


func _chip(kind: int) -> Button:
	var b := Button.new()
	b.text = str(CutSceneMaker_v1Step.Kind.keys()[kind]).capitalize()
	b.tooltip_text = "Drag onto the timeline to add a %s step" % str(CutSceneMaker_v1Step.Kind.keys()[kind])
	b.add_theme_color_override("font_color", CutSceneMaker_v1Step.KIND_COLORS[kind])
	b.set_drag_forwarding(func(_p: Vector2) -> Variant: return _chip_payload(b, kind), Callable(), Callable())
	# Clicking without dragging still works, so the chips double as Add buttons.
	b.pressed.connect(func() -> void: _add_at_playhead(kind))
	return b


## The preview has to be attached to the control that STARTED the drag, not to
## the panel, or Godot has nothing to draw under the cursor.
func _chip_payload(chip: Button, kind: int) -> Dictionary:
	var preview := Label.new()
	preview.text = "  %s  " % str(CutSceneMaker_v1Step.Kind.keys()[kind])
	preview.add_theme_color_override("font_color", CutSceneMaker_v1Step.KIND_COLORS[kind])
	chip.set_drag_preview(preview)
	return {"cine_kind": kind}


func _button(text: String, handler: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(handler)
	return b

#endregion


#region /// geometry and lane packing

func _track_x() -> float:
	return GUTTER


func _exit_strip_w() -> float:
	if _cine == null or _cine.next_scenes.is_empty():
		return 0.0
	return EXIT_W


func _track_w() -> float:
	return maxf(_canvas.size.x - GUTTER - PAD_R - _exit_strip_w(), 1.0)


func _t_to_x(t: float) -> float:
	return _track_x() + (t / _duration()) * _track_w()


func _x_to_t(x: float) -> float:
	return clampf((x - _track_x()) / _track_w() * _duration(), 0.0, _duration())


func _rows_top() -> float:
	return STRIP_H + RULER_H


func _row_of(step: CutSceneMaker_v1Step) -> int:
	return maxi(ROW_ORDER.find(step.kind), 0)


## Drawn width of a clip. Instant beats get a fixed minimum so they stay
## grabbable; SOUND uses the real (or trimmed) length of the audio.
func _clip_w(step: CutSceneMaker_v1Step) -> float:
	var span: float = step.display_span()
	if span <= 0.0:
		return MIN_CLIP_W
	return maxf(_t_to_x(step.at_time + span) - _t_to_x(step.at_time), MIN_CLIP_W)


## Works out how tall each row is. Lanes are NOT assigned automatically —
## every clip sits on the lane you dragged it to, and two clips are free to
## touch or overlap. A row is only as tall as its deepest clip needs.
func _rebuild_layout() -> void:
	_row_top.clear()
	_row_lanes.clear()
	if _cine == null:
		return

	var deepest: Array[int] = []
	for i in ROW_ORDER.size():
		deepest.append(0)
	for step in _cine.sorted_steps():
		var r: int = _row_of(step)
		deepest[r] = maxi(deepest[r], step.lane)

	var y: float = _rows_top()
	for i in ROW_ORDER.size():
		var lanes: int = deepest[i] + 1
		# While you are dragging, the row you are over grows one spare lane,
		# so there is always somewhere to drop a clip below everything else.
		if _drag != null and _row_of(_drag) == i:
			lanes += 1
		_row_lanes.append(lanes)
		_row_top.append(y)
		y += float(lanes) * LANE_H

	# Let the canvas grow so the ScrollContainer can reach every lane.
	_canvas.custom_minimum_size.y = y + 18.0


## Which sub-lane a y-coordinate falls in, within a given row.
func _lane_at_y(y: float, row: int) -> int:
	var rel: float = y - _row_top[row]
	return clampi(int(floor(rel / LANE_H)), 0, _row_lanes[row] - 1)


## Re-packs every row so nothing overlaps — the old automatic behaviour, but
## only when you ask for it. Greedy first-fit: a clip takes the highest lane
## whose previous clip has already finished. Measured in pixels, so two
## instant beats a hair apart still separate.
## Turning hold OFF must put everything back immediately, or the scene would
## stay displaced until the next click.
func _on_hold_toggled(on: bool) -> void:
	_hold_preview = on
	if not on and _cine != null:
		_cine.end_preview()
		_cine.preview_at(_time)
		_cine.end_preview()
		_canvas.queue_redraw()


func _tidy_rows() -> void:
	if _cine == null:
		return
	var before: Array = []
	for step in _cine.sorted_steps():
		before.append(step.lane)

	var per_row: Array = []
	for i in ROW_ORDER.size():
		per_row.append([])
	for step in _cine.sorted_steps():
		per_row[_row_of(step)].append(step)

	for i in ROW_ORDER.size():
		var lane_ends: Array[float] = []
		for step in per_row[i]:
			var x0: float = _t_to_x(step.at_time)
			var x1: float = x0 + _clip_w(step)
			var placed: bool = false
			for j in lane_ends.size():
				if x0 >= lane_ends[j] + LANE_GAP:
					lane_ends[j] = x1
					step.lane = j
					placed = true
					break
			if not placed:
				lane_ends.append(x1)
				step.lane = lane_ends.size() - 1

	_mark_dirty()
	_refresh()


func _row_h(i: int) -> float:
	return float(_row_lanes[i]) * LANE_H


func _content_h() -> float:
	if _row_top.is_empty():
		return _canvas.size.y
	return _row_top[_row_top.size() - 1] + _row_h(_row_lanes.size() - 1)


func _clip_rect(step: CutSceneMaker_v1Step) -> Rect2:
	if _row_top.is_empty():
		_rebuild_layout()
	var x: float = _t_to_x(step.at_time)
	var y: float = _row_top[_row_of(step)] + float(maxi(step.lane, 0)) * LANE_H
	# The clip body sits BELOW the label strip, leaving room for its name.
	return Rect2(x, y + LABEL_H, _clip_w(step), LANE_H - LABEL_H - 5.0)

#endregion


#region /// drawing

func _draw_timeline() -> void:
	if _cine == null:
		return
	_rebuild_layout()
	var font: Font = get_theme_default_font()
	var fs: int = get_theme_default_font_size()

	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(_canvas.size.x, _content_h() + 18.0)),
		Color(0.11, 0.12, 0.14))
	_draw_filmstrip()
	_draw_ruler(font, fs)
	_draw_rows(font, fs)
	_draw_frame_grid()      # before the clips, so lines sit underneath them
	_draw_clips(font, fs)
	_draw_end_marker(font, fs)
	_draw_exits(font, fs)
	_draw_playhead(font, fs)


func _draw_filmstrip() -> void:
	_canvas.draw_rect(Rect2(_track_x(), 0, _track_w(), STRIP_H), Color(0.07, 0.08, 0.09))
	if _cine.sheet == null or _cine.frame_count < 1 or _cine.fps <= 0.0:
		return
	var tex: Texture2D = _cine.sheet
	var fh: float = float(tex.get_height()) / float(_cine.frame_count)
	var fw: float = float(tex.get_width())
	var thumb_w: float = STRIP_H * (fw / fh)
	var limit: float = _track_x() + _track_w()

	for i in _cine.frame_count:
		var x: float = _t_to_x(float(i) / _cine.fps)
		if x > limit:
			break
		var dest := Rect2(x, 0, thumb_w, STRIP_H)
		var src := Rect2(0, float(i) * fh, fw, fh)
		var over: float = (x + thumb_w) - limit
		if over > 0.0:
			var keep: float = maxf(thumb_w - over, 1.0)
			dest.size.x = keep
			src.size.x = fw * (keep / thumb_w)
		_canvas.draw_texture_rect_region(tex, dest, src)
		_canvas.draw_line(Vector2(x, 0), Vector2(x, STRIP_H), Color(0, 0, 0, 0.55), 1.0)


func _draw_ruler(font: Font, fs: int) -> void:
	var top := STRIP_H
	_canvas.draw_rect(Rect2(_track_x(), top, _track_w(), RULER_H), Color(0.15, 0.16, 0.19))
	var limit: float = _track_x() + _track_w()
	for s in int(ceil(_duration())) + 1:
		var x: float = _t_to_x(float(s))
		if x > limit:
			break
		_canvas.draw_line(Vector2(x, top), Vector2(x, top + RULER_H), Color(0.5, 0.55, 0.6), 1.0)
		_canvas.draw_string(font, Vector2(x + 3, top + RULER_H - 4), "%ds" % s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, Color(0.62, 0.67, 0.72))


func _draw_rows(font: Font, fs: int) -> void:
	var limit: float = _track_x() + _track_w()
	for i in ROW_ORDER.size():
		var y: float = _row_top[i]
		var h: float = _row_h(i)
		var shade := Color(0.145, 0.155, 0.18) if i % 2 == 0 else Color(0.125, 0.135, 0.16)
		_canvas.draw_rect(Rect2(_track_x(), y, _track_w(), h), shade)
		_canvas.draw_line(Vector2(_track_x(), y), Vector2(limit, y), Color(0, 0, 0, 0.4), 1.0)

		# Faint separators between sub-lanes, so a stacked row reads as stacked.
		for j in range(1, _row_lanes[i]):
			var ly: float = y + float(j) * LANE_H
			_canvas.draw_line(Vector2(_track_x(), ly), Vector2(limit, ly), Color(1, 1, 1, 0.05), 1.0)

		var label: String = str(CutSceneMaker_v1Step.Kind.keys()[ROW_ORDER[i]])
		if _row_lanes[i] > 1:
			label += "  x%d" % _row_lanes[i]
		_canvas.draw_string(font, Vector2(6, y + LANE_H - 8), label,
			HORIZONTAL_ALIGNMENT_LEFT, GUTTER - 10, fs - 3,
			Color(CutSceneMaker_v1Step.KIND_COLORS[ROW_ORDER[i]], 0.85))


## One faint line per sprite frame. This is the grid clips snap to, so seeing
## it is what makes the snapping feel deliberate instead of magnetic.
func _draw_frame_grid() -> void:
	if _cine.sheet == null or _cine.frame_count <= 1 or _cine.fps <= 0.0:
		return
	var top: float = _rows_top()
	var bottom: float = _content_h()
	var limit: float = _track_x() + _track_w()
	for i in _cine.frame_count + 1:
		var x: float = _t_to_x(float(i) / _cine.fps)
		if x > limit:
			break
		_canvas.draw_line(Vector2(x, top), Vector2(x, bottom), Color(1, 1, 1, 0.11), 1.0)


func _draw_clips(font: Font, fs: int) -> void:
	var list: Array = _cine.sorted_steps()

	# Rects up front, so each clip can ask what else is sitting on it.
	var rects: Dictionary = {}
	for step in list:
		rects[step] = _clip_rect(step)

	for step in list:
		var r: Rect2 = rects[step]
		var col: Color = step.color()
		var label: String = step.summary()
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3).x

		# The name normally rides ON the card. It is only lifted onto a banner
		# above when it has to be: either another clip covers the space the
		# name would occupy, or the card is too small to hold it.
		var name_area := Rect2(r.position, Vector2(minf(tw + 10.0, r.size.x), r.size.y))
		var covered: bool = false
		for other in list:
			if other != step and rects[other].intersects(name_area):
				covered = true
				break
		var lifted: bool = covered or tw + 10.0 > r.size.x

		# A lifted clip is the one sitting on top of something, so it is drawn
		# see-through: you can read the end of whatever is underneath it. The
		# outline stays solid so its own edges are still exact.
		_canvas.draw_rect(r, Color(col, 0.42 if lifted else 0.85))
		_canvas.draw_rect(r, Color(col.lightened(0.3), 0.95), false, 1.0)

		if step == _selected:
			_canvas.draw_rect(r.grow(2.0), Color(1, 1, 1, 0.95), false, 2.0)
			if step.uses_duration():
				var g := Color(1, 1, 1, 0.9)
				if step.kind != CutSceneMaker_v1Step.Kind.SOUND:
					_canvas.draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), g)
				_canvas.draw_rect(Rect2(r.end.x - 3, r.position.y, 3, r.size.y), g)

		if not lifted:
			# Room to spare and nothing on top: the name sits on the card.
			_canvas.draw_string(font, Vector2(r.position.x, r.end.y - 5.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs - 3, Color(0.06, 0.06, 0.08))
			continue

		# Lifted: a banner above the card, spanning the clip's width so its
		# right edge still shows where the clip ends.
		var tag := Rect2(r.position.x, r.position.y - LABEL_H + 1.0, r.size.x, LABEL_H - 2.0)
		_canvas.draw_rect(tag, Color(col.darkened(0.62), 0.95))
		_canvas.draw_rect(tag, Color(col, 0.85), false, 1.0)
		var tint: Color = Color(1, 1, 1, 0.98) if step == _selected else Color(col.lightened(0.5), 0.98)
		if tw + 10.0 <= tag.size.x:
			_canvas.draw_string(font, Vector2(tag.position.x, tag.end.y - 3.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, fs - 3, tint)
		else:
			# Too narrow even for a banner: spill the name out to the right.
			_canvas.draw_string(font, Vector2(tag.end.x + 4.0, tag.end.y - 3.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, 320.0, fs - 3, tint)


## Where the cutscene actually stops. Anything drawn to the right of this line
## is on the timeline but will never play.
func _draw_end_marker(font: Font, fs: int) -> void:
	var e: float = _cine.end_time()
	if e >= _duration() - 0.001:
		return
	var x: float = _t_to_x(e)
	var bottom: float = _content_h()
	_canvas.draw_line(Vector2(x, STRIP_H), Vector2(x, bottom + 16.0), Color(1.0, 0.75, 0.2, 0.8), 1.0)
	_canvas.draw_string(font, Vector2(x + 4, bottom + 13.0), "cutscene ends %.2fs" % e,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, Color(1.0, 0.78, 0.3, 0.9))


## The cutscene's exits, drawn as cards down the right-hand strip: where it
## can go when it ends, and what has to be true for each one.
##
## The picture comes from the target cutscene's own sprite sheet, so branching
## between cutscenes shows you real artwork without you making thumbnails.
func _draw_exits(font: Font, fs: int) -> void:
	if _cine.next_scenes.is_empty():
		return
	var x: float = _canvas.size.x - EXIT_W + 4.0
	var y: float = _rows_top()
	var live: CutSceneMaker_v1Next = _cine.pick_next()

	_canvas.draw_string(font, Vector2(x, y - 5.0), "GOES TO",
		HORIZONTAL_ALIGNMENT_LEFT, EXIT_W, fs - 3, Color(0.6, 0.65, 0.7))

	for exit in _cine.next_scenes:
		if exit == null:
			continue
		var card := Rect2(x, y, EXIT_W - 10.0, EXIT_H)
		var taken: bool = exit == live
		_canvas.draw_rect(card, Color(0.17, 0.19, 0.23) if taken else Color(0.13, 0.14, 0.16))
		_canvas.draw_rect(card, Color(0.45, 0.85, 0.5, 0.95) if taken else Color(0.32, 0.34, 0.38),
			false, 2.0 if taken else 1.0)

		# Picture on the left of the card.
		var pic: Texture2D = _exit_thumb(exit)
		var pic_rect := Rect2(card.position + Vector2(4, 4), Vector2(52, EXIT_H - 8))
		if pic != null:
			var src := Rect2(0, 0, float(pic.get_width()), float(pic.get_height()))
			_canvas.draw_texture_rect_region(pic, pic_rect, src)
		else:
			_canvas.draw_rect(pic_rect, Color(0.09, 0.1, 0.12))
			_canvas.draw_string(font, pic_rect.position + Vector2(6, 32), "no pic",
				HORIZONTAL_ALIGNMENT_LEFT, 48, fs - 4, Color(0.4, 0.42, 0.46))

		var tx: float = pic_rect.end.x + 6.0
		var tw: float = card.end.x - tx - 4.0
		_canvas.draw_string(font, Vector2(tx, card.position.y + 18.0), exit.title(),
			HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 2,
			Color(1, 1, 1, 0.97) if taken else Color(0.82, 0.85, 0.88))
		_canvas.draw_string(font, Vector2(tx, card.position.y + 34.0), exit.condition_text(),
			HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 4,
			Color(0.55, 0.9, 0.6) if taken else Color(0.6, 0.63, 0.68))
		if taken:
			_canvas.draw_string(font, Vector2(tx, card.position.y + 50.0), "-> taken now",
				HORIZONTAL_ALIGNMENT_LEFT, tw, fs - 4, Color(0.5, 0.88, 0.55))
		y += EXIT_H + 8.0


## First frame of the target cutscene's sheet, or an explicit thumbnail.
func _exit_thumb(exit: CutSceneMaker_v1Next) -> Texture2D:
	if exit.thumbnail != null:
		return exit.thumbnail
	if exit.scene == null:
		return null
	if _thumbs.has(exit.scene):
		return _thumbs[exit.scene]

	var pic: Texture2D = null
	var probe: Node = exit.scene.instantiate()
	var cine: Node = probe if probe is CutSceneMaker_v1Player else probe.get_node_or_null("Cutscene")
	if cine != null and cine is CutSceneMaker_v1Player and cine.sheet != null:
		var sheet: Texture2D = cine.sheet
		var frame_h: int = int(sheet.get_height() / maxi(cine.frame_count, 1))
		var img: Image = sheet.get_image()
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			var one := Image.create(sheet.get_width(), frame_h, false, Image.FORMAT_RGBA8)
			one.blit_rect(img, Rect2i(0, 0, sheet.get_width(), frame_h), Vector2i.ZERO)
			pic = ImageTexture.create_from_image(one)
	probe.free()
	_thumbs[exit.scene] = pic
	return pic


func _draw_playhead(font: Font, fs: int) -> void:
	var x: float = _t_to_x(_time)
	_canvas.draw_line(Vector2(x, 0), Vector2(x, _content_h() + 16.0), Color(1.0, 0.25, 0.3), 2.0)
	_canvas.draw_string(font, Vector2(x + 4, 12), "f%d" % _cine.frame_at(_time),
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.55, 0.6))

#endregion


#region /// hit testing and dragging

## Returns [step, Grab]. Edges only count for kinds that have a duration.
##
## Clips may now sit on top of each other, so order matters: the selected clip
## wins, then the one drawn last (visually on top). Otherwise a buried clip
## would steal every click from the one you can actually see.
func _hit(pos: Vector2) -> Array:
	_rebuild_layout()
	var ordered: Array = _cine.sorted_steps()
	ordered.reverse()
	if _selected != null and _selected in ordered:
		ordered.erase(_selected)
		ordered.push_front(_selected)
	for step in ordered:
		var r: Rect2 = _clip_rect(step)
		if not r.grow(2.0).has_point(pos):
			continue
		if step.uses_duration():
			if absf(pos.x - r.end.x) <= EDGE_GRAB:
				return [step, Grab.EDGE_R]
			# A sound always plays from its beginning, so only the right edge
			# means anything — dragging the left one would imply a start
			# offset we do not support.
			if step.kind != CutSceneMaker_v1Step.Kind.SOUND and absf(pos.x - r.position.x) <= EDGE_GRAB:
				return [step, Grab.EDGE_L]
		return [step, Grab.BODY]
	return [null, Grab.NONE]


func _on_canvas_input(event: InputEvent) -> void:
	if _cine == null:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_delete_selected()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_canvas.grab_focus()
			var hit: Array = _hit(event.position)
			if hit[0] != null:
				_begin_drag(hit[0], hit[1], event.position)
			else:
				_scrubbing = true
				_set_time(_snap(_x_to_t(event.position.x)))
		else:
			if _drag != null:
				_commit_drag()
			_drag = null
			_grab = Grab.NONE
			_scrubbing = false
			# Hand the camera and any moved nodes back the instant you let go,
			# so a scrub can never end up saved into the scene — unless you
			# deliberately asked to hold it.
			if _cine != null and not _hold_preview:
				_cine.end_preview()
				_canvas.queue_redraw()

	elif event is InputEventMouseMotion:
		if _drag != null:
			_apply_drag(event.position)
		elif _scrubbing:
			_set_time(_snap(_x_to_t(event.position.x)))
		else:
			_update_cursor(event.position)


func _update_cursor(pos: Vector2) -> void:
	match _hit(pos)[1]:
		Grab.EDGE_L, Grab.EDGE_R:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_HSIZE
		Grab.BODY:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_MOVE
		_:
			_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _begin_drag(step: CutSceneMaker_v1Step, grab: int, pos: Vector2) -> void:
	_selected = step
	_drag = step
	_grab = grab
	_grab_dt = step.at_time - _x_to_t(pos.x)
	_was_time = step.at_time      # captured once, for a single clean undo
	_was_dur = step.duration
	_was_lane = step.lane
	_inspect(step)
	_canvas.queue_redraw()


func _apply_drag(pos: Vector2) -> void:
	var t: float = _x_to_t(pos.x)
	match _grab:
		Grab.BODY:
			_drag.at_time = _snap(t + _grab_dt)
			# Vertical position picks the sub-lane. Nothing is auto-arranged,
			# so a clip stays exactly where you drop it — including on top of
			# another one, if that is what you want.
			_drag.lane = _lane_at_y(pos.y, _row_of(_drag))
			_set_time(_drag.at_time)
		Grab.EDGE_R:
			# Right edge sets length; the start stays put.
			var want: float = maxf(_snap(t) - _drag.at_time, 0.0)
			# A sound cannot be stretched past the end of the audio file, so
			# clamp there. Dragging to the far end means "play it all".
			if _drag.kind == CutSceneMaker_v1Step.Kind.SOUND:
				want = minf(want, _drag.sound_length())
			_drag.duration = want
			_set_time(_drag.at_time + want)
		Grab.EDGE_L:
			# Left edge moves the start but must keep the END still, so the
			# duration absorbs exactly the same shift.
			var right: float = _was_time + _was_dur
			var new_start: float = clampf(_snap(t), 0.0, right)
			_drag.at_time = new_start
			_drag.duration = right - new_start
			_set_time(new_start)
	_canvas.queue_redraw()


func _set_time(t: float) -> void:
	_time = clampf(t, 0.0, _duration())
	if _cine != null:
		_cine.preview_at(_time)
	_update_readout()
	_canvas.queue_redraw()

#endregion


#region /// creating, deleting, undo

func _can_drop(_pos: Vector2, data: Variant) -> bool:
	return _cine != null and data is Dictionary and data.has("cine_kind")


## The drop only chooses WHEN. The Kind decides which row it lands on, so a
## clip can never end up on a row that does not match what it does.
func _drop(pos: Vector2, data: Variant) -> void:
	var kind: int = int(data["cine_kind"])
	_rebuild_layout()
	var row: int = ROW_ORDER.find(kind)
	var lane: int = _lane_at_y(pos.y, row) if row >= 0 else 0
	_create(kind, _snap(_x_to_t(pos.x)), lane)


func _add_at_playhead(kind: int) -> void:
	if _cine != null:
		_create(kind, _snap(_time), 0)


func _create(kind: int, at: float, lane: int) -> void:
	var step := CutSceneMaker_v1Step.new()
	step.kind = kind
	step.at_time = at
	step.lane = maxi(lane, 0)
	if kind == CutSceneMaker_v1Step.Kind.SOUND:
		step.duration = 0.0   # 0 means "play the whole file"
	var before: Array[CutSceneMaker_v1Step] = _cine.steps.duplicate()
	var after: Array[CutSceneMaker_v1Step] = _cine.steps.duplicate()
	after.append(step)

	if undo != null:
		undo.create_action("Add cutscene step")
		undo.add_do_property(_cine, "steps", after)
		undo.add_undo_property(_cine, "steps", before)
		undo.commit_action()
	else:
		_cine.steps = after

	_selected = step
	_inspect(step)
	_mark_dirty()
	_refresh()


func _delete_selected() -> void:
	if _cine == null or _selected == null:
		return
	var before: Array[CutSceneMaker_v1Step] = _cine.steps.duplicate()
	var after: Array[CutSceneMaker_v1Step] = _cine.steps.duplicate()
	after.erase(_selected)

	if undo != null:
		undo.create_action("Delete cutscene step")
		undo.add_do_property(_cine, "steps", after)
		undo.add_undo_property(_cine, "steps", before)
		undo.commit_action()
	else:
		_cine.steps = after

	_selected = null
	_mark_dirty()
	_refresh()


## One undo entry per drag, registered on release using the values captured
## when the drag started. Doing this per mouse-move would flood the history.
func _commit_drag() -> void:
	if _drag == null:
		return
	var moved: bool = _drag.at_time != _was_time or _drag.duration != _was_dur or _drag.lane != _was_lane
	if undo != null and moved:
		var now_time: float = _drag.at_time
		var now_dur: float = _drag.duration
		undo.create_action("Move cutscene step")
		undo.add_do_property(_drag, "at_time", now_time)
		undo.add_do_property(_drag, "duration", now_dur)
		undo.add_do_property(_drag, "lane", _drag.lane)
		undo.add_undo_property(_drag, "at_time", _was_time)
		undo.add_undo_property(_drag, "duration", _was_dur)
		undo.add_undo_property(_drag, "lane", _was_lane)
		undo.commit_action(false)
	_mark_dirty()
	_refresh()


## EditorInterface only really exists inside the editor, so every call through
## it is guarded. Without this the dock throws whenever it is driven from a
## plain runtime context, such as the test harness.
func _mark_dirty() -> void:
	if Engine.is_editor_hint() and EditorInterface.has_method("mark_scene_as_unsaved"):
		EditorInterface.mark_scene_as_unsaved()


func _inspect(res: Resource) -> void:
	if Engine.is_editor_hint() and EditorInterface.has_method("edit_resource"):
		EditorInterface.edit_resource(res)

#endregion
