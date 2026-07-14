class_name DialogBranch extends Resource
## A named chunk of conversation. The branch with id "entry" plays first
## when the player talks. Other branches are "topics" opened by keywords
## or choices (e.g. id "apple").

## Unique name within this NPC's dialog. Use "entry" for the opening branch.
@export var id: String = ""

## The lines, played top to bottom (lines whose show_if_flag isn't met are skipped).
@export var lines: Array[DialogLine] = []
