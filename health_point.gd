class_name Health_Point
extends Node

signal health_changed(new_health: int)
signal died()

@export var max_health: int = 5

# The ": set = _set_health" part means ANY time you change this variable,
# Godot will automatically run the _set_health function below.
var current_health: int = max_health : set = _set_health

func _ready() -> void:
	current_health = max_health
	# Optional: Tell the UI our starting health when the game loads
	health_changed.emit(current_health)

# This function intercepts any changes to current_health automatically
func _set_health(value: int) -> void:
	# Keep health between 0 and max_health (prevents going into negatives)
	current_health = clampi(value, 0, max_health)
	
	# Tell the UI to update
	health_changed.emit(current_health)
	
	# Check for death
	if current_health == 0:
		died.emit()
