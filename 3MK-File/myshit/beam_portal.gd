extends Area2D
class_name BeamPortal

## Must match the source_portal_id on the BeamEmitter in the OTHER world.
@export var portal_id: String = "portal_1"

func _ready() -> void:
	add_to_group("beam_portal")
	queue_redraw()

func _draw() -> void:
	var col := Color(0.3, 0.6, 1.0, 0.45)
	draw_rect(Rect2(-10, -80, 20, 160), col)
	draw_rect(Rect2(-10, -80, 20, 160), Color(0.3, 0.6, 1.0, 1.0), false, 2.0)
	# Center line to show beam direction
	draw_line(Vector2(0, -80), Vector2(0, 80), Color(1.0, 1.0, 1.0, 0.25), 1.0)
