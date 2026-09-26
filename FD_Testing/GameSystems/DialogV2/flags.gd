extends Node
## Flags. A dictionary of named booleans that every system reads and writes.
## Dialog branches, zones, map discovery and checkpoints all run on it.

signal flag_changed(flag_name: String, value: Variant)

var _flags: Dictionary = {}


func _ready() -> void:
	# The F11 debug panel, debug builds only. Last child of the root, so it
	# hears F11 / Esc / TAB before the Board does.
	if OS.is_debug_build():
		get_tree().root.add_child.call_deferred(DebugPanel.new())


## Set a flag to any value (bool / int / String).
func set_flag(flag_name: String, value: Variant = true) -> void:
	_flags[flag_name] = value
	flag_changed.emit(flag_name, value)


## Read a flag's raw value.
func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return _flags.get(flag_name, default)


## True only if the flag exists and is "truthy" (true, non-zero, non-empty).
func is_set(flag_name: String) -> bool:
	if not _flags.has(flag_name):
		return false
	return bool(_flags[flag_name])


## Add to a numeric flag.
func add_flag(flag_name: String, amount: int = 1) -> void:
	var current: int = int(_flags.get(flag_name, 0))
	set_flag(flag_name, current + amount)


## Remove a single flag.
func clear_flag(flag_name: String) -> void:
	if _flags.has(flag_name):
		_flags.erase(flag_name)
		flag_changed.emit(flag_name, null)


## Wipe everything - for "New Game" or testing.
func clear_all() -> void:
	_flags.clear()


# --- Save / load helpers, so flags survive between play sessions ---

func to_dict() -> Dictionary:
	return _flags.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_flags = data.duplicate(true)
