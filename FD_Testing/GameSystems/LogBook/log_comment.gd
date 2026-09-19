class_name LogComment extends Resource
## A comment box on the knowledge board - like Unreal Blueprint comments: a
## big colored rectangle with a title, sitting behind the cards, used to group
## and label regions ("The Apple Case", "Act 2", ...). Save as .tres in the
## Entries folder - loaded automatically.

@export var title: String = ""

## Top-left corner of the box on the board.
@export var position: Vector2 = Vector2.ZERO

## Size of the box.
@export var size: Vector2 = Vector2(400, 300)

@export var color: Color = Color(0.35, 0.55, 0.85, 0.18)

## on = only visible while LogBook.show_dev_comments is true (your private organization).
@export var dev_only: bool = false
