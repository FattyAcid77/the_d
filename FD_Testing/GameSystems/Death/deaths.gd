extends Node
## Deaths — add as an Autoload named "Deaths".
##
## THE SEQUENCE when the player dies:
##   1. Sami's death animation plays (his "Death" state)
##   2. the clipboard SLIDES UP from the bottom
##   3. the board ANIMATION plays (BoardAnim/death_board_00..19.png)
##   4. the writing appears: time of death, cause, and the CHECK MARK
##   5. RETRY / QUIT become clickable
##
## KILL THE PLAYER from anywhere:
##     Deaths.kill("bleeding")          # id of a DeathCause .tres
##     Deaths.kill("bleeding", 1.5)     # longer animation beat
## From a dialog line: action_name = "kill", action_args = ["bleeding"]

const CAUSES_DIR := "res://FD_Testing/GameSystems/Death/Causes"
const FRAMES_RES := "res://FD_Testing/GameSystems/Death/board_frames.tres"
const STATIC_ART := "res://FD_Testing/GameSystems/Death/DEATH_UI.png"
const CHECK_ART := "res://FD_Testing/GameSystems/Death/CheckMark.png"
const DIGITS_DIR := "res://FD_Testing/GameSystems/Death/Digits"
const BLUR_SHADER := "res://FD_Testing/GameSystems/LogBook/blur_background.gdshader"

const ART_SIZE := Vector2(640, 360)

@export_group("Timing")
## Seconds the player's death animation gets before the board comes up.
@export var default_anim_seconds: float = 1.1
@export var slide_seconds: float = 0.5
## The board animation as a SpriteFrames — edit frames, order and timing
## in Godot's SpriteFrames panel. Animation name: "death".
@export var board_frames: SpriteFrames
@export var board_anim_name: String = "death"
## Multiplies the SpriteFrames speed (2.0 = twice as fast).
@export var anim_speed_scale: float = 1.0
## Pause after the animation before the writing appears.
@export var write_delay: float = 0.25

@export_group("Placement (measured from the board art)")
## Where the clock is written, just after the printed "TIME:".
@export var time_value_pos := Vector2(0.505, 0.390)
## The FIRST printed checkbox, and the gap down to the next one.
@export var check_first_pos := Vector2(0.374, 0.550)
@export var check_row_spacing: float = 0.0645
## Optional: where a written cause name would go (only if you use one).
@export var cause_value_pos := Vector2(0.395, 0.545)
## Hitboxes over the printed RETRY / QUIT boxes.
@export var retry_rect := Rect2(0.4328, 0.8056, 0.1172, 0.0694)
@export var quit_rect := Rect2(0.4560, 0.8800, 0.0700, 0.0500)

@export_group("Extra text (the board art already draws its own)")
## These are EMPTY on purpose — the clipboard art has the words printed.
## Fill one only if your art stops drawing it.
@export var header_text: String = ""
@export var header_pos := Vector2(0.360, 0.150)
@export var time_label_text: String = ""
@export var time_label_pos := Vector2(0.378, 0.400)
@export var cause_label_text: String = ""
@export var cause_label_pos := Vector2(0.411, 0.508)
@export var retry_text: String = ""
@export var quit_text: String = ""
@export var ink_color := Color(0.16, 0.09, 0.06)
@export var use_24_hour: bool = true

@export_group("Clock (drawn with the number images)")
## Draw the time using Digits/digit_0..9.png instead of a font.
@export var use_digit_images: bool = true
## Gap between digits, in art pixels.
@export var digit_spacing: float = 3.0
## Extra gap where the ":" goes.
@export var colon_width: float = 7.0
## Scales the digit art (1.0 = its drawn size).
@export var digit_scale: float = 1.0

@export_group("Flow")
## Scene loaded by QUIT.
@export_file("*.tscn") var main_menu_scene: String = ""

signal player_died(cause_id: String)

var is_dead: bool = false
var causes: Array[DeathCause] = []
var last_cause_id: String = ""

var _layer: CanvasLayer
var _blur: ColorRect
var _root: Control
var _frame: TextureRect
var _check: TextureRect
var _header: Label
var _time_label: Label
var _time_value: Label
var _cause_label: Label
var _cause_value: Label
var _retry: Button
var _quit: Button
var _still: Texture2D
var _digits: Array[Texture2D] = []
var _digit_nodes: Array[TextureRect] = []
var _clock_root: Control
var _writing: Array[CanvasItem] = []
var _check_row: int = 0
var _fallback_respawn := Vector2.ZERO
var _has_fallback := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_causes()
	_load_digits()
	_load_frames()
	_build_ui()
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func _load_causes() -> void:
	causes.clear()
	var dir := DirAccess.open(CAUSES_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if file.get_extension() == "tres" or file.get_extension() == "res":
			var r := load(CAUSES_DIR + "/" + file)
			if r is DeathCause:
				causes.append(r)


## True when the clock is drawn from the number images.
func using_digits() -> bool:
	return use_digit_images and _digits.size() == 10


func _load_digits() -> void:
	_digits.clear()
	for i in 10:
		var path := "%s/digit_%d.png" % [DIGITS_DIR, i]
		if ResourceLoader.exists(path):
			_digits.append(load(path))
	if _digits.size() < 10:
		_digits.clear()          # incomplete set: fall back to the font


func _load_frames() -> void:
	if board_frames == null and ResourceLoader.exists(FRAMES_RES):
		board_frames = load(FRAMES_RES)
	if board_frames == null and ResourceLoader.exists(STATIC_ART):
		_still = load(STATIC_ART)            # no SpriteFrames? use the still board


func get_cause(id: String) -> DeathCause:
	for c in causes:
		if c.id == id:
			return c
	return null


## Optional: a spot to respawn at when there's no checkpoint yet.
func set_respawn(world_pos: Vector2) -> void:
	_fallback_respawn = world_pos
	_has_fallback = true


# ==========================================================================
# dying
# ==========================================================================

func kill(cause_id: String = "", anim_seconds: float = -1.0) -> void:
	if is_dead:
		return
	is_dead = true
	last_cause_id = cause_id
	if cause_id != "":
		Flags.set_flag("died_of:" + cause_id)      # remember every cause seen
	Flags.add_flag("death_count")
	player_died.emit(cause_id)

	var player := get_tree().get_first_node_in_group("Player")
	if player:
		if "input_enabled" in player:
			player.input_enabled = false
		if player.has_method("end_grab"):
			player.end_grab()
		var sm = player.get("state_machine")
		var death_node = sm.get_node_or_null("Death") if sm else null
		if death_node and sm.has_method("ChangeState"):
			sm.ChangeState(death_node)
		else:
			_play_death_anim(player)

	var wait: float = anim_seconds if anim_seconds >= 0.0 else default_anim_seconds
	await get_tree().create_timer(wait, true, false, false).timeout
	await show_screen()


func _play_death_anim(player: Node) -> void:
	if not ("anim" in player) or player.anim.sprite_frames == null:
		return
	var frames = player.anim.sprite_frames
	var names := ["Death_down", "Death"]
	if player.has_method("AnimDirection"):
		names.push_front("Death_" + player.AnimDirection())
	for n in names:
		if frames.has_animation(n):
			player.anim.play(n)
			return


## The board sequence: slide up -> animate -> write -> buttons.
func show_screen() -> void:
	_prepare_texts()
	_layout()
	for w in _writing:
		w.visible = false                    # nothing written yet
	_retry.disabled = true
	_quit.disabled = true
	_frame.texture = _first_frame()
	_layer.visible = true
	get_tree().paused = true

	# 2. slide up
	var h := get_viewport().get_visible_rect().size.y
	_root.position.y = h
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_root, "position:y", 0.0, slide_seconds)
	await tw.finished

	# 3. the board animation (frames + timing come from the SpriteFrames)
	if board_frames and board_frames.has_animation(board_anim_name):
		var fps: float = maxf(0.1, board_frames.get_animation_speed(board_anim_name) * anim_speed_scale)
		for i in board_frames.get_frame_count(board_anim_name):
			_frame.texture = board_frames.get_frame_texture(board_anim_name, i)
			var d: float = board_frames.get_frame_duration(board_anim_name, i) / fps
			await get_tree().create_timer(d, true, false, true).timeout

	# 4. the writing + check mark
	await get_tree().create_timer(write_delay, true, false, true).timeout
	for w in _writing:
		if w == _time_value and using_digits():
			continue                       # the images draw the clock instead
		if w is Label and (w as Label).text == "":
			continue                       # nothing to write there
		w.visible = true
	# 5. now they can choose
	_retry.disabled = false
	_quit.disabled = false


func _first_frame() -> Texture2D:
	if board_frames and board_frames.has_animation(board_anim_name) \
			and board_frames.get_frame_count(board_anim_name) > 0:
		return board_frames.get_frame_texture(board_anim_name, 0)
	return _still


func _prepare_texts() -> void:
	var c := get_cause(last_cause_id)
	_header.text = header_text
	_time_label.text = time_label_text
	_cause_label.text = cause_label_text
	# with digit IMAGES the font label must stay EMPTY, or it prints the
	# time a second time behind the drawn digits
	_time_value.text = "" if using_digits() else _clock_text()
	_cause_value.text = c.label if c else ""
	_retry.text = retry_text
	_quit.text = quit_text
	# anything with no text stays out of the way entirely
	for l in [_header, _time_label, _cause_label, _cause_value]:
		l.visible = l.text != ""
	# the check mark goes on the row this cause belongs to
	_check_row = c.row if c else 0


func _clock_text() -> String:
	var t := Time.get_time_dict_from_system()
	if use_24_hour:
		return "%02d:%02d" % [t.hour, t.minute]
	var h: int = t.hour % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, t.minute, "AM" if t.hour < 12 else "PM"]


# ==========================================================================
# retry / quit
# ==========================================================================

func _on_retry() -> void:
	_layer.visible = false
	get_tree().paused = false
	is_dead = false
	var n: int = int(Flags.get_flag("prescription_current", -1))
	if n >= 0 and Prescription.get_checkpoint(n) != null:
		Prescription.apply(n)                     # back to the last checkpoint
	else:
		# awaited so the fallback below runs against the reloaded scene, not the
		# old one that is still alive behind the transition
		await SceneManager.reload_current_scene()
		if _has_fallback:
			await get_tree().process_frame
			var p := get_tree().get_first_node_in_group("Player")
			if p:
				p.global_position = _fallback_respawn
	var p2 := get_tree().get_first_node_in_group("Player")
	if p2 and "input_enabled" in p2:
		p2.input_enabled = true


func _on_quit() -> void:
	_layer.visible = false
	get_tree().paused = false
	is_dead = false
	if main_menu_scene != "":
		SceneManager.load_new_scene(main_menu_scene)
	else:
		push_warning("Deaths: main_menu_scene is empty — set it on the autoload.")


# ==========================================================================
# UI
# ==========================================================================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
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
		_blur.color = Color(0.03, 0.02, 0.02, 0.9)
	_layer.add_child(_blur)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_frame = TextureRect.new()
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_frame)

	_header = _make_label(26)
	_time_label = _make_label(18)
	_time_value = _make_label(18)
	_cause_label = _make_label(16)
	_cause_value = _make_label(16)

	_clock_root = Control.new()
	_clock_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_clock_root)

	_check = TextureRect.new()
	if ResourceLoader.exists(CHECK_ART):
		_check.texture = load(CHECK_ART)
	_check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_check.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_check)

	# The board art already draws the RETRY / QUIT boxes, so these are
	# invisible hitboxes sitting exactly on top of them.
	_retry = _make_hitbox()
	_retry.pressed.connect(_on_retry)
	_quit = _make_hitbox()
	_quit.pressed.connect(_on_quit)

	# everything that "gets written" after the animation
	# what "gets written" once the board animation finishes
	_writing = [_header, _time_label, _time_value, _cause_label, _cause_value,
			_check, _clock_root]
	_layer.visible = false


## A clickable area with no visuals of its own (the art is the button).
func _make_hitbox() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", ink_color)
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_root.add_child(b)
	return b


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ink_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var s: float = minf(screen.y * 0.94 / ART_SIZE.y, screen.x * 0.94 / ART_SIZE.x)
	var fsize := ART_SIZE * s
	var fpos := (screen - fsize) * 0.5
	_frame.position = fpos
	_frame.size = fsize

	_place(_header, fpos, fsize, header_pos)
	_place(_time_label, fpos, fsize, time_label_pos)
	_place(_time_value, fpos, fsize, time_value_pos)
	_place(_clock_root, fpos, fsize, time_value_pos)
	_layout_clock(s)
	_place(_cause_label, fpos, fsize, cause_label_pos)
	_place(_cause_value, fpos, fsize, cause_value_pos)
	var row_frac := Vector2(check_first_pos.x, check_first_pos.y + check_row_spacing * _check_row)
	_place(_check, fpos, fsize, row_frac)
	if _check.texture:
		_check.size = Vector2(_check.texture.get_width(), _check.texture.get_height()) * s

	_retry.position = fpos + Vector2(retry_rect.position.x * fsize.x, retry_rect.position.y * fsize.y)
	_retry.size = Vector2(retry_rect.size.x * fsize.x, retry_rect.size.y * fsize.y)
	_quit.position = fpos + Vector2(quit_rect.position.x * fsize.x, quit_rect.position.y * fsize.y)
	_quit.size = Vector2(quit_rect.size.x * fsize.x, quit_rect.size.y * fsize.y)

	_header.add_theme_font_size_override("font_size", maxi(14, int(26 * s)))
	for l in [_time_label, _time_value]:
		l.add_theme_font_size_override("font_size", maxi(10, int(18 * s)))
	for l in [_cause_label, _cause_value]:
		l.add_theme_font_size_override("font_size", maxi(9, int(16 * s)))
	_retry.add_theme_font_size_override("font_size", maxi(12, int(20 * s)))
	_quit.add_theme_font_size_override("font_size", maxi(10, int(16 * s)))


## Draws the time with the hand-drawn number images.
func _layout_clock(s: float) -> void:
	var use_images: bool = using_digits()
	_time_value.visible = not use_images and _time_value.text != ""
	for n in _digit_nodes:
		n.queue_free()
	_digit_nodes.clear()
	if not use_images:
		return
	var text := _clock_text()
	var x: float = 0.0
	var scale_f: float = s * digit_scale
	# tallest digit sets the baseline so they sit level
	var tallest: float = 0.0
	for t in _digits:
		tallest = maxf(tallest, float(t.get_height()))
	for ch in text:
		if ch == ":":
			x += colon_width * scale_f
			continue
		if ch < "0" or ch > "9":
			x += digit_spacing * scale_f
			continue
		var tex: Texture2D = _digits[int(ch)]
		var r := TextureRect.new()
		r.texture = tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(tex.get_width(), tex.get_height()) * scale_f
		# sit them on a common baseline (they have different heights)
		r.position = Vector2(x, (tallest - tex.get_height()) * scale_f)
		_clock_root.add_child(r)
		_digit_nodes.append(r)
		x += r.size.x + digit_spacing * scale_f


func _place(c: Control, fpos: Vector2, fsize: Vector2, frac: Vector2) -> void:
	c.position = fpos + Vector2(frac.x * fsize.x, frac.y * fsize.y)


func _on_dialog_action(action_name: String, args: Array) -> void:
	if action_name != "kill":
		return
	var id: String = str(args[0]) if args.size() > 0 else ""
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
	kill(id)
