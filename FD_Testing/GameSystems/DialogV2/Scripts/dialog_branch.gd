class_name DialogBranch extends Resource
## A named chunk of conversation. The branch with id "entry" plays first
## when the player talks. Other branches are "topics" opened by keywords
## or choices (e.g. id "apple").

## Unique name within this NPC's dialog. Use "entry" for the opening branch.
@export var id: String = ""

@export_group("When this branch plays")
## ALL of these flags must be set for this branch to be available.
## Empty = no requirement.
@export var require_flags: Array[String] = []

## If ANY of these flags is set, this branch is hidden completely.
## (This is how an old branch disappears once the story moves on.)
@export var blocked_by_flags: Array[String] = []

## Play this branch only once, ever.
@export var play_once: bool = false

@export_group("Show as a topic")
## If ON, this branch appears as a topic button in the conversation hub —
## no keyword needed. This is the easy way to give an NPC many subjects.
@export var is_topic: bool = false

## Button text. If empty, the branch id is used.
@export var topic_label: String = ""

## The topic only appears once this flag is set. Empty = always available.
@export var unlock_flag: String = ""

## If ON, the topic disappears after the player has fully heard it.
@export var ask_once: bool = false

## The lines, played top to bottom (lines whose show_if_flag isn't met are skipped).
@export var lines: Array[DialogLine] = []


## True if this branch is currently allowed to play.
func can_play() -> bool:
	for f in require_flags:
		if not Flags.is_set(f):
			return false
	for f in blocked_by_flags:
		if Flags.is_set(f):
			return false
	if play_once and Flags.is_set("topic_seen:" + id):
		return false
	return true
