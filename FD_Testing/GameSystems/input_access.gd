class_name InputAccess
## Small helper so every system asks for input the same safe way.
##
## THE PROBLEM IT SOLVES
## Godot's Input.is_action_just_pressed("interact") throws a hard error
##     The InputMap action "interact" doesn't exist.
## EVERY FRAME if that action isn't in your Input Map. Eleven scripts in this
## package poll "interact" inside _process, so a single missing action buries
## the Errors panel under thousands of identical lines and hides the real
## problems underneath.
##
## This checks the action exists first, falls back to a sensible alternative,
## and warns ONCE instead of erroring forever.
##
## SETUP (do this once)
## Project > Project Settings > Input Map, add an action named "interact"
## and bind it to E (and/or Space, controller A). Until you do, the package
## quietly falls back to "ui_accept" (Enter/Space), which Godot always has,
## so everything still works while you get set up.

## The action every system uses for "talk / pick up / press the thing".
const INTERACT := "interact"

## Used automatically when the action above isn't in the Input Map yet.
## "ui_accept" is built into Godot, so this always resolves to something.
const FALLBACK := "ui_accept"

## Remembers which names we've already complained about, so the warning
## appears once per run rather than once per frame.
static var _warned := {}


## The action name to actually use — the real one if it exists, else the
## fallback. Warns once if it had to substitute.
static func resolve(action: String = INTERACT) -> String:
	if InputMap.has_action(action):
		return action
	if not _warned.has(action):
		_warned[action] = true
		push_warning(("InputAccess: no '%s' action in the Input Map — using '%s' "
				+ "instead. Add '%s' in Project Settings > Input Map.")
				% [action, FALLBACK, action])
	if InputMap.has_action(FALLBACK):
		return FALLBACK
	return ""


## Safe replacement for Input.is_action_just_pressed().
static func just_pressed(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_just_pressed(a)


## Safe replacement for Input.is_action_pressed().
static func pressed(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_pressed(a)


## Safe replacement for Input.is_action_just_released().
static func just_released(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_just_released(a)


## Safe replacement for event.is_action_pressed(). Returns false rather than
## erroring when the action is missing.
static func event_pressed(event: InputEvent, action: String) -> bool:
	if event == null or not InputMap.has_action(action):
		return false
	return event.is_action_pressed(action)
