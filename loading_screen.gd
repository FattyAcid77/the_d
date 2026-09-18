class_name LoadingScreen extends CanvasLayer

signal loading_screen_ready

@export var animation_player: AnimationPlayer
@export var progress_bar: TextureProgressBar

func _ready() -> void:
	animation_player.play("transition")
	await animation_player.animation_finished
	loading_screen_ready.emit()

# driven by SceneManager while the threaded load runs. 0.0 - 1.0
func set_progress(new_value: float) -> void:
	progress_bar.value = new_value

func hide_screen() -> void:
	animation_player.play_backwards("transition")
	await animation_player.animation_finished
	queue_free()

# old names, kept so loading_test.gd keeps working
func _on_progress_changed(new_value: float) -> void:
	set_progress(new_value)

func _on_load_finished() -> void:
	await hide_screen()
