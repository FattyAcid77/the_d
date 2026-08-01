class_name DialogChoice extends Resource
## A button the player can press during a line.
## Choices are for branching CONVERSATION (this line, right now).
## Keywords/topics are for asking ABOUT things. Use whichever fits.

## Text shown on the button.
@export_multiline var text: String = ""

## Only show this choice if this flag is set. Empty = always show.
@export var show_if_flag: String = ""

## Set this flag when the choice is picked. Empty = nothing.
@export var set_flag: String = ""

## Jump to this branch id when picked. Empty = just continue the line list.
@export var goto_branch: String = ""

## If true, picking this choice closes the whole dialog.
@export var ends_dialog: bool = false
