class_name DialogZone extends Area2D
## A patch of floor that FORCES a dialog to start when Sami walks into it.
## No interact key, no choice — he steps in, the box opens.
##
## This is deliberately SEPARATE from the NPC. Use it for:
##   * an ambush line the moment he enters a room
##   * a voice from nowhere ("don't go in there")
##   * an NPC across the room shouting at him without him talking to them
##   * scripted story beats tied to a place, not a person
##
## SCENE SHAPE
##   DialogZone (Area2D, this script)
##   └── CollisionShape2D        <- draw the patch of floor here
##
## WHERE THE WORDS COME FROM — pick ONE:
##   1. `dialog`   — drag a Dialog .tres straight in. Simplest.
##   2. `speaker`  — point at an NPC node in the level. The zone borrows that
##                   NPC's dialog, name and portrait, so the line looks like
##                   it came from them even though they're across the room.
##
## Branch choice still works exactly as everywhere else: the NPC decides which
## branch plays based on world flags. The zone only decides WHEN.

signal triggered
signal dialog_ended

@export_group("What it says")
## A Dialog .tres. Used when `speaker` is empty.
@export var dialog: Dialog
## Optional NPC in this level to borrow the dialog/name/portrait from.
## When set, this WINS over the `dialog` above.
@export var speaker: NodePath
## Overrides the name in the box. Empty = the NPC's name, or nothing.
@export var speaker_name: String = ""
## Overrides the portrait. Empty = the NPC's portrait, or none.
@export var portrait: Texture2D

@export_group("When it fires")
## ON  = fires once ever, then the zone is done for good (saved via flag).
## OFF = fires every time he walks in (see `cooldown`).
@export var once_only: bool = true
## Seconds before it can fire again. Ignored when once_only is ON.
@export var cooldown: float = 0.0
## Don't fire while another dialog is already running (almost always ON).
@export var skip_if_dialog_active: bool = true
## Wait this long after he enters before the box opens. Good for letting him
## walk a step or two into the room first.
@export var delay: float = 0.0

@export_group("Flags")
## The zone only exists once this flag is set. Empty = always armed.
@export var require_flag: String = ""
## The zone is dead once this flag is set.
@export var hide_flag: String = ""
## Flag set the moment it fires. With once_only ON this is also what
## remembers it across saves — leave it empty and one is made from the
## node's name automatically.
@export var set_flag: String = ""
## Flag set when the dialog it started finishes.
@export var finished_flag: String = ""

@export_group("The player")
## Freeze Sami while the dialog runs. Works by setting his `frozen` /
## `can_move` property if he has one — harmless if he doesn't.
@export var freeze_player: bool = true
## Which group counts as the player.
@export var player_group: String = "Player"

@export_group("Debug")
## Draw the zone in-game so you can see where it is while building.
@export var show_in_game: bool = false
@export var debug_log: bool = false

var _fired := false
var _cool := 0.0
var _player: Node2D = null
var _auto_flag: String = ""


func _ready() -> void:
	_auto_flag = set_flag if set_flag != "" else "dialogzone_" + str(name)
	body_entered.connect(_on_entered)
	monitoring = true
	_refresh_armed()

	if not show_in_game:
		for c in get_children():
			if c is CollisionShape2D or c is CollisionPolygon2D:
				c.visible = false


func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta


# --- arming ----------------------------------------------------------------

## Is this zone allowed to exist right now?
func is_armed() -> bool:
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		return true
	if require_flag != "" and not flags.is_set(require_flag):
		return false
	if hide_flag != "" and flags.is_set(hide_flag):
		return false
	if once_only and flags.is_set(_auto_flag):
		return false
	return true


func _refresh_armed() -> void:
	set_deferred("monitoring", is_armed())


# --- firing ----------------------------------------------------------------

func _on_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player = body
	if not is_armed():
		return
	if _fired and once_only:
		return
	if _cool > 0.0:
		return

	var dm := get_node_or_null("/root/DialogManager")
	if skip_if_dialog_active and dm and dm.is_active:
		return

	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		# he may have left, or a dialog may have started, during the wait
		if not is_instance_valid(self) or not is_armed():
			return
		if skip_if_dialog_active and dm and dm.is_active:
			return

	_fire()


func _fire() -> void:
	var dm := get_node_or_null("/root/DialogManager")
	if dm == null:
		push_warning("DialogZone '%s': no DialogManager autoload." % name)
		return

	var d := _resolve_dialog()
	if d == null:
		push_warning("DialogZone '%s': nothing to say — set `dialog` or `speaker`." % name)
		return

	_fired = true
	_cool = cooldown

	var flags := get_node_or_null("/root/Flags")
	if flags:
		flags.set_flag(_auto_flag)

	if freeze_player:
		_set_player_frozen(true)

	if debug_log:
		print("DialogZone '%s': forcing dialog." % name)

	triggered.emit()
	dm.start_dialog(d, _resolve_name(), _resolve_portrait())

	# one-shot listener, so we don't stack connections on repeat zones
	if not dm.dialog_finished.is_connected(_on_dialog_finished):
		dm.dialog_finished.connect(_on_dialog_finished, CONNECT_ONE_SHOT)

	if once_only:
		set_deferred("monitoring", false)


func _on_dialog_finished() -> void:
	if freeze_player:
		_set_player_frozen(false)
	var flags := get_node_or_null("/root/Flags")
	if flags and finished_flag != "":
		flags.set_flag(finished_flag)
	dialog_ended.emit()


## Fire it from code, ignoring the collision entirely.
func trigger_now() -> void:
	_fire()


## Let a once_only zone fire again (testing, or a new life/loop).
func rearm() -> void:
	_fired = false
	_cool = 0.0
	var flags := get_node_or_null("/root/Flags")
	if flags and flags.has_method("clear_flag"):
		flags.clear_flag(_auto_flag)
	_refresh_armed()


# --- working out what to say -----------------------------------------------

func _npc() -> Node:
	if speaker.is_empty():
		return null
	return get_node_or_null(speaker)


func _resolve_dialog() -> Dialog:
	var n := _npc()
	if n:
		# an NPC node, or its NPCResource, may hold the dialog
		for prop in ["dialog", "npc_dialog"]:
			var v = n.get(prop)
			if v is Dialog:
				return v
		var res = n.get("npc_resource")
		if res:
			var v2 = res.get("dialog")
			if v2 is Dialog:
				return v2
	return dialog


func _resolve_name() -> String:
	if speaker_name != "":
		return speaker_name
	var n := _npc()
	if n:
		for prop in ["display_name", "npc_name"]:
			var v = n.get(prop)
			if v is String and v != "":
				return v
		var res = n.get("npc_resource")
		if res:
			for prop2 in ["display_name", "npc_name"]:
				var v2 = res.get(prop2)
				if v2 is String and v2 != "":
					return v2
	return ""


func _resolve_portrait() -> Texture2D:
	if portrait:
		return portrait
	var n := _npc()
	if n:
		var v = n.get("portrait")
		if v is Texture2D:
			return v
		var res = n.get("npc_resource")
		if res:
			var v2 = res.get("portrait")
			if v2 is Texture2D:
				return v2
	return null


# --- the player ------------------------------------------------------------

func _is_player(body: Node2D) -> bool:
	if body == null:
		return false
	if player_group != "" and body.is_in_group(player_group):
		return true
	return body is Player


## Tries the usual "stop moving" property names. Silent if he has none —
## the dialog box already eats input in most setups.
func _set_player_frozen(on: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	for prop in ["frozen", "is_frozen", "dialog_lock", "input_locked"]:
		if prop in _player:
			_player.set(prop, on)
			return
	for prop2 in ["can_move", "movement_enabled", "active"]:
		if prop2 in _player:
			_player.set(prop2, not on)
			return
