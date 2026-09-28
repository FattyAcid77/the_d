@tool
extends EditorPlugin
## Pickers for the inspector: sounds and music sets, flags, and ids (death
## causes, items, windows, rooms, states). Rescans whenever something is saved.
## Plus the Check panel, which lists what will break before a playtest does.

const Library := preload("library.gd")
const Tools := preload("tools.gd")
const Inspector := preload("inspector.gd")
const Names := preload("names.gd")
const CheckDock := preload("check_dock.gd")

var library: Library
var names: Names
var tools: Tools
var inspector: Inspector
var check_dock: CheckDock


func _enter_tree() -> void:
	library = Library.new()
	names = Names.new()
	tools = Tools.new()
	tools.library = library
	tools.names = names
	add_child(tools)
	inspector = Inspector.new()
	inspector.tools = tools
	add_inspector_plugin(inspector)
	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.connect(library.scan)
	fs.filesystem_changed.connect(names.scan)
	resource_saved.connect(_on_saved)
	scene_saved.connect(func(_p): names.scan())
	library.scan()
	names.scan()
	# bottom panel, next to Output: a list of problems wants the width
	check_dock = CheckDock.new(tools)
	add_control_to_bottom_panel(check_dock, "Check")


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.filesystem_changed.is_connected(library.scan):
		fs.filesystem_changed.disconnect(library.scan)
	if fs.filesystem_changed.is_connected(names.scan):
		fs.filesystem_changed.disconnect(names.scan)
	remove_inspector_plugin(inspector)
	remove_control_from_bottom_panel(check_dock)
	check_dock.queue_free()
	tools.queue_free()


func _on_saved(res: Resource) -> void:
	if Library.class_of(res) in ["SoundDef", "MusicSet"]:
		library.scan()
	names.scan()
