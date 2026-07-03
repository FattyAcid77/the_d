extends Area2D

@onready var dd: AnimatedSprite2D = $AnimatedSprite2D

@export var required_puzzle_id: String = "Complete"
@export_file("*.tscn") var scene: String

var gate_open := false
var teleporting := false

func _ready() -> void:
	for receiver in get_tree().get_nodes_in_group("beam_receiver"):
		if receiver.puzzle_id == required_puzzle_id:
			receiver.beam_activated.connect(_open_gate)
			break

func _open_gate() -> void:
	if gate_open:
		return
	dd.stop()
	dd.frame = 0
	dd.play("default")
	dd.animation_finished.connect(func(): gate_open = true, CONNECT_ONE_SHOT)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	if teleporting or not gate_open or scene == "":
		return
	teleporting = true
	get_tree().call_deferred("change_scene_to_file", scene)
