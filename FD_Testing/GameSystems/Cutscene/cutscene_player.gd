extends Node
## Cutscene — add as an Autoload named "Cutscene".
## Two modes:
##
## 1) SINGLE VIDEO (.ogv):
##      await Cutscene.play("res://.../video.ogv")
##    Skippable with "interact" (see `skippable`).
##
## 2) COMIC — a sequence of panels (video or image), the player presses
##    "interact" to go to the next panel; each panel can play a sound and
##    set flags the moment it appears:
##      await Cutscene.play_comic(preload("res://.../my_comic.tres"))
##
## From DIALOG lines:
##    action_name "cutscene", args ["res://...ogv"]        -> single video
##    action_name "comic",    args ["res://...tres"]       -> comic
##    (tick wait_for_action to hold the conversation until it ends)
##
## Godot can NOT play .gif or .mp4 — convert to .ogv:
##    ffmpeg -i input.gif -c:v libtheora -q:v 8 output.ogv

signal started
signal finished

## Single-video mode: let the player skip the whole video with "interact".
@export var skippable: bool = true

## Comic mode: the corner prompt shown when a panel has finished.
## Arabic works fine here (e.g. "...التالي").
@export var next_text: String = "Next..."

## Comic mode: if ON, the player can only advance AFTER the panel finished
## (video ended / image delay passed). If OFF, they can advance any time.
@export var advance_only_after_end: bool = false

var is_playing: bool = false

var _layer: CanvasLayer
var _ratio_box: AspectRatioContainer
var _video: VideoStreamPlayer
var _image: TextureRect
var _sfx: AudioStreamPlayer
var _next_label: Label
var _was_paused: bool = false

# comic state
var _comic: Comic = null
var _panel_index: int = -1
var _panel_timer: float = 0.0
var _advance_lock: float = 0.0
var _panel_ended: bool = false
var _image_end_delay: float = 0.0
const IMAGE_PANEL_END_DELAY := 0.8   # image panels count as "ended" after this


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(black)

	_ratio_box = AspectRatioContainer.new()
	_ratio_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ratio_box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_layer.add_child(_ratio_box)

	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.finished.connect(_on_video_finished)
	_ratio_box.add_child(_video)

	_image = TextureRect.new()
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_image)

	_sfx = AudioStreamPlayer.new()
	_layer.add_child(_sfx)

	_next_label = Label.new()
	_next_label.add_theme_font_size_override("font_size", 22)
	_next_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_label.position = Vector2(-160, -46)
	_next_label.modulate = Color(1, 1, 1, 0.85)
	_next_label.visible = false
	_layer.add_child(_next_label)

	_layer.visible = false
	_video.visible = false
	_image.visible = false


# ==========================================================================
# MODE 1 — single video
# ==========================================================================

func play(video_path: String) -> void:
	if is_playing:
		push_warning("Cutscene already playing; ignoring play('%s')." % video_path)
		return
	if video_path.get_extension().to_lower() in ["mp4", "gif"]:
		push_error("Cutscene: Godot cannot play .%s — convert to .ogv." % video_path.get_extension())
		return
	var stream: VideoStream = load(video_path)
	if stream == null:
		push_error("Cutscene: could not load '%s'." % video_path)
		return
	await play_stream(stream)


## Play a VideoStream you already have (e.g. dragged into an inspector slot).
func play_stream(stream: VideoStream) -> void:
	if is_playing:
		push_warning("Cutscene already playing; ignoring play_stream.")
		return
	if stream == null:
		push_error("Cutscene: no video assigned.")
		return
	_begin()
	_video.visible = true
	_video.stream = stream
	_video.play()
	await get_tree().process_frame
	_fit_ratio_to_video()
	await finished


func _fit_ratio_to_video() -> void:
	var tex := _video.get_video_texture()
	if tex and tex.get_size().y > 0:
		_ratio_box.ratio = tex.get_size().x / tex.get_size().y


func _on_video_finished() -> void:
	if not is_playing:
		return
	if _comic != null:
		_panel_ended = true          # panel plays ONCE, holds on its last frame
		_show_next_prompt()
		return
	_end()


# ==========================================================================
# MODE 2 — comic
# ==========================================================================

func play_comic(comic: Comic) -> void:
	if is_playing:
		push_warning("Cutscene already playing; ignoring play_comic.")
		return
	if comic == null or comic.panels.is_empty():
		push_error("Cutscene: comic is empty.")
		return
	_begin()
	_comic = comic
	_panel_index = -1
	_next_panel()
	await finished


func _next_panel() -> void:
	_panel_index += 1
	if _panel_index >= _comic.panels.size():
		_end()
		return
	var p: ComicPanel = _comic.panels[_panel_index]
	_advance_lock = 0.15
	_panel_timer = p.auto_advance_sec
	_panel_ended = false
	_image_end_delay = 0.0
	_next_label.visible = false

	for f in p.set_flags:
		Flags.set_flag(f)
	if p.sound:
		_sfx.stream = p.sound
		_sfx.play()

	_video.stop()
	_video.visible = false
	_image.visible = false
	var stream := p.get_stream()
	if stream:
		_video.visible = true
		_video.stream = stream
		_video.play()
		_fit_ratio_to_video.call_deferred()
	elif p.image:
		_image.visible = true
		_image.texture = p.image
		_image_end_delay = IMAGE_PANEL_END_DELAY


func _process(delta: float) -> void:
	if not is_playing:
		return
	if _advance_lock > 0.0:
		_advance_lock -= delta
		return
	if _comic != null:
		var p: ComicPanel = _comic.panels[_panel_index]
		if not _panel_ended and _image_end_delay > 0.0:
			_image_end_delay -= delta
			if _image_end_delay <= 0.0:
				_panel_ended = true
				_show_next_prompt()
		if p.auto_advance_sec > 0.0:
			_panel_timer -= delta
			if _panel_timer <= 0.0:
				_next_panel()
				return
		if InputAccess.just_pressed():
			if _panel_ended or not advance_only_after_end:
				_next_panel()
	else:
		if skippable and InputAccess.just_pressed():
			_video.stop()
			_end()


# ==========================================================================
# shared begin/end + dialog integration
# ==========================================================================

func _begin() -> void:
	is_playing = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_layer.visible = true
	_advance_lock = 0.2
	started.emit()


func _show_next_prompt() -> void:
	_next_label.text = tr(next_text)
	_next_label.visible = true


func _end() -> void:
	if not is_playing:
		return
	is_playing = false
	_comic = null
	_next_label.visible = false
	_layer.visible = false
	_video.stop()
	_video.visible = false
	_video.stream = null
	_image.visible = false
	get_tree().paused = _was_paused
	finished.emit()


func _on_dialog_action(action_name: String, args: Array) -> void:
	if action_name != "cutscene" and action_name != "comic":
		return
	if args.is_empty() or not (args[0] is String):
		push_error("'%s' action needs args = [\"res://path\"]." % action_name)
		return
	if action_name == "cutscene":
		await play(args[0])
	else:
		var c := load(args[0])
		if c is Comic:
			await play_comic(c)
		else:
			push_error("'comic' action: '%s' is not a Comic resource." % args[0])
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
