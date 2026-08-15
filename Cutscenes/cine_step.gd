@tool
class_name CineStep
extends Resource
## One beat of a cutscene.
##
## Pick a Kind and the Inspector hides every field that Kind doesn't use, so
## you only ever see the two or three boxes that actually do something. That
## hiding is the whole point of this file — see `_validate_property()`.
##
## `at_time` is seconds from the START of the cutscene, not from the last
## beat. Beats can share a time; they fire in the order you listed them.

enum Kind {
	SAY,        ## Show a line in the box. Empty text hides the box.
	CAMERA,     ## Pan the active Camera2D to a world point.
	MOVE,       ## Slide a node to `to_position`.
	FADE,       ## Fade the black overlay. 0 = clear, 1 = black.
	LETTERBOX,  ## Slide the cinematic bars. 0 = off, 1 = full.
	SOUND,      ## Play a one-shot through the Audio autoload.
	FLAG,       ## Set a flag in the Flags autoload, so the game remembers.
}

## Every optional field, in one place. `_validate_property()` walks this list
## and hides anything the current Kind didn't ask for.
const OPTIONAL_FIELDS: PackedStringArray = [
	"speaker", "text", "hold",
	"target", "to_position", "duration",
	"amount", "sound", "flag_name",
]


## When this beat fires, in seconds from the start of the cutscene.
@export var at_time: float = 0.0

## What this beat does. Changing it changes which fields appear below.
@export var kind: Kind = Kind.SAY:
	set(value):
		kind = value
		notify_property_list_changed()  # redraw the Inspector right away

## Shown in the name plate. Leave empty for a narrator line.
@export var speaker: String = ""

## The line itself. Arabic is fine — the box flips to right-to-left on its own.
## Leave this empty to hide the dialogue box at this point in the timeline.
@export_multiline var text: String = ""

## Freeze the timeline until the player presses the key. Uncheck to talk over
## an animation that keeps playing underneath.
@export var hold: bool = true

## MOVE only: which node to slide. Type its name as seen from the level, e.g.
## `Sami` or `NPCs/Guard`. This is the one field you type by hand.
@export var target: NodePath

## Where to end up. CAMERA reads this as a world point.
@export var to_position: Vector2 = Vector2.ZERO

## How long the slide or fade takes. 0 snaps instantly.
@export var duration: float = 1.0

## 0 = fully off (clear screen / no bars), 1 = fully on (black / full bars).
@export_range(0.0, 1.0) var amount: float = 1.0

@export var sound: AudioStream

## Name of the flag to set, e.g. "saw_door_cutscene".
@export var flag_name: String = ""


## Hides every property this Kind has no use for. Without it the Inspector
## shows all nine optional fields on every single step and nobody can tell
## which three matter.
func _validate_property(property: Dictionary) -> void:
	if property.name not in OPTIONAL_FIELDS:
		return
	if property.name not in _fields_for_kind():
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _fields_for_kind() -> PackedStringArray:
	match kind:
		Kind.SAY:
			return ["speaker", "text", "hold"]
		Kind.CAMERA:
			return ["to_position", "duration"]
		Kind.MOVE:
			return ["target", "to_position", "duration"]
		Kind.FADE, Kind.LETTERBOX:
			return ["amount", "duration"]
		Kind.SOUND:
			return ["sound"]
		Kind.FLAG:
			return ["flag_name"]
	return []
