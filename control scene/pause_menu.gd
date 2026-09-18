extends CanvasLayer

@onready var Settings_Menu: CanvasLayer = $SettingsMenu

func _process(_delta: float) -> void:
	# this layer is PROCESS_MODE_ALWAYS, so without the guard the player can
	# pause/unpause the tree out from under a scene transition mid-load
	if SceneManager.is_transitioning:
		return
	if Input.is_action_just_pressed("Option"):
		toggle_pause()

func _ready() -> void:
	visible = false
	


func toggle_pause() -> void:
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if not is_paused:
		Settings_Menu.visible = false


func _on_button_pressed() -> void:
	get_tree().paused = !get_tree().paused
	visible = get_tree().paused
	
	


func _on_button_3_pressed() -> void:
	get_tree().quit()


func _on_button_2_pressed() -> void:
	visible = false
	Settings_Menu.visible = true
