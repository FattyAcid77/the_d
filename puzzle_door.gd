extends Area2D

signal door_finished_opening

@onready var dd: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx: AudioStreamPlayer2D = $Sfx

@export var required_puzzle_id: String = "Complete"
@export_file("*.tscn") var scene: String

## Plays the instant the puzzle solves. Swap it here to change the sound.
@export var open_sound: AudioStream
## Seconds after the sound starts before the door animation plays.
## Tune it so the head-explosion frame lands right on the boom.
@export_range(0.0, 30.0, 0.01) var animation_delay: float = 9.88

var gate_open := false
var opening := false
var teleporting := false

func _ready() -> void:
	add_to_group("puzzle_door")
	# coming back to a solved room: door just sits open, no sound
	if GameState.is_solved(required_puzzle_id):
		gate_open = true
		dd.animation = "default"
		dd.frame = dd.sprite_frames.get_frame_count("default") - 1
		return
	for receiver in get_tree().get_nodes_in_group("beam_receiver"):
		if receiver.puzzle_id == required_puzzle_id:
			receiver.beam_activated.connect(_open_gate)
			break

func _open_gate() -> void:
	if opening:
		return
	opening = true
	if open_sound != null:
		sfx.stream = open_sound
		sfx.play()   # riser starts the instant the beam completes the puzzle
		if animation_delay > 0.0:
			await get_tree().create_timer(animation_delay).timeout
	dd.stop()
	dd.frame = 0
	dd.play("default")
	await dd.animation_finished
	gate_open = true
	door_finished_opening.emit()   # puzzle area waits for this to sweep the beam gear

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if teleporting or not gate_open or scene == "":
		return
	teleporting = true
	get_tree().call_deferred("change_scene_to_file", scene)
