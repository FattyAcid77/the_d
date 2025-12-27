extends Control
@onready var b: Button = $ColorRect/ColorRect/SineWave/R1
@onready var b_2: Button = $ColorRect/ColorRect/SineWave/L1
@onready var label: Label = $ColorRect/ColorRect2/Label
var radio_scene: PackedScene = preload("res://3MK-File/Scene/test_scene.tscn")

func _close_radio():
	var radio_instance = radio_scene.instantiate()


@export var hold = 1



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label.text =str(RadioGlobal.radio) +  "  Hz"  
	if b.is_pressed():
		RadioGlobal.radio += int(hold * 1 )

func _on_button_pressed() -> void:
	RadioGlobal.radio += 1


func _on_button_2_pressed() -> void:
	RadioGlobal.radio -= 1
