extends Node2D

func _process(_delta: float) -> void:
	var task = load("res://radio_7g_3_mk.tscn").instantiate()
	task.generate_task()

	var radio = load("res://radio_task_system.tscn").instantiate()
	radio.task_data = task

	add_child(task)
	add_child(radio)
