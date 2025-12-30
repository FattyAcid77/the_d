extends Area2D

#
# SIGNAL — the task will shout this message 
# “open_radio(required_amp, required_wavelength)”
#
signal open_radio(required_amp, required_wavelength)


#
# EXPORTED SETTINGS — fully inspector editable
#

@export var required_amplitude: float = 100.0
@export var required_wavelength: float = 150.0

# Optional: Set task name (shows in debug)
@export var task_name: String = "Default Task"


#
# DETECTION — When Player enters the task area
#
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("player Entered")
		emit_signal("open_radio", required_amplitude, required_wavelength)
