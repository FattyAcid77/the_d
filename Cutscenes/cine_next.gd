@tool
class_name CutSceneMaker_v1Next
extends Resource
## One way out of a cutscene.
##
## A cutscene can list several. When it ends they are checked TOP TO BOTTOM
## and the first one whose flags pass is the one taken — the same rule your
## dialogue branches use, so put the most specific exit first and the plain
## fallback last.
##
##     0  require_flag = "found_evidence"   -> good_ending.tscn
##     1  (no flags)                        -> bad_ending.tscn
##
## With that, a player holding "found_evidence" gets the good ending and
## everyone else falls through to the bad one.

## This exit is only available once this flag is written. Empty = always.
@export var require_flag: String = ""

## If this flag IS written, this exit is skipped. Empty = never blocked.
@export var blocked_by_flag: String = ""

## The scene to go to. Leave empty to simply end the cutscene and stay put.
@export var scene: PackedScene

## Shown on the timeline card. If left empty, the scene's file name is used.
@export var label: String = ""

## Picture for the timeline card. Leave empty and the card uses the first
## frame of the target cutscene's own sprite sheet, so branching between
## cutscenes needs no artwork from you at all.
@export var thumbnail: Texture2D


## True when this exit is allowed right now.
func can_take() -> bool:
	if require_flag != "" and not Flags.is_set(require_flag):
		return false
	if blocked_by_flag != "" and Flags.is_set(blocked_by_flag):
		return false
	return true


## Name for the timeline card.
func title() -> String:
	if label != "":
		return label
	if scene != null and scene.resource_path != "":
		return scene.resource_path.get_file().get_basename()
	return "(no scene)"


## Short description of when this exit is taken.
func condition_text() -> String:
	if require_flag != "" and blocked_by_flag != "":
		return "if %s and not %s" % [require_flag, blocked_by_flag]
	if require_flag != "":
		return "if " + require_flag
	if blocked_by_flag != "":
		return "if not " + blocked_by_flag
	return "otherwise"
