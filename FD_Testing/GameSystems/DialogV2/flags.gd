extends Node
## Flags — the game's memory. Add as an Autoload named "Flags".
##
## A "flag" is one remembered fact about the world. Anything can set one
## (an NPC, an item pickup, a cutscene) and any dialog line can react to it:
##
##     Flags.set_flag("apple_eaten")        # now it's true
##     Flags.add_flag("talked_to_java")     # counter: 1, 2, 3...
##     if Flags.is_set("apple_eaten"):      # ask in dialog
##         ...
##
## This is what lets the world feel like it remembers what happened.

signal flag_changed(flag_name: String, value: Variant)

var _flags: Dictionary = {}


## Set a flag to any value (bool / int / String). Defaults to true.
func set_flag(flag_name: String, value: Variant = true) -> void:
	_flags[flag_name] = value
	flag_changed.emit(flag_name, value)


## Read a flag's raw value. Returns `default` if it was never set.
func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return _flags.get(flag_name, default)


## True only if the flag exists AND is "truthy" (true, non-zero, non-empty).
## This is the one you'll use most in dialog conditions.
func is_set(flag_name: String) -> bool:
	if not _flags.has(flag_name):
		return false
	return bool(_flags[flag_name])


## Add to a numeric flag. Great for counters ("times_talked", "coins").
func add_flag(flag_name: String, amount: int = 1) -> void:
	var current: int = int(_flags.get(flag_name, 0))
	set_flag(flag_name, current + amount)


## Remove a single flag.
func clear_flag(flag_name: String) -> void:
	if _flags.has(flag_name):
		_flags.erase(flag_name)
		flag_changed.emit(flag_name, null)


## Wipe everything — for "New Game" or testing.
func clear_all() -> void:
	_flags.clear()


## --- Save / load helpers, so flags survive between play sessions ---

func to_dict() -> Dictionary:
	return _flags.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_flags = data.duplicate(true)
