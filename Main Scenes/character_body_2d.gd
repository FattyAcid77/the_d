extends CharacterBody2D

@onready var ani: AnimatedSprite2D = $Sprite2D
const speed = 300.0
var push_force = 80
var input_direction: Vector2 = Vector2.ZERO

func _process(_delta):
	pass

func _physics_process(delta: float) -> void:
		
		
		if Input.is_action_pressed("right"):
			#velocity.x += 1
			ani.play("Right")
			ani.flip_h = false
		elif Input.is_action_pressed("left"):
			#velocity.x -= 1
			ani.play("Left")
			ani.flip_h = true
		elif Input.is_action_pressed("down"):
			#velocity.y += 1
			ani.play("down")
		elif Input.is_action_pressed("up"):
			#velocity.y -= 1
			ani.play("Up")
		else:
			ani.stop()
		
		input_direction = Input.get_vector("left", "right", "up", "down")
		velocity = input_direction.normalized() * speed
		#if velocity.length() > 0:
			#velocity = velocity.normalized() * speed
			#velocity = input_direction.normalized() * speed
			#position += velocity * delta
		#velocity = input_direction.normalized() * speed
		
		move_and_slide()
		
		for i in get_slide_collision_count():
			var c = get_slide_collision(i)
			if c.get_collider() is RigidBody2D:
				c.get_collider().apply_central_impulse(-c.get_normal() * push_force)
	
	
