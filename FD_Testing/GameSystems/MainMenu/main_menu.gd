class_name MainMenu extends CanvasLayer
## The main menu room: the door starts a new game, the wheelchair leaves, the
## dominoes open settings, the radio plays. The first launch plays the intro,
## then walks through the settings, then shows the room.

signal hovered(action: String)
signal pressed(action: String)
signal new_game
signal quitting
signal settings_opened
signal settings_closed
signal first_run_finished
signal intro_finished

const CANVAS := Vector2(640, 360)
const FRAME := Vector2(640, 360)

@export_group("Art")
## The room loop: a grid of 640x360 frames, left to right, top to bottom.
@export_file("*.png") var sheet_english: String = "res://FD_Testing/GameSystems/MainMenu/Art/menu_english.png"
@export_file("*.png") var sheet_arabic: String = "res://FD_Testing/GameSystems/MainMenu/Art/menu_arabic.png"
## Shown instead once the player has finished the game.
@export_file("*.png") var sheet_finished_english: String = "res://FD_Testing/GameSystems/MainMenu/Art/menu_finished_english.png"
@export_file("*.png") var sheet_finished_arabic: String = "res://FD_Testing/GameSystems/MainMenu/Art/menu_finished_arabic.png"
## Frames per second of the room loop.
@export var fps: float = 12.0
## How many frames to play. 0 = every cell in the sheet.
@export var frame_count: int = 0

@export_group("Radio art")
## The radio while a station plays. One frame, or a sheet of frames that animates.
@export var radio_playing_art: Texture2D
## The radio on a locked station (static).
@export var radio_static_art: Texture2D
## Size of one frame of that art. 640x360 = full-canvas layers.
@export var radio_art_frame: Vector2 = Vector2(640, 360)
## Where the art's top-left corner sits on the 640x360 canvas.
@export var radio_art_position: Vector2 = Vector2.ZERO
## Frames per second when the art is a sheet.
@export var radio_art_fps: float = 12.0
## Where the stand-in glow sits when a state has no art yet.
@export var radio_dial_rect: Rect2 = Rect2(84, 249, 104, 31)
@export var radio_glow_color: Color = Color(1.0, 0.72, 0.38, 0.28)

@export_group("Intro")
## The intro film, played before the first-launch setup. Theora .ogv; Godot can't play .mp4.
@export var intro_video: VideoStream
## Play it on every launch, not only the first.
@export var intro_every_launch: bool = false
## A key, click or button skips it.
@export var intro_skippable: bool = true
## Which volume slider owns its sound.
@export_enum("Master", "Music", "Ambience", "SFX", "UI", "Dialog") var intro_category: String = "Music"
## Seconds it takes to fade out at the end.
@export var intro_fade_seconds: float = 0.6

@export_group("New game")
## The first scene of a new game.
@export_file("*.tscn") var new_game_scene: String = ""
## The lit doorway on the art. The push ends centred on it.
@export var door_opening: Rect2 = Rect2(290, 106, 66, 186)
## How far the view pushes in.
@export var door_zoom: float = 4.0
@export var door_seconds: float = 1.6
## The light the screen turns into. It is full a quarter of the way before the push ends.
@export var door_light: Color = Color(1.0, 0.87, 0.62)
## Seconds the full light holds before the first scene loads.
@export var door_hold_seconds: float = 0.35
## Seconds that light takes to clear once the first scene is up.
@export var arrive_seconds: float = 0.8

@export_group("Leaving")
## The chair's word after the first press.
@export var quit_confirm_label: String = "Leave? Press again"
## Seconds the chair waits for the second press.
@export var quit_confirm_seconds: float = 3.0

@export_group("Sounds")
## Room tone looped under the menu.
@export var ambience_sound_id: String = ""
## How far the room tone drops while the radio plays, in dB.
@export var radio_duck_db: float = -12.0
## Played on the frames where the door light cuts out.
@export var buzz_sound_id: String = ""
## The frames the light cuts out on.
@export var buzz_frames: PackedInt32Array = [0, 2, 16]

@export_group("Look")
@export var label_size: int = 8
@export var label_color: Color = Color(0.96, 0.9, 0.76)
## Empty = the default font, kept sharp when scaled up.
@export var font: Font
## Seconds the room takes to come up out of black.
@export var fade_in_seconds: float = 1.0
## How dark the room goes behind the settings panel.
@export_range(0.0, 1.0) var settings_dim: float = 0.65

@export_group("Behaviour")
## Walk new players through language, volume and display before the room.
@export var first_run: bool = true

var busy := false

var _hover: MenuHotspot = null
var _frames := 1
var _cols := 1
var _frame := -1
var _time := 0.0
var _sheet_path := ""
var _atlas := AtlasTexture.new()
var _quit_armed := false
var _quit_token := 0
var _ambience: AudioStreamPlayer
var _ambience_db := 0.0
var _duck_tween: Tween
var _font: Font
var _radio_atlas := AtlasTexture.new()
var _radio_frames := 1
var _radio_cols := 1
var _radio_time := 0.0
var _intro_playing := false
var _intro_moved := 0
var _intro_last_pos := 0.0
var _pushing := false
var _intro_started := 0

static var _sharp_font: Font = null

@onready var _root: Control = %Root
@onready var _stage: Control = %Stage
@onready var _background: TextureRect = %Background
@onready var _radio_art: TextureRect = %RadioArt
@onready var _radio_glow: ColorRect = %RadioGlow
@onready var _hotspots: Node2D = %Hotspots
@onready var _label: Label = %HoverLabel
@onready var _dim: ColorRect = %Dim
@onready var _settings: MenuSettings = %Settings
@onready var _fade: ColorRect = %Fade
@onready var _radio: MenuRadio = %Radio
@onready var _intro: Control = %Intro
@onready var _video: VideoStreamPlayer = %IntroVideo


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("main_menu")
	_font = font if font else _sharp(_root.get_theme_default_font())
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", label_size)
	_label.add_theme_color_override("font_color", label_color)
	_label.visible = false
	if _settings.font == null:
		_settings.font = _font
	_background.texture = _atlas
	_radio_art.texture = _radio_atlas
	_radio_art.visible = false
	_radio_glow.position = radio_dial_rect.position
	_radio_glow.size = radio_dial_rect.size
	_radio_glow.color = radio_glow_color
	_radio_glow.visible = false

	_settings.closed.connect(_on_settings_closed)
	_settings.first_run_done.connect(_on_first_run_done)
	_radio.turned_on.connect(_on_radio.bind(true))
	_radio.turned_off.connect(_on_radio.bind(false))
	_radio.tuned.connect(_on_tuned)
	var loc := get_node_or_null("/root/Loc")
	if loc:
		loc.language_changed.connect(_on_language_changed)
	var prof := get_node_or_null("/root/Profile")
	if prof:
		prof.finished.connect(_apply_sheet)

	_apply_sheet()
	_layout()
	get_viewport().size_changed.connect(_layout)

	var setup: bool = first_run and prof != null and prof.needs_first_run()
	_dim.color.a = 1.0 if setup else 0.0
	# Fade sits above the intro, so it only goes black once the film is done
	_fade.color = Color(0, 0, 0, 0)
	if intro_video and (intro_every_launch or (prof != null and prof.needs_first_run())):
		busy = true
		await _play_intro()
		busy = false
	_start_ambience()
	if setup:
		_settings.start_first_run()
	else:
		_fade.color = Color(0, 0, 0, 1)
		create_tween().tween_property(_fade, "color:a", 0.0, fade_in_seconds)


func _process(delta: float) -> void:
	_time += delta * fps
	var f := int(_time) % _frames
	if f != _frame:
		_frame = f
		_atlas.region = Rect2(Vector2(f % _cols, floori(float(f) / _cols)) * FRAME, FRAME)
		if buzz_frames.has(f):
			_sfx(buzz_sound_id)
	if _radio_glow.visible:
		_radio_glow.color.a = radio_glow_color.a * (0.85 + 0.15 * sin(_time * 1.7))
	if _radio_art.visible and _radio_frames > 1:
		_radio_time += delta * radio_art_fps
		var rf := int(_radio_time) % _radio_frames
		_radio_atlas.region = Rect2(Vector2(rf % _radio_cols,
				floori(float(rf) / _radio_cols)) * radio_art_frame, radio_art_frame)
	if _intro_playing:
		_layout_intro()
		_watch_intro()


# --- the art --------------------------------------------------------------------

## Loads only the sheet for the current language and ending, and drops the old one.
func _apply_sheet() -> void:
	var loc := get_node_or_null("/root/Loc")
	var prof := get_node_or_null("/root/Profile")
	var arabic: bool = loc != null and loc.current() == "ar"
	var done: bool = prof != null and prof.is_finished()
	var path := sheet_english
	if done:
		path = sheet_finished_arabic if arabic else sheet_finished_english
	elif arabic:
		path = sheet_arabic
	if path == _sheet_path:
		return
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		push_warning("MainMenu: can't load the room sheet '%s'." % path)
		return
	_sheet_path = path
	_atlas.atlas = tex
	_cols = maxi(1, int(tex.get_width() / FRAME.x))
	var rows := maxi(1, int(tex.get_height() / FRAME.y))
	_frames = frame_count if frame_count > 0 else _cols * rows
	_frame = -1


## Fits the 640x360 art to the screen, centred.
func _layout() -> void:
	if _pushing:
		return
	var screen := get_viewport().get_visible_rect().size
	var s := minf(screen.x / CANVAS.x, screen.y / CANVAS.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((screen - CANVAS * s) * 0.5).floor()


func _to_canvas(screen_pos: Vector2) -> Vector2:
	return _stage.get_global_transform_with_canvas().affine_inverse() * screen_pos


# --- input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# TAB would open the Board over the menu
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		return
	if _intro_playing:
		var skip := event.is_pressed() and not event.is_echo() and (event is InputEventKey
				or event is InputEventMouseButton or event is InputEventJoypadButton)
		# a short grace so the click that launched the game doesn't skip it
		if skip and intro_skippable and Time.get_ticks_msec() - _intro_started > 400:
			_end_intro()
		get_viewport().set_input_as_handled()
		return
	if busy or _settings.visible:
		return
	if event is InputEventMouseMotion:
		_set_hover(_hotspot_at(_to_canvas(event.position)))
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _hotspot_at(_to_canvas(event.position))
		if h:
			_set_hover(h)
			_press(h)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not busy and not _settings.visible:
		if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
			_step_hover(1)
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
			_step_hover(-1)
		elif event.is_action_pressed("ui_accept") and _hover:
			_press(_hover)
	# nothing reaches the in-game shortcuts (Board letters, LogBook) from here
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


func _hotspot_at(canvas_point: Vector2) -> MenuHotspot:
	var list := _live_hotspots()
	list.reverse()  # the last one in the scene sits on top (knobs over the radio)
	for h in list:
		if h.contains(canvas_point):
			return h
	return null


func _live_hotspots() -> Array[MenuHotspot]:
	var out: Array[MenuHotspot] = []
	for c in _hotspots.get_children():
		if c is MenuHotspot and c.enabled:
			out.append(c)
	return out


## Arrow keys and the d-pad walk the objects in scene order.
func _step_hover(dir: int) -> void:
	var list := _live_hotspots()
	if list.is_empty():
		return
	var i := list.find(_hover)
	if i == -1:
		i = 0 if dir > 0 else list.size() - 1
	else:
		i = posmod(i + dir, list.size())
	_set_hover(list[i])


func _set_hover(h: MenuHotspot) -> void:
	if h == _hover:
		return
	if _hover:
		_hover.set_lit(false)
	_hover = h
	_disarm_quit()
	if h == null:
		_label.visible = false
		return
	h.set_lit(true)
	_show_label(h.label)
	_sfx(h.hover_sound_id)
	hovered.emit(h.action)


func _show_label(text: String) -> void:
	if _hover == null or text == "":
		_label.visible = false
		return
	_label.text = tr(text)
	_label.reset_size()
	_label.position = (_hover.label_position() - _label.size * 0.5).round()
	_label.visible = true


func _hotspot(action: String) -> MenuHotspot:
	for c in _hotspots.get_children():
		if c is MenuHotspot and c.action == action:
			return c
	return null


# --- what each thing does -----------------------------------------------------------

func _press(h: MenuHotspot) -> void:
	if not h.enabled:
		return
	_sfx(h.press_sound_id)
	pressed.emit(h.action)
	match h.action:
		"door":
			start_new_game()
		"counter":
			_load_save()
		"radio":
			_radio.toggle()
		"knob_back":
			_radio.step(-1)
		"knob_next":
			_radio.step(1)
		"dominoes":
			open_settings()
		"chair":
			_press_chair()


func start_new_game() -> void:
	if busy:
		return
	busy = true
	_pushing = true
	_set_hover(null)
	_radio.turn_off(true)
	new_game.emit()
	var centre := door_opening.get_center()
	var screen := get_viewport().get_visible_rect().size
	var s := _stage.scale.x * door_zoom
	_fade.color = Color(door_light, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_stage, "scale", Vector2(s, s), door_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(_stage, "position", screen * 0.5 - centre * s, door_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# the light covers everything before the push ends, so no room shows at the edges
	tw.tween_property(_fade, "color:a", 1.0, door_seconds * 0.75) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _ambience:
		tw.tween_property(_ambience, "volume_db", -60.0, door_seconds)
	await tw.finished
	await get_tree().create_timer(door_hold_seconds).timeout

	var flags := get_node_or_null("/root/Flags")
	if flags:
		flags.clear_all()
	if new_game_scene == "":
		push_warning("MainMenu: no new_game_scene set - staying on the menu.")
		return
	_arrive_fade()
	get_tree().change_scene_to_file(new_game_scene)


## The door light stays over the first scene for a moment and clears.
func _arrive_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	var rect := ColorRect.new()
	rect.color = door_light
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_interval(0.1)
	tw.tween_property(rect, "color:a", 0.0, arrive_seconds)
	tw.tween_callback(layer.queue_free)


func _load_save() -> void:
	# Load save isn't designed yet; the Counter hotspot is switched off in the
	# scene until it is. One idea: hand the prescription over the counter.
	pass


func open_settings() -> void:
	_set_hover(null)
	_settings.open_settings()
	create_tween().tween_property(_dim, "color:a", settings_dim, 0.2)
	settings_opened.emit()


func _on_settings_closed() -> void:
	create_tween().tween_property(_dim, "color:a", 0.0, 0.2)
	settings_closed.emit()


func _on_first_run_done() -> void:
	var prof := get_node_or_null("/root/Profile")
	if prof:
		prof.mark_first_run_done()
	create_tween().tween_property(_dim, "color:a", 0.0, fade_in_seconds)
	first_run_finished.emit()


## First press asks, second press within a few seconds leaves.
func _press_chair() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_token += 1
		_show_label(quit_confirm_label)
		var token := _quit_token
		await get_tree().create_timer(quit_confirm_seconds).timeout
		if token == _quit_token:
			_disarm_quit()
		return
	busy = true
	_set_hover(null)
	quitting.emit()
	_fade.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	await tw.finished
	get_tree().quit()


func _disarm_quit() -> void:
	if not _quit_armed:
		return
	_quit_armed = false
	_quit_token += 1
	if _hover:
		_show_label(_hover.label)


# --- radio and room tone ----------------------------------------------------------

func _on_radio(on: bool) -> void:
	if not on:
		_radio_art.visible = false
		_radio_glow.visible = false
	if _ambience == null:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(_ambience, "volume_db",
			_ambience_db + (radio_duck_db if on else 0.0), 0.6)


## Static art on a locked station, the playing art on a real one; the glow stands in for a missing one.
func _on_tuned(_index: int, locked: bool) -> void:
	var tex: Texture2D = radio_static_art if locked else radio_playing_art
	_radio_glow.visible = tex == null
	_radio_art.visible = tex != null
	if tex == null:
		return
	_radio_atlas.atlas = tex
	_radio_cols = maxi(1, int(tex.get_width() / radio_art_frame.x))
	_radio_frames = _radio_cols * maxi(1, int(tex.get_height() / radio_art_frame.y))
	_radio_atlas.region = Rect2(Vector2.ZERO, radio_art_frame)
	_radio_art.position = radio_art_position
	_radio_art.size = radio_art_frame
	_radio_time = 0.0


# --- intro -----------------------------------------------------------------------------

func _play_intro() -> void:
	var problem := _intro_file_problem()
	if problem != "":
		push_error("MainMenu: the intro can't play, skipping it. " + problem)
		return
	_intro.visible = true
	_video.modulate.a = 1.0
	_video.stream = intro_video
	BusRoute.use(_video, intro_category)
	_video.finished.connect(_end_intro, CONNECT_ONE_SHOT)
	_intro_started = Time.get_ticks_msec()
	_intro_moved = _intro_started
	_intro_last_pos = 0.0
	_intro_playing = true
	_video.play()
	_layout_intro()
	await intro_finished
	# the film fades to the black behind it, then the room or the setup takes over
	var tw := create_tween()
	tw.tween_property(_video, "modulate:a", 0.0, intro_fade_seconds)
	await tw.finished
	_video.stop()
	_video.stream = null
	_intro.visible = false


## Why the file can't be the intro, or "" if it looks like Theora video.
## Godot plays nothing and never finishes on a wrong file, so it's checked first.
func _intro_file_problem() -> String:
	var path := intro_video.file if intro_video.file != "" else intro_video.resource_path
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "Can't open '%s'." % path
	var head := f.get_buffer(256)
	if head.slice(0, 4).get_string_from_ascii() != "OggS":
		if head.slice(4, 8).get_string_from_ascii() == "ftyp":
			return "'%s' is really an MP4 with its name changed. Renaming doesn't convert it; convert it to Theora (README, section 24)." % path.get_file()
		return "'%s' isn't an Ogg Theora video. Convert it to Theora (README, section 24)." % path.get_file()
	if head.hex_encode().find("theora".to_ascii_buffer().hex_encode()) == -1:
		return "'%s' is an Ogg file but its video isn't Theora. Convert it to Theora (README, section 24)." % path.get_file()
	return ""


## A film that stops moving mid-way (a broken file) ends the intro instead of holding a black screen.
func _watch_intro() -> void:
	var now := Time.get_ticks_msec()
	if _video.stream_position != _intro_last_pos:
		_intro_last_pos = _video.stream_position
		_intro_moved = now
	elif now - _intro_moved > 1500:
		push_error("MainMenu: the intro stopped playing at %.1fs, skipping it." % _intro_last_pos)
		_end_intro()


func _end_intro() -> void:
	if not _intro_playing:
		return
	_intro_playing = false
	if _video.finished.is_connected(_end_intro):
		_video.finished.disconnect(_end_intro)
	intro_finished.emit()


## The film keeps its own shape, as big as fits, with black round it.
func _layout_intro() -> void:
	var screen := get_viewport().get_visible_rect().size
	var tex := _video.get_video_texture()
	var film := Vector2(tex.get_size()) if tex and tex.get_width() > 0 else screen
	var k := minf(screen.x / film.x, screen.y / film.y)
	_video.size = (film * k).floor()
	_video.position = ((screen - _video.size) * 0.5).floor()


func _start_ambience() -> void:
	var snd := get_node_or_null("/root/Sound")
	if ambience_sound_id == "" or snd == null:
		return
	var d = snd.get_def(ambience_sound_id)
	if d == null or d.stream == null:
		push_warning("MainMenu: no playable sound '%s' for the room tone." % ambience_sound_id)
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = d.stream
	_ambience_db = d.volume_db
	_ambience.volume_db = -60.0
	add_child(_ambience)
	BusRoute.use(_ambience, "Ambience")
	_ambience.finished.connect(_ambience.play)
	_ambience.play()
	create_tween().tween_property(_ambience, "volume_db", _ambience_db, fade_in_seconds)


func _sfx(id: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if id != "" and snd:
		snd.play(id)


# --- language and font -----------------------------------------------------------------

func _on_language_changed(_code: String) -> void:
	_apply_sheet()
	if _hover:
		_show_label(quit_confirm_label if _quit_armed else _hover.label)


## Text is drawn at art size and scaled up with the stage; a signed-distance
## copy of the font stays sharp at any scale.
static func _sharp(base: Font) -> Font:
	if _sharp_font == null:
		_sharp_font = base
		if base is FontFile:
			var copy := (base as FontFile).duplicate() as FontFile
			copy.multichannel_signed_distance_field = true
			_sharp_font = copy
	return _sharp_font
