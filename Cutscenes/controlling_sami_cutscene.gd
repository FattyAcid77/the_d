extends Node
## Controlling SamiCutscene — one place to drive the player during cutscenes.
##
## Nothing your teammate wrote is touched, and nothing of yours is rewritten.
## This only CALLS what Sami and the state machine already expose:
##
##     player.disable() / enable()          your own methods
##     player.state_machine.process_mode    the switch Initialize() already flips
##     player.face_toward(dir)              your own method
##     player.UpdateAnimation("Idle")       your own method
##
## Deliberately has NO class_name, so it adds nothing to the project's global
## namespace and can never collide with a class your teammate adds later.
##
## USE IT EITHER WAY:
##   - Autoload it (Project Settings -> Autoload) so auto-freeze always works
##   - or drop the scene into one level, where it only works in that level
##
## FROM ANYWHERE:
##     var sami := get_node("/root/ControllingSamiCutscene")
##     sami.freeze()
##     sami.place_at($SpawnMarker)
##     sami.face(Vector2.LEFT)
##     sami.play_anim("Idle")
##     sami.unfreeze()

signal froze
signal unfroze

## Freeze Sami while SceneManager is fading, so he cannot walk around behind
## the curtain, then hand control back once the new scene is revealed.
@export var auto_freeze_on_transition: bool = true

## Prints what it does. Turn on when a freeze does not seem to take.
@export var debug: bool = false

var _player: Node = null
var _frozen: bool = false
var _sm_mode_before: int = Node.PROCESS_MODE_INHERIT
var _was_transitioning: bool = false


## The live player, re-found automatically after every scene change.
## Returns null in a scene with no player, and callers cope with that.
var player: Node:
	get:
		if _player == null or not is_instance_valid(_player):
			_player = null
			if is_inside_tree():
				_player = get_tree().get_first_node_in_group("Player")
		return _player


func _ready() -> void:
	# Must keep ticking while a cutscene has the tree paused, or the unfreeze
	# at the end of a transition would never fire.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if not auto_freeze_on_transition:
		return
	var sm := get_node_or_null("/root/SceneManager")
	if sm == null or not ("is_transitioning" in sm):
		return

	# Edge-triggered: only act when the transition starts or ends, so this
	# never fights a freeze somebody else set for their own reasons.
	var now: bool = sm.is_transitioning
	if now and not _was_transitioning:
		_log("scene transition started -> freezing")
		freeze()
	elif not now and _was_transitioning:
		_log("scene transition finished -> unfreezing")
		unfreeze()
	_was_transitioning = now


#region /// freeze

func is_frozen() -> bool:
	return _frozen


## Stops Sami dead: input off, state machine off, velocity zeroed.
##
## The state machine is switched off rather than deleted or replaced, using the
## same process_mode switch Sami_statemachine already uses — Initialize() turns
## it on, this turns it back off. No new state class, no edits to your scene.
func freeze() -> void:
	if _frozen:
		return
	var p: Node = player
	if p == null:
		_log("freeze: no player in the 'Player' group")
		return
	_frozen = true

	if p.has_method("disable"):
		p.disable()
	elif "input_enabled" in p:
		p.input_enabled = false

	var sm: Node = _state_machine(p)
	if sm != null:
		_sm_mode_before = sm.process_mode
		sm.process_mode = Node.PROCESS_MODE_DISABLED

	# _physics_process still calls move_and_slide() every frame, so without
	# this he keeps coasting on whatever velocity he had.
	if p is CharacterBody2D:
		p.velocity = Vector2.ZERO

	_log("frozen")
	froze.emit()


func unfreeze() -> void:
	if not _frozen:
		return
	_frozen = false
	var p: Node = player
	if p == null:
		return

	var sm: Node = _state_machine(p)
	if sm != null:
		sm.process_mode = _sm_mode_before

	if p.has_method("enable"):
		p.enable()
	elif "input_enabled" in p:
		p.input_enabled = true

	_log("unfrozen")
	unfroze.emit()

#endregion


#region /// posing

## Teleports Sami. Give it a node (a Marker2D, a door, anything Node2D) or a
## plain Vector2 world position.
func place_at(where: Variant) -> void:
	var p: Node = player
	if p == null:
		return
	var pos: Vector2
	if where is Node2D:
		pos = (where as Node2D).global_position
	elif where is Vector2:
		pos = where
	else:
		push_warning("place_at expects a Node2D or a Vector2, got %s" % typeof(where))
		return
	p.global_position = pos
	if p is CharacterBody2D:
		p.velocity = Vector2.ZERO
	_log("placed at %s" % str(pos))


## Turns Sami to face a DIRECTION — Vector2.LEFT, RIGHT, UP, DOWN.
## Not a position: face_toward() reads the vector's sign, not its length.
func face(dir: Vector2) -> void:
	var p: Node = player
	if p == null or dir == Vector2.ZERO:
		return
	if p.has_method("face_toward"):
		p.face_toward(dir)
		if p.has_method("UpdateAnimation"):
			p.UpdateAnimation("Idle")   # redraw facing the new way
		_log("facing %s" % str(dir))


## Plays one of Sami's animation states, e.g. "Idle" or "Walk". The direction
## suffix is added by his own UpdateAnimation().
func play_anim(anim_state: String) -> void:
	var p: Node = player
	if p == null:
		return
	if p.has_method("UpdateAnimation"):
		p.UpdateAnimation(anim_state)
		_log("anim '%s'" % anim_state)

#endregion


#region /// helpers

func _state_machine(p: Node) -> Node:
	if p == null:
		return null
	if "state_machine" in p and p.state_machine != null:
		return p.state_machine
	return p.get_node_or_null("Statemachine")


func _log(msg: String) -> void:
	if debug:
		print("[SamiCutscene] %s" % msg)

#endregion
