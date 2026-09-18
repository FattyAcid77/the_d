class_name InputAccess
## Small helper so every system asks for input the same safe way. the problem
## it solves Godot's Input.is_action_just_pressed("interact") throws a hard
## error The InputMap action "interact" doesn't exist.

const INTERACT := "interact"

## Used automatically when the action above isn't in the Input Map yet.
const FALLBACK := "ui_accept"

# Remembers which names we've already complained about
static var _warned := {}


## The action name to actually use - the real one if it exists, else the fallback.
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


## Safe replacement for event.is_action_pressed().
static func event_pressed(event: InputEvent, action: String) -> bool:
	if event == null or not InputMap.has_action(action):
		return false
	return event.is_action_pressed(action)
