class_name HealthData
extends Resource

signal health_changed(current_health: int)
signal max_health_changed(max_health: int)
signal died()

@export var max_health: int = 3 : set = _set_max_health
@export var current_health: int = 3 : set = _set_health

func _set_max_health(value: int) -> void:
	max_health = max(1, value) # Prevents max health from going below 1
	max_health_changed.emit(max_health)
	
	# If max health drops below current health, adjust current health
	self.current_health = min(current_health, max_health)

func _set_health(value: int) -> void:
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health)
	
	if current_health == 0:
		died.emit()
