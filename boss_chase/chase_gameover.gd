class_name ChaseGameOver extends CanvasLayer

# Full-screen result overlay. Structure cloned from control scene/Pause_Menu.tscn:
# a CanvasLayer with process_mode = ALWAYS so its button still responds while
# the tree is paused, and layer 6 so it sits above the PauseMenu autoload's 5.

signal restart_pressed

@onready var title: Label = $Control/Center/Box/Title
@onready var subtitle: Label = $Control/Center/Box/Subtitle
@onready var restart_button: Button = $Control/Center/Box/Restart


func _ready() -> void:
	restart_button.pressed.connect(func(): restart_pressed.emit())
	hide_result()


func show_result(title_text: String, subtitle_text: String) -> void:
	title.text = title_text
	subtitle.text = subtitle_text
	visible = true
	restart_button.grab_focus()


func hide_result() -> void:
	visible = false
