@tool
class_name RadioMaker_v1Signal
extends QuestSignal
## One radio signal, standing where its puzzle is.
##
## YOU DO NOT PLACE THIS BY HAND. Open the "Radio" dock at the bottom of the
## editor, pick a signal, and press "Place in scene" — it drops one of these in
## already pointed at that signal. Then drag it to where the puzzle is. The
## circle you see IS the area the player has to be inside to hear it.
##
## Frequency, kind, reach and what happens when the player tunes in are NOT set
## here. They live in `radio_puzzle.tres`, which the dock writes.
##
## This extends QuestSignal, so `radio_signal_manager.gd` picks it up exactly
## like any other beacon and needed no changes at all.

## What happens the moment the player tunes in. Chosen in the Maker.
enum Reward { SHOW_NODE, HIDE_NODE, SOLVE_PUZZLE, SET_FLAG }

const PUZZLE_PATH: String = "res://3MK-File/RadioMaker/radio_puzzle.tres"

const MAIN_TINT: Color = Color("ffd24a")
const SIDE_TINT: Color = Color("4aa3ff")
const BAD_TINT: Color = Color("ff5a5a")

## Fires once, the moment the player tunes in. Connect it for extra juice —
## a sound, a camera shake — without touching this script.
signal caught

## The inherited fields this node fills in for itself. Hidden from the
## Inspector so the only thing on show is the dropdown.
const PULLED: PackedStringArray = [
	"quest_type", "puzzle_id", "frequency", "signal_radius", "order",
]

## Which signal from the Maker this node is.
@export var signal_id: String = "":
	set(value):
		signal_id = value
		_pull()

var _puzzle: RadioMaker_v1Puzzle = null
var _fired: bool = false
## Seconds until the puzzle file is re-read, so the circle keeps up while the
## Maker is open in another window. Editor only.
var _poll: float = 0.0


func _ready() -> void:
	super._ready()
	_pull()
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	var game_state: Node = _autoload("GameState")
	if puzzle_id != "" and game_state != null and game_state.is_solved(puzzle_id):
		_fired = true
		return
	if quest_type != Type.SIDE:
		return
	var manager: Node = _autoload("RadioSignals")
	if manager == null:
		return
	# A signal caught before a scene reload stays caught, same as the mirrors.
	if manager.is_caught(frequency):
		_fire()
	else:
		manager.side_signal_caught.connect(_on_side_caught)


## Autoloads do not exist while the editor is running a @tool script, so they
## are looked up by path instead of by name — the same guard FD's
## `radio_link.gd` uses. Returns null when the singleton is not there.
func _autoload(id: String) -> Node:
	return get_node_or_null(NodePath("/root/" + id))


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	_puzzle = null   # the Maker may have just saved over it
	_pull()


#region /// reading the Maker's file

func _entry() -> Dictionary:
	if _puzzle == null:
		if not ResourceLoader.exists(PUZZLE_PATH):
			return {}
		# Ignore the cache in the editor, otherwise a save from the Maker is
		# invisible until Godot is restarted.
		var mode := (ResourceLoader.CACHE_MODE_IGNORE if Engine.is_editor_hint()
			else ResourceLoader.CACHE_MODE_REUSE)
		_puzzle = ResourceLoader.load(PUZZLE_PATH, "", mode) as RadioMaker_v1Puzzle
	if _puzzle == null:
		return {}
	return _puzzle.find(signal_id)


## Copy the Maker's numbers onto the inherited QuestSignal fields, which is all
## `radio_signal_manager.gd` ever reads.
func _pull() -> void:
	var e: Dictionary = _entry()
	if not e.is_empty():
		quest_type = Type.MAIN if int(e.get("type", 1)) == 0 else Type.SIDE
		frequency = int(e.get("frequency", 630))
		signal_radius = float(e.get("radius", 400.0))
		order = int(e.get("order", 0))
		puzzle_id = str(e.get("puzzle_id", ""))
	update_configuration_warnings()
	queue_redraw()


func _ids() -> PackedStringArray:
	if _puzzle == null:
		_entry()
	return _puzzle.ids() if _puzzle != null else PackedStringArray()

#endregion


#region /// the Inspector, kept to one line

func _validate_property(property: Dictionary) -> void:
	if property.name in PULLED:
		# Still saved, just never shown — the Maker owns these.
		property.usage = PROPERTY_USAGE_NO_EDITOR
		return
	if property.name == "signal_id":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(_ids())


func _get_configuration_warnings() -> PackedStringArray:
	if signal_id == "":
		return ["Pick a signal. To make one, use the \"Radio\" dock at the bottom of the editor."]
	if _entry().is_empty():
		return ["There is no signal called \"%s\" in the Radio dock." % signal_id]
	return PackedStringArray()

#endregion


#region /// the circle you place it by

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var e: Dictionary = _entry()
	if e.is_empty():
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, BAD_TINT, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-30.0, -30.0),
			"no signal picked", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, BAD_TINT)
		return
	var tint: Color = MAIN_TINT if quest_type == Type.MAIN else SIDE_TINT
	draw_circle(Vector2.ZERO, signal_radius, Color(tint, 0.07))
	draw_arc(Vector2.ZERO, signal_radius, 0.0, TAU, 64, tint, 2.0)
	var label: String = ("%s   MAIN" % signal_id if quest_type == Type.MAIN
		else "%s   %d Hz" % [signal_id, frequency])
	draw_string(ThemeDB.fallback_font, Vector2(-36.0, -12.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)

#endregion


#region /// what happens when it is caught

func _on_side_caught(freq: int) -> void:
	if freq == frequency:
		_fire()


func _fire() -> void:
	if _fired:
		return
	_fired = true
	_apply_reward()
	caught.emit()


func _apply_reward() -> void:
	var e: Dictionary = _entry()
	var kind: int = int(e.get("reward", Reward.SHOW_NODE))
	var value: String = str(e.get("reward_value", ""))
	if value == "":
		return
	match kind:
		Reward.SHOW_NODE, Reward.HIDE_NODE:
			var node: Node = get_node_or_null(NodePath(value))
			if node == null:
				push_warning("Radio signal \"%s\": nothing at \"%s\"." % [signal_id, value])
				return
			if "visible" in node:
				node.visible = kind == Reward.SHOW_NODE
		Reward.SOLVE_PUZZLE:
			var game_state: Node = _autoload("GameState")
			if game_state != null:
				game_state.solve_puzzle(value)
		Reward.SET_FLAG:
			var flags: Node = _autoload("Flags")
			if flags != null:
				flags.set_flag(value)

#endregion
