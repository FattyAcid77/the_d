extends CharacterBody2D

@onready var ani: AnimatedSprite2D = $Sprite2D
const SPEED = 300.0



func _process(delta):
	# ... (Keep your existing movement code here) ...
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
		ani.play("Right")
		ani.flip_h = false
	elif Input.is_action_pressed("ui_left"):
		velocity.x -= 1
		ani.play("Left")
		ani.flip_h = true
	elif Input.is_action_pressed("ui_down"):
		velocity.y += 1
		ani.play("down")
	elif Input.is_action_pressed("ui_up"):
		velocity.y -= 1
		ani.play("Up")
	else:
		ani.stop()

	if velocity.length() > 0:
		velocity = velocity.normalized() * SPEED
		position += velocity * delta

	# 🔹 INTERACT WITH TASK
	# Only check this ONCE
	if Input.is_action_just_pressed("ui_accept"):
		print("Player pressed Interact")
		
		if WaveCanvas20.current_task != null:
			print("✅ Attempting to complete task...")
			# This triggers the check in the Task script
			# If successful, the Task script emits 'task_completed'
			# The TaskSystem catches that signal and prints the reward
			WaveCanvas20.current_task.close_radio()
		else:
			print("❌ No active task to interact with")
