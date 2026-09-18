class_name PlayerTest extends CharacterBody2D

#--------camera settings ----------
@export var camera_adj: bgrd_node
@onready var sami_camera = $Camera2D

## TEST-ONLY character for prototyping push / pull animations.
##
## This is completely separate from your real Player (sami_doctor.gd) and does
## NOT use the shared state machine, so nothing here can break your game.
##
## Controls:
##   move        = your normal arrow/WASD keys
##   grab        = hold F. While holding it and moving:
##                   move toward the way you face = PUSH  (PS_ animation)
##                   move away from the way you face = PULL (PL_ animation)

func _ready() -> void:
	camera_limit_set()

@onready var anim: AnimatedSprite2D = $Sprite2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var move_speed : float = 100.0
var drag_speed : float = 50.0
var _grabbing : bool = false


func _process( _delta ):
	# Read movement input every frame.
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# Hold F to grab / push / pull.
	var grab : bool = Input.is_physical_key_pressed(KEY_F)

	# The moment we start grabbing, lock our facing so push/pull don't spin around.
	if grab and not _grabbing:
		SetDirection()
	_grabbing = grab

	# Pick what we're doing this frame (these act like our "states").
	if grab:
		_drag()
	elif direction != Vector2.ZERO:
		_walk()
	else:
		_idle()


func _physics_process( _delta ):
	move_and_slide()


# ----- the three "states", kept as simple functions -----

func _idle() -> void:
	velocity = Vector2.ZERO
	UpdateAnimation("Idle")


func _walk() -> void:
	SetDirection()
	UpdateAnimation("Walk")
	velocity = direction * move_speed


func _drag() -> void:
	# How much of our movement points along the locked facing direction.
	var along : float = direction.dot(cardinal_direction)

	if along > 0.1:
		# Moving the way we face = pushing.
		UpdateDragAnimation("PS")
		velocity = cardinal_direction * drag_speed
	elif along < -0.1:
		# Moving the opposite way = pulling.
		UpdateDragAnimation("PL")
		velocity = -cardinal_direction * drag_speed
	else:
		# Holding the grab but not moving along the axis: stand still,
		# keep the current push/pull frame.
		velocity = Vector2.ZERO


# ----- animation helpers -----

# Walk/Idle facing: down / up / Side, with a sprite flip for left.
func SetDirection() -> void:
	if direction == Vector2.ZERO:
		return
	if direction.y == 0:
		cardinal_direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		cardinal_direction = Vector2.UP if direction.y < 0 else Vector2.DOWN
	anim.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1


func UpdateAnimation( anim_state : String ) -> void:
	var anim_name : String = anim_state + "_" + AnimDirection()
	if anim.animation == anim_name:
		return  # already playing it — don't restart (that's the "slow" bug)
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


# Push/pull uses separate LEFT/RIGHT frames (no flip), all caps.
func UpdateDragAnimation( anim_state : String ) -> void:
	anim.scale.x = 1
	var anim_name : String = anim_state + "_" + AnimDirection4()
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "Side"


func AnimDirection4() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "DOWN"
	elif cardinal_direction == Vector2.UP:
		return "UP"
	elif cardinal_direction == Vector2.LEFT:
		return "LEFT"
	else:
		return "RIGHT"

func camera_limit_set() -> void:
	sami_camera.limit_top = camera_adj.top_limit
	sami_camera.limit_right = camera_adj.right_limit
	sami_camera.limit_bottom = camera_adj.bot_limit
	sami_camera.limit_left = camera_adj.left_limit
