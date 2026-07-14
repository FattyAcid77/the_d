extends Node
## Cutscene — add as an Autoload named "Cutscene".
## Plays a video (.ogv ONLY — Godot cannot play .mp4) fullscreen, on top of
## everything, with the game paused. One function:
##
##     Cutscene.play("res://GameSystems/Cutscene/test_anime.ogv")
##
## and if you need to wait for it before continuing:
##
##     await Cutscene.play("res://GameSystems/Cutscene/test_anime.ogv")
##     print("cutscene over, do the next thing")
##
## From DIALOG (the "when this word appears" case): on any DialogLine set
##     action_name = "cutscene"
##     action_args = ["res://GameSystems/Cutscene/test_anime.ogv"]
##     wait_for_action = ON
## and the conversation pauses, plays the video, then continues by itself.
##
## Converting videos:  ffmpeg -i input.mp4 -c:v libtheora -q:v 8 -c:a libvorbis -q:a 5 output.ogv

signal started
signal finished

## Let the player skip with the "interact" key.
@export var skippable: bool = true

var is_playing: bool = false

var _layer: CanvasLayer
var _black: ColorRect
var _ratio_box: AspectRatioContainer
var _video: VideoStreamPlayer
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	# listen for dialog "cutscene" actions, without hard-depending on DialogManager
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_signal("action_requested"):
		dm.action_requested.connect(_on_dialog_action)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90                      # above the dialog box
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)

	_ratio_box = AspectRatioContainer.new()
	_ratio_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ratio_box.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_layer.add_child(_ratio_box)

	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.finished.connect(_on_video_finished)
	_ratio_box.add_child(_video)

	_layer.visible = false


## Play a .ogv video. Await this call to continue after it ends.
func play(video_path: String) -> void:
	if is_playing:
		push_warning("Cutscene already playing; ignoring play('%s')." % video_path)
		return
	if video_path.get_extension().to_lower() == "mp4":
		push_error("Cutscene: Godot cannot play .mp4 — convert to .ogv (see this script's header).")
		return
	var stream: VideoStream = load(video_path)
	if stream == null:
		push_error("Cutscene: could not load '%s'." % video_path)
		return

	is_playing = true
	_was_paused = get_tree().paused
	get_tree().paused = true

	_video.stream = stream
	_layer.visible = true
	_video.play()
	started.emit()

	# match the black bars to the video's real shape once the first frame exists
	await get_tree().process_frame
	var tex := _video.get_video_texture()
	if tex and tex.get_size().y > 0:
		_ratio_box.ratio = tex.get_size().x / tex.get_size().y

	await finished


func _process(_delta: float) -> void:
	if is_playing and skippable and Input.is_action_just_pressed("interact"):
		_video.stop()
		_on_video_finished()


func _on_video_finished() -> void:
	if not is_playing:
		return
	is_playing = false
	_layer.visible = false
	_video.stream = null
	get_tree().paused = _was_paused
	finished.emit()


## Dialog integration: a line with action_name "cutscene" plays args[0].
func _on_dialog_action(action_name: String, args: Array) -> void:
	if action_name != "cutscene":
		return
	if args.is_empty() or not (args[0] is String):
		push_error("Cutscene action needs args = [\"res://path/to/video.ogv\"].")
		return
	await play(args[0])
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_waiting_action") and dm.is_waiting_action():
		dm.finish_action()
