class_name DialogLine extends Resource
## One thing a character says. BBCode is allowed in `text`
## (e.g. [b]bold[/b], [i]italic[/i]). Keywords become links automatically.
##
## A line can ALSO move the camera and/or fire a game action — and a line
## with empty text becomes a pure "do something" step (no box shown).

## What the character says. Leave EMPTY for a camera-only / action-only step.
@export_multiline var text: String = ""

## Optional speaker name override. Empty = use the NPC's name.
@export var speaker_name: String = ""

## Only show this line if this flag is set. Empty = always show.
@export var show_if_flag: String = ""

## HIDE this line once this flag is set. Empty = never hidden.
## Pair with show_if_flag on another line for "before vs after" variants:
##   Line A "Hello"            hide_if_flag = "Video"
##   Line B "You saw that?!"   show_if_flag = "Video"
@export var hide_if_flag: String = ""

## Flags to set the moment this line runs (e.g. ["talked_to_java"]).
@export var set_flags: Array[String] = []

## Words in this line that can become clickable topics.
@export var keywords: Array[DialogKeyword] = []

## Player choice buttons. If filled, replaces "press to continue".
@export var choices: Array[DialogChoice] = []

@export_group("Camera")
## Tween the active Camera2D to a point while this line plays (cutscene feel).
@export var move_camera: bool = false
@export var camera_target: Vector2 = Vector2.ZERO
@export var camera_time: float = 1.0

@export_group("Action")
## Fire DialogManager.action_requested(name, args) when this line runs.
## Your game listens for it (give item, open door, play cutscene, etc.).
@export var action_name: String = ""
@export var action_args: Array = []
## If true, the dialog pauses until your code calls DialogManager.finish_action().
@export var wait_for_action: bool = false
