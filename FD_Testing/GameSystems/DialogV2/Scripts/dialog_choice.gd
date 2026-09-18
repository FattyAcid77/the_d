class_name DialogChoice extends Resource
## A button the player can press during a line. Choices are for branching
## conversation (this line, right now).

@export_multiline var text: String = ""

## Only show this choice if this flag is set.
@export var show_if_flag: String = ""

## Set this flag when the choice is picked.
@export var set_flag: String = ""

## Jump to this branch id when picked.
@export var goto_branch: String = ""

## If true, picking this choice closes the whole dialog.
@export var ends_dialog: bool = false
