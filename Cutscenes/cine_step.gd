@tool
class_name CutSceneMaker_v1Step
extends Resource
## One beat of a cutscene.
##
## Pick a Kind and the Inspector hides every field that Kind doesn't use, so
## you only ever see the two or three boxes that matter. That hiding is the
## whole point of this file — see `_validate_property()`.
##
## `at_time` is seconds from the START of the cutscene, not from the last
## beat. Beats can share a time; they fire in the order you listed them.

enum Kind {
	SAY,        ## Show a line in the box. Empty text hides the box.
	CAMERA,     ## Pan the active Camera2D to a world point.
	MOVE,       ## Slide a node to `to_position`.
	FADE,       ## Fade the black overlay. 0 = clear, 1 = black.
	LETTERBOX,  ## Slide the cinematic bars. 0 = off, 1 = full.
	SOUND,      ## Play a one-shot.
	FLAG,       ## Write a flag, so the game remembers this happened.
}

## Every optional field, in one place. `_validate_property()` walks this list
## and hides anything the current Kind didn't ask for.
const OPTIONAL_FIELDS: PackedStringArray = [
	"speaker", "text", "hold",
	"target", "to_position", "duration",
	"amount", "sound", "flag_name",
]

## Colour used for this Kind's marker in the timeline dock.
const KIND_COLORS: Dictionary = {
	Kind.SAY: Color("4aa3ff"),
	Kind.CAMERA: Color("b06bff"),
	Kind.MOVE: Color("ff8a3d"),
	Kind.FADE: Color("7a7a7a"),
	Kind.LETTERBOX: Color("d9d9d9"),
	Kind.SOUND: Color("3ddc84"),
	Kind.FLAG: Color("ffd24a"),
}


## When this beat fires, in seconds from the start of the cutscene.
@export var at_time: float = 0.0

## Which sub-lane this clip sits on inside its track in the timeline dock.
## Purely a layout choice — it has no effect on playback whatsoever. You set
## it by dragging the clip up or down, and clips are free to touch or overlap.
@export var lane: int = 0

## What this beat does. Changing it changes which fields appear below.
@export var kind: Kind = Kind.SAY:
	set(value):
		kind = value
		notify_property_list_changed()  # redraw the Inspector right away
		emit_changed()

## Shown in the name plate. Leave empty for a narrator line.
@export var speaker: String = ""

## The line itself. Arabic is fine — direction is detected automatically.
## Leave empty to hide the dialogue box at this point in the timeline.
@export_multiline var text: String = ""

## Freeze the timeline until the player presses the key. Uncheck to talk over
## an animation that keeps playing underneath.
##
## When this is ON, `duration` is ignored — the line waits for the player
## however long that takes.
@export var hold: bool = true

## MOVE only: which node to slide, as seen from the level, e.g. `Guard`.
@export var target: NodePath

## Where to end up. CAMERA reads this as a world point.
@export var to_position: Vector2 = Vector2.ZERO

## How long the slide or fade takes. 0 snaps instantly.
@export var duration: float = 1.0

## 0 = fully off (clear screen / no bars), 1 = fully on (black / full bars).
@export_range(0.0, 1.0) var amount: float = 1.0

@export var sound: AudioStream

## Name of the flag to write, e.g. "saw_door_cutscene".
@export var flag_name: String = ""


## Kinds whose `duration` field means something — the Inspector shows it and
## the timeline gives the clip resize handles. For SOUND it means "trim",
## for the rest it means "how long the slide takes".
func uses_duration() -> bool:
	return kind in [Kind.SAY, Kind.CAMERA, Kind.MOVE, Kind.FADE, Kind.LETTERBOX, Kind.SOUND]


## How long this step occupies the CUTSCENE.
##
## SOUND is deliberately zero: a long audio file must not silently stretch the
## scene. `duration` is a shared field, so instant kinds still carry the
## default 1.0 even though the Inspector hides it — counting that would add a
## phantom second to every cutscene ending on a FLAG.
func span() -> float:
	if kind == Kind.SOUND:
		return 0.0
	return duration if uses_duration() else 0.0


## True when this line hides itself after `duration` instead of waiting for
## the player. A held line ignores duration entirely.
func is_timed_line() -> bool:
	return kind == Kind.SAY and not hold and duration > 0.0


## True when this sound has been cut short of its natural length.
func is_trimmed() -> bool:
	return kind == Kind.SOUND and duration > 0.0 and duration < sound_length()


## Seconds of audio that will actually be heard.
func sound_play_time() -> float:
	return duration if is_trimmed() else sound_length()


## The real length of the assigned audio, in seconds. Zero if there is none.
func sound_length() -> float:
	if sound == null:
		return 0.0
	return sound.get_length()


## Width the timeline should draw this clip at.
##
## Deliberately different from `span()`: a SOUND clip is drawn as long as the
## audio actually is, so you can see where it ends and place the next beat
## after it — but it does NOT feed `end_time()`, so dropping in a long track
## can't silently stretch the whole cutscene.
func display_span() -> float:
	if kind == Kind.SOUND:
		return sound_play_time()
	return span()


## Short label for the timeline dock, so a marker says what it is at a glance.
func summary() -> String:
	match kind:
		Kind.SAY:
			if text.is_empty():
				return "hide box"
			var short: String = text.substr(0, 18).replace("\n", " ")
			return ("%s: %s" % [speaker, short]) if speaker != "" else short
		Kind.CAMERA:
			return "cam -> %s" % str(to_position)
		Kind.MOVE:
			return "move %s" % str(target)
		Kind.FADE:
			return "fade %.1f" % amount
		Kind.LETTERBOX:
			return "bars %.1f" % amount
		Kind.SOUND:
			if sound == null:
				return "sound: (none)"
			var file: String = sound.resource_path.get_file()
			if file.is_empty():
				file = "sound"
			if is_trimmed():
				return "%s  %.2fs (trimmed from %.2fs)" % [file, duration, sound_length()]
			return "%s  %.2fs" % [file, sound_length()]
		Kind.FLAG:
			return "flag: %s" % flag_name
	return ""


func color() -> Color:
	return KIND_COLORS.get(kind, Color.WHITE)


## Hides every property this Kind has no use for. Without it the Inspector
## shows all nine optional fields on every single step and nobody can tell
## which three matter.
func _validate_property(property: Dictionary) -> void:
	# `lane` is set by dragging in the dock, so it would only be clutter here.
	# NO_EDITOR still stores it, it just stops showing in the Inspector.
	if property.name == "lane":
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	if property.name not in OPTIONAL_FIELDS:
		return
	if property.name not in _fields_for_kind():
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _fields_for_kind() -> PackedStringArray:
	match kind:
		Kind.SAY:
			return ["speaker", "text", "hold", "duration"]
		Kind.CAMERA:
			return ["to_position", "duration"]
		Kind.MOVE:
			return ["target", "to_position", "duration"]
		Kind.FADE, Kind.LETTERBOX:
			return ["amount", "duration"]
		Kind.SOUND:
			return ["sound", "duration"]
		Kind.FLAG:
			return ["flag_name"]
	return []
