class_name LanguagePrompt extends CanvasLayer
## The "choose your language" screen shown the FIRST time the game runs.
##
## Put it in your main menu scene (or your very first scene). It checks
## Loc.needs_first_prompt() and hides itself instantly if the player has
## already chosen — so it costs nothing on every later launch.
##
## To test it again: call Loc.forget_choice() and restart.
##
## TURNING IT OFF: untick `enabled` in the Inspector, or set
## `first_launch_prompt = false` in loc.gd to kill it everywhere at once.
## Either way the node deletes itself in _ready and never touches the screen
## or the pause state, so a half-finished main menu still runs normally.

signal chosen(code: String)

## Shown above the buttons. Deliberately written in BOTH languages, since
## the player hasn't picked one yet and might not read English.
@export var heading: String = "Language  /  اللغة"
@export var button_min_size := Vector2(260, 56)
@export var font_size: int = 26
@export var dim_color := Color(0.03, 0.03, 0.05, 1.0)
## Pause the game while the prompt is up.
@export var pause_game: bool = true

## MASTER OFF SWITCH. Untick this while the main menu is still being built —
## the prompt then deletes itself immediately and changes nothing.
@export var enabled: bool = true

var _root: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not enabled:
		queue_free()          # switched off in the Inspector
		return

	# The global switch in loc.gd. Read defensively so this node still works
	# if Loc isn't registered as an autoload yet.
	var loc := get_node_or_null("/root/Loc")
	if loc == null:
		push_warning("LanguagePrompt: no Loc autoload — prompt skipped.")
		queue_free()
		return
	if loc.get("first_launch_prompt") == false:
		queue_free()          # switched off globally in loc.gd
		return

	if not loc.needs_first_prompt():
		queue_free()          # already chosen — never seen again
		return

	_build()
	if pause_game:
		get_tree().paused = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_root = CenterContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)

	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size + 6)
	col.add_child(title)

	for code in Loc.available():
		var b := Button.new()
		b.text = Loc.language_name(code)
		b.custom_minimum_size = button_min_size
		b.add_theme_font_size_override("font_size", font_size)
		b.pressed.connect(_pick.bind(code))
		col.add_child(b)

	if col.get_child_count() > 1:
		col.get_child(1).grab_focus()


func _pick(code: String) -> void:
	Loc.set_language(code)
	chosen.emit(code)
	if pause_game:
		get_tree().paused = false
	queue_free()
