@tool
extends EditorPlugin
## Adds the "Radio" dock at the bottom of the editor.
##
## Everything about a radio signal is set in that dock — its spot on the dial,
## how far it carries, and what happens when the player finds it. Nobody has to
## open the Inspector and nobody has to read the radio code.
##
## The dock writes `3MK-File/RadioMaker/radio_puzzle.tres`, and its "Place in
## scene" button drops the matching node into whatever level is open.

const PanelScript = preload("res://addons/radio_maker/maker_panel.gd")

var _panel: Control


func _enter_tree() -> void:
	_panel = PanelScript.new()
	_panel.undo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "Radio")


func _exit_tree() -> void:
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
