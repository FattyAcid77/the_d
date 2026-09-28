@tool
extends VBoxContainer
## The Check tab: Run reads the whole project and lists what will break, what's
## probably a mistake and what's missing from the translations. Double-click a
## line to open that scene with the node selected, or that resource.

const Checker := preload("checker.gd")

var checker: Checker
var run_button: Button
var summary: Label
var tree: Tree
var _groups := {}


func _init(p_tools) -> void:
	name = "Check"
	checker = Checker.new()
	checker.library = p_tools.library
	checker.names = p_tools.names
	var bar := HBoxContainer.new()
	add_child(bar)
	run_button = Button.new()
	run_button.text = "Run"
	run_button.tooltip_text = "Read every level, resource and dialog in the project"
	run_button.pressed.connect(run)
	bar.add_child(run_button)
	summary = Label.new()
	summary.text = "Press Run before a build or when something doesn't work."
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 120
	bar.add_child(summary)
	tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.columns = 2
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, true)
	tree.set_column_expand_ratio(0, 3)
	tree.set_column_expand_ratio(1, 2)
	tree.item_activated.connect(_on_activated)
	add_child(tree)
	var hint := Label.new()
	hint.text = "Double-click a line to go there. Fix it, then Run again."
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)


func run() -> void:
	run_button.disabled = true
	summary.text = "Checking..."
	await get_tree().process_frame
	var list := checker.run()
	_show(list)
	run_button.disabled = false


func _show(list: Array) -> void:
	tree.clear()
	_groups.clear()
	var root := tree.create_item()
	var th := EditorInterface.get_editor_theme()
	var heads := {
		Checker.RED: ["Will break", "StatusError"],
		Checker.YELLOW: ["Probably a mistake", "StatusWarning"],
		Checker.TRANSLATION: ["Translations", "Translation"],
	}
	for level in [Checker.RED, Checker.YELLOW, Checker.TRANSLATION]:
		var n := checker.count(level)
		var g := tree.create_item(root)
		g.set_text(0, "%s (%d)" % [heads[level][0], n])
		g.set_icon(0, th.get_icon(heads[level][1], "EditorIcons"))
		g.set_selectable(0, false)
		g.set_selectable(1, false)
		g.collapsed = level == Checker.TRANSLATION or n == 0
		_groups[level] = g
	for p in list:
		var it := tree.create_item(_groups[p.level])
		it.set_text(0, p.text)
		it.set_tooltip_text(0, p.text)
		var where: String = str(p.path).get_file() + (" > " + str(p.node) if str(p.node) != "" and str(p.node) != "." else "")
		it.set_text(1, where)
		it.set_tooltip_text(1, str(p.path) + (("  " + p.node) if p.node != "" else ""))
		it.set_metadata(0, p)
	var red := checker.count(Checker.RED)
	var yellow := checker.count(Checker.YELLOW)
	var tr := checker.count(Checker.TRANSLATION)
	if red + yellow + tr == 0:
		summary.text = "All clear."
	else:
		summary.text = "%d will break, %d to look at, %d translations." % [red, yellow, tr]


func _on_activated() -> void:
	var it := tree.get_selected()
	if it and it.get_metadata(0) is Dictionary:
		go_to(it.get_metadata(0))


## Opens the scene and selects the node, or opens the resource.
func go_to(p: Dictionary) -> void:
	var path := str(p.path)
	if path.ends_with(".tscn"):
		EditorInterface.open_scene_from_path(path)
		for i in 3:
			await get_tree().process_frame
		var root := EditorInterface.get_edited_scene_root()
		if root == null:
			return
		var node: Node = root
		if str(p.node) != "" and str(p.node) != ".":
			node = root.get_node_or_null(NodePath(str(p.node)))
		if node:
			var sel := EditorInterface.get_selection()
			sel.clear()
			sel.add_node(node)
			EditorInterface.edit_node(node)
	elif ResourceLoader.exists(path):
		EditorInterface.edit_resource(load(path))
	elif FileAccess.file_exists(path):
		EditorInterface.select_file(path)
