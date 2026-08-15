extends CanvasLayer
## Door cutscene. The animation is in the AnimationPlayer — edit it there.
## From a level:  add_child(cs)  ->  await cs.play()  ->  cs.queue_free()

signal finished

@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep animating while paused
	anim.animation_finished.connect(_on_anim_finished)
	visible = false
	if get_tree().current_scene == self:
		play()  # this scene was run on its own (F6)


func play() -> void:
	visible = true
	get_tree().paused = true
	anim.play("door_open")
	await finished


func _on_anim_finished(_anim_name: StringName) -> void:
	visible = false
	get_tree().paused = false
	finished.emit()
