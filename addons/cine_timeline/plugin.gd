@tool
extends EditorPlugin
## Adds the "Cutscene" dock at the bottom of the editor.
##
## The dock follows the selection: click a CutSceneMaker_v1Player in the scene tree and
## the timeline fills in. Click anything else and it goes idle.

const PanelScript = preload("res://addons/cine_timeline/timeline_panel.gd")

var _panel: Control


func _enter_tree() -> void:
	_panel = PanelScript.new()
	_panel.undo = get_undo_redo()
	add_control_to_bottom_panel(_panel, "Cutscene")
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


func _exit_tree() -> void:
	if EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	if _panel != null:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null


func _on_selection_changed() -> void:
	if _panel == null:
		return
	for node in EditorInterface.get_selection().get_selected_nodes():
		# The dock is useful whether you clicked the cutscene root or one of
		# its children, so walk up until we find one.
		var walk: Node = node
		while walk != null:
			if walk is CutSceneMaker_v1Player:
				_panel.set_target(walk)
				return
			walk = walk.get_parent()
	_panel.set_target(null)
