class_name Player extends CharacterBody2D
# 3-point health, shared live with Health_UI through this same resource.
@export var stats: HealthData

@onready var anim: AnimatedSprite2D = $Sprite2D
@onready var state_machine: Sami_statemachine = $Statemachine
# inventory panel, toggled with I. lives under UI.
@onready var inventory: CanvasLayer = get_node_or_null("UI/Inventory UI")

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var move_speed : float = 100.0

# push / pull
var focus_grabbable: Node = null          # object whose zone we're standing in
var grabbed: Node = null                  # object we're holding
var grab_offset: Vector2 = Vector2.ZERO   # player->object, locked when we grab

# Called when the node enters the scene tree for the first time.
func _ready():
	# Hand ourselves to the state machine so every state can control us.
	state_machine.Initialize(self)
	if inventory != null:
		_set_inventory(false)   # start hidden


# Every frame we ONLY read the input into 'direction'.
# The states decide what to do with it (move, animate, switch).
func _process( delta ):
	direction.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	direction.y = Input.get_action_strength("down") - Input.get_action_strength("up")

	# I toggles the inventory panel. Doesn't pause, so you can test movement with it open.
	if inventory != null and Input.is_action_just_pressed("I"):
		_set_inventory(not inventory.visible)


func _physics_process( delta ):
	move_and_slide()


# Turns the raw input into a facing (down/up/left/right) and flips the sprite.
# Returns true only when the facing actually changed.
func SetDirection() -> bool:
	var new_dir: Vector2 = cardinal_direction
	if direction == Vector2.ZERO:
		return false

	if direction.y == 0:
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN

	if new_dir == cardinal_direction:
		return false

	cardinal_direction = new_dir
	anim.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true


func UpdateAnimation( anim_state : String ) -> void:
	var anim_name: String = anim_state + "_" + AnimDirection()
	# Don't restart an animation that's already playing — calling play() every
	# frame snaps it back to frame 0 and makes it look frozen / slow.
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


# face the side an object is on (no movement input needed, so it holds while
# we push or pull)
func face_toward(vec: Vector2) -> void:
	if vec == Vector2.ZERO:
		return
	if abs(vec.x) >= abs(vec.y):
		cardinal_direction = Vector2.RIGHT if vec.x >= 0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if vec.y >= 0 else Vector2.UP
	anim.scale.x = 1   # push/pull have their own left/right frames, never flipped


# play a PS_ or PL_ frame for a direction
func update_drag_animation(prefix: String, dir: Vector2) -> void:
	anim.scale.x = 1
	var anim_name: String = prefix + "_" + _dir4(dir)
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func _dir4(vec: Vector2) -> String:
	if abs(vec.x) >= abs(vec.y):
		return "RIGHT" if vec.x >= 0 else "LEFT"
	return "DOWN" if vec.y >= 0 else "UP"


# Drag and Rotate both call this so the pose always matches.
# The pull art is named weirdly: up/down by where you move, left/right by where
# you face, so we just flip the y.
func play_push_pull_anim(pushing: bool) -> void:
	if pushing:
		update_drag_animation("PS", cardinal_direction)
	else:
		update_drag_animation("PL", Vector2(cardinal_direction.x, -cardinal_direction.y))


# grab the object we're next to. true if we got one.
func try_start_grab() -> bool:
	if focus_grabbable == null:
		return false
	grabbed = focus_grabbable
	grab_offset = grabbed.global_position - global_position   # lock which side it's on
	if grabbed.has_method("on_grabbed"):
		grabbed.on_grabbed(self)
	return true


func end_grab() -> void:
	if grabbed != null and grabbed.has_method("on_released"):
		grabbed.on_released(self)
	grabbed = null


# keep the held object pinned at the locked offset so it can't slip past us
func drag_follow() -> void:
	if grabbed == null:
		return
	grabbed.global_position = global_position + grab_offset
	if grabbed is CharacterBody2D:
		grabbed.velocity = Vector2.ZERO


# show/hide the inventory panel and stop it processing while hidden
func _set_inventory(on: bool) -> void:
	inventory.visible = on
	inventory.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
