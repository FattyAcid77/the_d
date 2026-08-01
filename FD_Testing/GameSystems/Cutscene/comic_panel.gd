class_name ComicPanel extends Resource
## One panel of a comic cutscene. Give it EITHER a video OR an image.
##
## VIDEO: drag your .ogv file straight from the FileSystem dock into the
## `video` slot. (Don't type a path — Godot 4.4+ hands over uid:// references
## when dragging, which text-path fields can't resolve.)
##
## Godot cannot play .gif or .mp4. Convert them first:
##   ffmpeg -i input.gif -c:v libtheora -q:v 8 output.ogv

## The panel's video — drag an .ogv here. Plays ONCE, then holds.
@export var video: VideoStream

## Or a still image for this panel (used when `video` is empty).
@export var image: Texture2D

## Sound played the moment this panel appears (optional).
@export var sound: AudioStream

## Flags set the moment this panel appears — so a panel can unlock
## dialogs, log entries, progress states...
@export var set_flags: Array[String] = []

## 0 = wait for the player to press interact. Any other value = the panel
## advances by itself after that many seconds.
@export var auto_advance_sec: float = 0.0

@export_group("Advanced")
## Optional fallback if you'd rather point at a path from code.
## The `video` slot above wins if both are set.
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
