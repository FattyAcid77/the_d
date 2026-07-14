class_name DialogTrigger extends Area2D
## Drop this under an NPC (or anything talkable). When the player is inside it
## and presses the "interact" action, it starts that thing's dialog.
## Shows the "Prompt" child while the player is in range.
##
## Where the dialog comes from, in priority order:
##   1. the `dialog` slot on this trigger
##   2. the parent NPC's NPCResource.dialog
##   3. the demo apple dialog, if `use_demo_dialog` is ticked

@export var dialog: Dialog
@export var use_demo_dialog: bool = false
@export var speaker_name: String = ""
@export var portrait: Texture2D

var _player_in: bool = false
var _player_node: Node2D = null
var _cooldown_until: int = 0   # blocks reopening right after a dialog closes
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	if dialog == null:
		dialog = _dialog_from_npc()
	if dialog == null and use_demo_dialog:
		dialog = DemoDialog.build()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	DialogManager.dialog_finished.connect(_on_dialog_finished)
	if prompt:
		prompt.visible = false


func _process(_delta: float) -> void:
	if _player_in and not DialogManager.is_active \
			and Time.get_ticks_msec() >= _cooldown_until \
			and Input.is_action_just_pressed("interact"):
		_start()


func _start() -> void:
	if dialog == null:
		push_warning("DialogTrigger has no dialog assigned.")
		return
	var nm: String = speaker_name
	var pt: Texture2D = portrait
	var npc := get_parent()
	if npc is NPC and npc.npc_resource:
		if nm == "":
			nm = npc.npc_resource.npc_name
		if pt == null:
			pt = npc.npc_resource.portrait
		if _player_node:
			npc.face_toward(_player_node.global_position)   # look at who you talk to
	if prompt:
		prompt.visible = false
	DialogManager.start_dialog(dialog, nm, pt)


func _on_dialog_finished() -> void:
	# small grace period so the closing keypress doesn't immediately reopen
	_cooldown_until = Time.get_ticks_msec() + 300
	if _player_in and prompt:
		prompt.visible = true


func _dialog_from_npc() -> Dialog:
	var npc := get_parent()
	if npc is NPC and npc.npc_resource:
		return npc.npc_resource.dialog
	return null


func _is_player(body: Node2D) -> bool:
	return body.is_in_group("Player") or body is Player


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in = true
		_player_node = body
		if prompt and not DialogManager.is_active:
			prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in = false
		_player_node = null
		if prompt:
			prompt.visible = false
