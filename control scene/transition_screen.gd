extends CanvasLayer

@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var timer: Timer = $Timer

func start_transition():
	
	animation_player.play("fade_to_black")
	
	timer.start()
	
func finish_transition():
	animation_player.play("fade_from_black")
	
	await animation_player.animation_finished
	queue_free()
	


func _on_timer_timeout() -> void:
	pass # Replace with function body.
