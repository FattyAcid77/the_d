extends Sprite2D


# Called when the node enters the scene tree for the first time.

func _process(delta: float) -> void:
	if RadioGlobal.filter:
		visible = true
		
