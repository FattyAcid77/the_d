class_name ComicPanel extends Resource
## One panel of a comic cutscene. Give it either a video or an image.

@export var video: VideoStream

## Or a still image for this panel (used when `video` is empty).
@export var image: Texture2D

## Sound played the moment this panel appears (optional).
@export var sound: AudioStream

## Flags set the moment this panel appears - so a panel can unlock dialogs, log entries
@export var set_flags: Array[String] = []

## 0 = wait for the player to press interact.
@export var auto_advance_sec: float = 0.0

@export_group("Advanced")
## Optional fallback if you'd rather point at a path from code.
@export var video_path: String = ""


## Returns the stream to play, from either field.
func get_stream() -> VideoStream:
	if video:
		return video
	if video_path != "":
		var s := load(video_path)
		if s is VideoStream:
			return s
	return null
