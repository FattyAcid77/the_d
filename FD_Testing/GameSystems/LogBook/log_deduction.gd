class_name LogDeduction extends Resource
## A deduction puzzle on the knowledge board. When all required entries are
## discovered, a mystery "+" card appears showing how many connections it
## needs.

@export var id: String = ""

## Entry ids the player must connect
@export var required_entries: Array[String] = []

## Where the mystery/result card sits on the board.
@export var board_position: Vector2 = Vector2.ZERO

@export_group("Result (after solving)")
## Title of the revealed entry (e.g.
@export var result_title: String = ""
## The text shown when the solved card is clicked.
@export_multiline var result_text: String = ""
@export var result_color: Color = Color(0.9, 0.35, 0.35)
@export var result_picture: Texture2D
## Flag raised on solve - dialogs react via show_if_flag, states can auto-advance on it, etc.
@export var result_flag: String = ""


func needed() -> int:
	return required_entries.size()


func is_solved() -> bool:
	return result_flag != "" and Flags.is_set(result_flag)
