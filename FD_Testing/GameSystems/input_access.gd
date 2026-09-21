class_name InputAccess
## Input lookups that don't explode when an action is missing.
##
## Input.is_action_just_pressed("interact") errors every frame if "interact"
## isn't in the Input Map, which buries the debugger. These check first,
## fall back to ui_accept, and complain once.

const INTERACT := "interact"
const FALLBACK := "ui_accept"

static var _warned := {}


## The action to use: the real one if it's mapped, else the fallback.
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


static func just_pressed(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_just_pressed(a)


static func pressed(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_pressed(a)


static func just_released(action: String = INTERACT) -> bool:
	var a := resolve(action)
	return a != "" and Input.is_action_just_released(a)


## event.is_action_pressed without the missing-action error.
static func event_pressed(event: InputEvent, action: String) -> bool:
	if event == null or not InputMap.has_action(action):
		return false
	return event.is_action_pressed(action)
