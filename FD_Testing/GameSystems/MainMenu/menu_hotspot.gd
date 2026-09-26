class_name MenuHotspot extends Polygon2D
## One clickable thing in the main menu art. Draw its outline with the polygon
## editor over the art; on hover the art under it brightens and its word shows.

## What pressing it does.
@export_enum("door", "counter", "radio", "knob_back", "knob_next", "dominoes", "chair")
var action: String = "door"
## Off = no hover, no click, skipped by the arrow keys.
@export var enabled: bool = true
## The word shown on hover. English here, Arabic in translations.csv.
@export var label: String = ""
## Centre of that word on the 640x360 art. Zero = just above the outline.
@export var label_at: Vector2 = Vector2.ZERO
## Played when it lights up.
@export var hover_sound_id: String = ""
## Played when it's pressed.
@export var press_sound_id: String = ""
## The artist's lit version, a full 640x360 layer. Empty = the art under the outline brightens.
@export var highlight: Texture2D
## How much brighter the art gets under the outline.
@export var glow_boost: float = 0.9
## Seconds to light up and go dark.
@export var glow_seconds: float = 0.15

const GLOW := preload("res://FD_Testing/GameSystems/MainMenu/menu_glow.gdshader")

var lit := false
var _strength := 0.0
var _tween: Tween


func _ready() -> void:
	# a moved node would drag its outline off the art, so fold the offset into the points
	if position != Vector2.ZERO:
		var pts := polygon
		for i in pts.size():
			pts[i] += position
		polygon = pts
		position = Vector2.ZERO
	var mat := ShaderMaterial.new()
	mat.shader = GLOW
	mat.set_shader_parameter("boost", glow_boost)
	mat.set_shader_parameter("use_art", highlight != null)
	material = mat
	texture = highlight
	color = Color.WHITE
	visible = false


func contains(canvas_point: Vector2) -> bool:
	return enabled and polygon.size() >= 3 \
			and Geometry2D.is_point_in_polygon(canvas_point, polygon)


func bounds() -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var r := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		r = r.expand(p)
	return r


func label_position() -> Vector2:
	if label_at != Vector2.ZERO:
		return label_at
	var b := bounds()
	return Vector2(b.get_center().x, b.position.y - 8.0)


func set_lit(on: bool) -> void:
	if on == lit:
		return
	lit = on
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_strength, _strength, 1.0 if on else 0.0, glow_seconds)
	if not on:
		_tween.tween_callback(hide)


func _set_strength(v: float) -> void:
	_strength = v
	(material as ShaderMaterial).set_shader_parameter("strength", v)
