extends CanvasLayer



func _on_button_pressed() -> void:
	visible = false
	get_parent().visible = true
