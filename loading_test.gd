extends Node

const LOADING_SCREEN := preload("res://loading_screen.tscn")

@export var fake_duration: float = 3.0

func _ready() -> void:
	var screen := LOADING_SCREEN.instantiate()
	add_child(screen)

	await screen.loading_screen_ready

	var elapsed := 0.0
	while elapsed < fake_duration:
		elapsed += get_process_delta_time()
		screen._on_progress_changed(clampf(elapsed / fake_duration, 0.0, 1.0))
		await get_tree().process_frame

	screen._on_progress_changed(1.0)
	await get_tree().create_timer(0.3).timeout
	screen._on_load_finished()
