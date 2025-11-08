extends Node

@export var filter:bool = true
var wave_canvas: Node = null

var current_state: int = 0
var frequency: float = 0.0

var state1:bool= false
var state2:bool= false
var state3:bool= false
var state4:bool= false
var state5:bool= false
var state6:bool= false




var radio: int = 530


func _ready() -> void:
	print(radio)
