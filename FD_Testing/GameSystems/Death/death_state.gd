class_name death_state extends state
## Sami's death state. Add a Node named "Death" under his Statemachine and
## attach this script — Deaths.kill() finds it by that name and switches to it.
##
## It plays the death animation (whatever exists of Death_down / Death_up /
## Death_Side / Death), freezes Sami, and never returns another state, so he
## stays down until Retry reloads the checkpoint.
##
## When your death art is ready, just add the animations to his SpriteFrames
## with those names — no code change needed.

## Base name of the death animations in the SpriteFrames.
@export var anim_prefix: String = "Death"


func Enter() -> void:
	player.velocity = Vector2.ZERO
	if player.has_method("end_grab"):
		player.end_grab()
	_play()


func Exit() -> void:
	pass


func _play() -> void:
	var frames: SpriteFrames = player.anim.sprite_frames
	if frames == null:
		return
	# try the facing-specific one first, then a plain one
	var candidates: Array = [
		anim_prefix + "_" + player.AnimDirection(),
		anim_prefix + "_down",
		anim_prefix,
	]
	for candidate in candidates:
		if frames.has_animation(candidate):
			if player.anim.animation != candidate:
				player.anim.play(candidate)
			return
	# no death art yet — leave the last frame up rather than erroring


## Dead men take no input and never leave this state.
func Process(_delta: float) -> state:
	player.velocity = Vector2.ZERO
	return null


func Physics(_delta: float) -> state:
	return null


func HandleInput(_event: InputEvent) -> state:
	return null
