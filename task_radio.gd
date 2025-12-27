extends Area2D

signal task_completed

@export var required_amplitude := 100.0
@export var required_wavelength := 150.0

var finished := false

func _ready():
	print("Task Ready - Required:", required_amplitude, required_wavelength)

func _on_body_entered(body):
	if body is CharacterBody2D:
		print("Player entered task area")
		open_radio()

func _on_body_exited(body):
	if body is CharacterBody2D:
		print(" Player exited task area")
		close_radio()

func open_radio():
	if finished:
		return

	WaveCanvas20.current_task = self
	print("Task set as current task")

func close_radio():
	print("Task close_radio() CALLED")

	if finished:
		return

	if check_task_success():
		finished = true
		print("TASK SUCCESS ✔️")
		emit_signal("task_completed")
	else:
		print("Task FAILED ❌")

func check_task_success() -> bool:
	var amp_ok = int(WaveCanvas20.amplitude) == int(required_amplitude)
	var wl_ok  = int(WaveCanvas20.wavelength) == int(required_wavelength)

	print("Check → Amp OK:", amp_ok, "| WL OK:", wl_ok)
	return amp_ok and wl_ok
