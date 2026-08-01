class_name NPC extends CharacterBody2D
## A character in the world. Its identity (name, art, dialog) comes from an
## NPCResource; its movement comes from ONE behavior child node (Wander,
## Patrol, or none for a standing NPC).
##
## Scene shape:
##   NPC (this script)
##   ├── Sprite2D            (AnimatedSprite2D)
##   ├── CollisionShape2D
##   ├── DialogTrigger       (instance of DialogV2/dialog_trigger.tscn)
##   └── Wander / Patrol     (optional, exactly one)
##
## While a dialog is open the tree is paused, so NPCs stop automatically.

@export var npc_resource: NPCResource

@onready var anim: AnimatedSprite2D = $Sprite2D

var direction: Vector2 = Vector2.ZERO         ## set by the behavior each frame
var cardinal_direction: Vector2 = Vector2.DOWN
var _behavior: NPCBehavior = null


func _ready() -> void:
	if npc_resource and npc_resource.sprite_frames and anim:
		anim.sprite_frames = npc_resource.sprite_frames
	for child in get_children():
		if child is NPCBehavior:
			_behavior = child
			_behavior.setup(self)
			break
	_update_animation()


func _physics_process(delta: float) -> void:
	if _behavior:
		_behavior.tick(delta)
	var speed: float = npc_resource.move_speed if npc_resource else 60.0
	velocity = direction * speed
	move_and_slide()
	_set_cardinal()
	_update_animation()


## Face a world position (the DialogTrigger calls this so the NPC looks
## at the player when talked to).
func face_toward(world_pos: Vector2) -> void:
	var vec := world_pos - global_position
	if vec == Vector2.ZERO:
		return
	if absf(vec.x) >= absf(vec.y):
		cardinal_direction = Vector2.RIGHT if vec.x >= 0.0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if vec.y >= 0.0 else Vector2.UP
	direction = Vector2.ZERO
	_update_animation()


func _set_cardinal() -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) >= absf(direction.y):
		cardinal_direction = Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if direction.y >= 0.0 else Vector2.UP


func _update_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	var state := "Walk" if direction != Vector2.ZERO else "Idle"
	var suffix := "down"
	if cardinal_direction == Vector2.UP:
		suffix = "up"
	elif cardinal_direction == Vector2.LEFT or cardinal_direction == Vector2.RIGHT:
		suffix = "Side"
	anim.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	var anim_name := state + "_" + suffix
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
