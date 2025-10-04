class_name TransitionScreen extends CanvasLayer
#this code only to control the transition queues


#custom signal to deal with the completion of the scene
signal transition_in_complete

# to load the two elements(animation player , timer) that will be controlled 
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var timer: Timer = $Timer

# there are two animations that should be played in order to for a complete transition to happen( fade in , fade out
#this one plays the first part (fade_to_black)
func start_transition():
	
	animation_player.play("fade_to_black")
	
	timer.start()

#this one plays the second part (fade from black) 
func finish_transition():
	if timer:
		timer.stop()
	animation_player.play("fade_from_black")
	
	await animation_player.animation_finished
	queue_free()
	
func report_midpoint() -> void:
	transition_in_complete.emit()
	


func _on_timer_timeout() -> void:
	pass # Replace with function body.
