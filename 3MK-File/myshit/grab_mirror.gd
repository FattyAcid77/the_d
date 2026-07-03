class_name GrabMirror extends CharacterBody2D

# A mirror you can push/pull (hold F) and rotate (hold E).
# Stays in the "beam_mirror" group so the beam still bounces off it.

@export var bar_color: Color = Color(0.75, 0.9, 1.0, 0.9)
@export var grabbed_color: Color = Color(1.0, 0.95, 0.55, 0.95)

var _focused_player: Player = null
var _is_grabbed: bool = false


func _ready() -> void:
	add_to_group("beam_mirror")
	add_to_group("grabbable")
	$InteractZone.body_entered.connect(_on_zone_entered)
	$InteractZone.body_exited.connect(_on_zone_exited)
	queue_redraw()


func rotate_by(amount: float) -> void:
	rotation += amount


func on_grabbed(player: Node) -> void:
	_is_grabbed = true
	add_collision_exception_with(player)   # so we don't block each other
	queue_redraw()


func on_released(player: Node) -> void:
	_is_grabbed = false
	velocity = Vector2.ZERO
	remove_collision_exception_with(player)
	queue_redraw()


# Only the test Player has focus_grabbable. The real Sami is also in the "Player"
# group, so check the type or it errors when Sami walks near.
func _on_zone_entered(body: Node) -> void:
	if body is Player:
		_focused_player = body
		body.focus_grabbable = self


func _on_zone_exited(body: Node) -> void:
	if body == _focused_player:
		if _focused_player.focus_grabbable == self:
			_focused_player.focus_grabbable = null
		_focused_player = null


# just a bar with a dot on one end so you can see which way it points
func _draw() -> void:
	var col: Color = grabbed_color if _is_grabbed else bar_color
	draw_rect(Rect2(-6, -32, 12, 64), col)
	draw_rect(Rect2(-6, -32, 12, 64), Color(1, 1, 1, 0.8), false, 2.0)
	draw_circle(Vector2(0, -32), 4.0, Color(1, 1, 1, 0.9))
