class_name BossJuice extends Node
## The feel: screen shake, hit-stop, flashes, zoom punch.
## Drop this in the boss room and hand it to BossFight's `juice` slot.
## It joins the group "boss_juice" so the TV can shake the screen too.

@export_group("Shake")
@export var shake_decay: float = 6.0
@export var shake_max_offset: float = 24.0
@export var shake_max_roll: float = 0.06

@export_group("Hit stop")
## How long the world freezes on a hit (seconds of real time).
@export var hit_stop_seconds: float = 0.07
## How slow it goes (0 = full freeze, 0.2 = slow motion).
@export var hit_stop_scale: float = 0.02

@export_group("Flash")
@export var flash_color := Color(1, 1, 1, 0.65)
@export var flash_seconds: float = 0.18

@export_group("Zoom punch")
@export var zoom_amount: float = 0.06
@export var zoom_seconds: float = 0.22

var _shake: float = 0.0
var _cam: Camera2D
var _cam_base_offset := Vector2.ZERO
var _cam_base_zoom := Vector2.ONE
var _flash: ColorRect
var _stopping := false


func _ready() -> void:
	add_to_group("boss_juice")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 99
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = flash_color
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	layer.add_child(_flash)


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_cam = get_viewport().get_camera_2d()
	if _cam == null:
		return
	if _cam_base_offset == Vector2.ZERO:
		_cam_base_offset = _cam.offset
	_shake = maxf(0.0, _shake - shake_decay * delta)
	var amount: float = _shake / maxf(1.0, shake_max_offset)
	_cam.offset = _cam_base_offset + Vector2(
		randf_range(-1, 1) * _shake,
		randf_range(-1, 1) * _shake)
	_cam.rotation = randf_range(-1, 1) * shake_max_roll * amount
	if _shake <= 0.01:
		_cam.offset = _cam_base_offset
		_cam.rotation = 0.0


## Shake the screen. `strength` is roughly pixels.
func shake(strength: float = 10.0) -> void:
	_shake = minf(shake_max_offset, maxf(_shake, strength))


## Freeze the world for an instant — the punch behind every good hit.
func hit_stop(seconds: float = -1.0) -> void:
	if _stopping:
		return
	_stopping = true
	var t: float = seconds if seconds > 0.0 else hit_stop_seconds
	Engine.time_scale = hit_stop_scale
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


## A white flash over everything.
func flash() -> void:
	if _flash == null:
		return
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, flash_seconds)


## A quick zoom-in kick on the camera.
func zoom_punch() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _cam_base_zoom == Vector2.ONE:
		_cam_base_zoom = cam.zoom
	var tw := create_tween()
	tw.tween_property(cam, "zoom", _cam_base_zoom * (1.0 + zoom_amount), zoom_seconds * 0.35) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "zoom", _cam_base_zoom, zoom_seconds * 0.65) \
		.set_ease(Tween.EASE_IN_OUT)
