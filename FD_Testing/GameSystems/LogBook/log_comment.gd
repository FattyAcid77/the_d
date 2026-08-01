class_name LogComment extends Resource
## A comment box on the knowledge board — like Unreal Blueprint comments:
## a big colored rectangle with a title, sitting BEHIND the cards, used to
## group and label regions ("The Apple Case", "Act 2", ...).
##
## Save as .tres in the Entries folder — loaded automatically.
## `dev_only` boxes are visible only when LogBook.show_dev_comments is ON,
## so you can keep organizational notes the player never sees.

@export var title: String = ""

## Top-left corner of the box on the board.
@export var position: Vector2 = Vector2.ZERO

## Size of the box.
@export var size: Vector2 = Vector2(400, 300)

@export var color: Color = Color(0.35, 0.55, 0.85, 0.18)

## ON = only visible while LogBook.show_dev_comments is true (your private
## organization). OFF = the player sees it too (nice for region labels).
@export var dev_only: bool = false
