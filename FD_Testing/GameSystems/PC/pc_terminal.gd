class_name PcTerminal extends Area2D
## A computer in the world. Sami walks up, presses interact, and the PC screen
## takes over until the player shuts it down.

signal opened
signal closed
signal refused

## The PC screen to open.
@export var screen_scene: PackedScene = preload("res://FD_Testing/GameSystems/PC/pc_screen.tscn")
## The PC only works once this flag is set. Empty = always.
@export var require_flag: String = ""
## Flag set the first time the PC is used.
@export var used_flag: String = ""
## Which group counts as the player.
@export var player_group: String = "Player"
@export var debug_log: bool = false

var is_open := false

var _player_in := false
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false


func _process(_delta: float) -> void:
	if is_open or not _player_in:
		return
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.is_active:
		return
	if InputAccess.just_pressed():
		open()


## Opens the PC from code too (a dialog action, a cutscene).
func open() -> void:
	if is_open:
		return
	var flags := get_node_or_null("/root/Flags")
	if require_flag != "" and flags and not flags.is_set(require_flag):
		if debug_log:
			print("PcTerminal: %s needs flag '%s'" % [name, require_flag])
		refused.emit()
		return
	if screen_scene == null:
		push_warning("PcTerminal: %s has no screen_scene." % name)
		return
	if not get_tree().get_nodes_in_group("pc_screen").is_empty():
		return
	var screen := screen_scene.instantiate()
	if screen.has_signal("closed"):
		screen.closed.connect(_on_screen_closed)
	is_open = true
	if prompt:
		prompt.visible = false
	# deferred: the root may be busy if this runs while a level is loading
	get_tree().root.add_child.call_deferred(screen)
	if used_flag != "" and flags:
		flags.set_flag(used_flag)
	if debug_log:
		print("PcTerminal: %s opened" % name)
	opened.emit()


func _on_screen_closed() -> void:
	is_open = false
	if prompt:
		prompt.visible = _player_in
	closed.emit()


func _on_entered(body: Node) -> void:
	if body.is_in_group(player_group) or body is Player:
		_player_in = true
		if prompt and not is_open:
			prompt.visible = true


func _on_exited(body: Node) -> void:
	if body.is_in_group(player_group) or body is Player:
		_player_in = false
		if prompt:
			prompt.visible = false
