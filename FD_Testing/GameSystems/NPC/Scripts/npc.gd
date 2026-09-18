@tool
class_name NPC extends CharacterBody2D
## A character in the world. Its identity (name, art, dialog) comes from an
## NPCResource; its movement comes from one behavior child node (Wander,
## Patrol, or none for a standing NPC).

@export var npc_resource: NPCResource:
	set(value):
		if npc_resource and npc_resource.changed.is_connected(_apply_resource):
			npc_resource.changed.disconnect(_apply_resource)
		npc_resource = value
		if npc_resource and not npc_resource.changed.is_connected(_apply_resource):
			npc_resource.changed.connect(_apply_resource)
		_apply_resource()

## Which animation to preview in the editor / stand in at start.
@export var idle_animation: String = "Idle_down"

@export_group("Animation")
## Overrides the resource's `resting_animation` for this one NPC in this one room.
@export var resting_animation_override: String = ""

## Overrides the resource's `use_direction_animations`.
@export_enum("Use the resource", "Force ON", "Force OFF")
var direction_animations_override: int = 0

## Print what the animation system is doing.
@export var debug_animation: bool = false

var direction: Vector2 = Vector2.ZERO  # set by the behavior each frame
var cardinal_direction: Vector2 = Vector2.DOWN
var _behavior: NPCBehavior = null


## A foot touched the floor.
signal footstep(resource: NPCResource)


func _ready() -> void:
	_apply_resource()
	if Engine.is_editor_hint():
		return  # no game logic inside the editor
	SoundLink.attach(self)  # every signal here becomes a SoundMap moment
	var spr := sprite()
	if spr:
		spr.frame_changed.connect(_on_frame_changed)
	for child in get_children():
		if child is NPCBehavior:
			_behavior = child
			_behavior.setup(self)
			break
	_update_animation()


## Pushes the resource's art onto the sprite.
func _apply_resource() -> void:
	var a := get_node_or_null("Sprite2D") as AnimatedSprite2D
	if a == null:
		return
	if npc_resource == null or npc_resource.sprite_frames == null:
		return
	a.sprite_frames = npc_resource.sprite_frames
	if a.sprite_frames.has_animation(idle_animation):
		a.animation = idle_animation
		a.frame = 0
		if not Engine.is_editor_hint():
			a.play(idle_animation)


## Only frames listed in the resource, only while actually moving
func _on_frame_changed() -> void:
	if npc_resource == null or velocity.length_squared() < 1.0:
		return
	var spr := sprite()
	if spr == null or not npc_resource.footstep_frames.has(spr.frame):
		return
	footstep.emit(npc_resource)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _behavior:
		_behavior.tick(delta)
	var speed: float = npc_resource.move_speed if npc_resource else 60.0
	velocity = direction * speed
	move_and_slide()
	_set_cardinal()
	_update_animation()


## Face a world position
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


var _override_anim: String = ""
var _override_hold: bool = false


func sprite() -> AnimatedSprite2D:
	return get_node_or_null("Sprite2D") as AnimatedSprite2D


## Does this NPC use the Idle_<dir> / Walk_<dir> state machine at all?
func uses_direction_animations() -> bool:
	if direction_animations_override == 1:
		return true
	if direction_animations_override == 2:
		return false
	if npc_resource:
		return npc_resource.use_direction_animations
	return true


## The animation this NPC plays when nothing else is happening.
func resting_animation() -> String:
	if resting_animation_override != "":
		return resting_animation_override
	if npc_resource and npc_resource.resting_animation != "":
		return npc_resource.resting_animation
	return ""


## Finds the real animation name for `base`, trying the direction-aware form first
func resolve_animation(base: String) -> String:
	var a := sprite()
	if a == null or a.sprite_frames == null or base == "":
		return ""
	var with_dir := base + "_" + _direction_suffix()
	if a.sprite_frames.has_animation(with_dir):
		return with_dir
	if a.sprite_frames.has_animation(base):
		return base
	push_warning("NPC '%s': no animation called '%s' or '%s'."
			% [name, with_dir, base])
	return ""


## Plays an animation and suspends the direction state machine.
func play_override(base: String, hold: bool = false) -> void:
	var a := sprite()
	if a == null:
		return
	var real := resolve_animation(base)
	if real == "":
		return

	_override_anim = real
	_override_hold = hold
	a.play(real)

	if debug_animation:
		print("NPC '%s': override '%s' (hold=%s)" % [name, real, hold])

	if not hold:
		# one-shot: hand control back when it finishes
		if not a.animation_finished.is_connected(_on_override_finished):
			a.animation_finished.connect(_on_override_finished, CONNECT_ONE_SHOT)


func _on_override_finished() -> void:
	clear_override()


## Back to normal - the state machine or the resting animation takes over.
func clear_override() -> void:
	if _override_anim == "":
		return
	_override_anim = ""
	_override_hold = false
	if debug_animation:
		print("NPC '%s': override cleared" % name)
	_update_animation(true)


func has_override() -> bool:
	return _override_anim != ""


func _direction_suffix() -> String:
	if cardinal_direction == Vector2.UP:
		return "up"
	if cardinal_direction == Vector2.LEFT or cardinal_direction == Vector2.RIGHT:
		return "Side"
	return "down"


## Alias for face_toward(), which already existed.
func face_position(world: Vector2) -> void:
	face_toward(world)


func _update_animation(force: bool = false) -> void:
	# an override owns the sprite until it is cleared
	if _override_anim != "" and not force:
		return

	var anim := sprite()
	if anim == null or anim.sprite_frames == null:
		return

	# still NPCs: no Idle_down/Walk_Side at all, just the resting loop.
	if not uses_direction_animations():
		var rest := resting_animation()
		if rest == "":
			rest = idle_animation
		if anim.sprite_frames.has_animation(rest) and anim.animation != rest:
			anim.play(rest)
		return

	# standing still with a resting animation of its own - smoking, polishing.
	if direction == Vector2.ZERO:
		var r := resting_animation()
		if r != "":
			var real := resolve_animation(r)
			if real != "" and anim.animation != real:
				anim.play(real)
			if real != "":
				return

	var state := "Walk" if direction != Vector2.ZERO else "Idle"
	var suffix := _direction_suffix()
	anim.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	var anim_name := state + "_" + suffix
	if anim.animation == anim_name:
		return
	if anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
