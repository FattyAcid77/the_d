extends Node2D

## Emitted when `tracked` walks into or out of the painted light.
signal lit_changed(amount: float)

## Drag the player here. The tree is not built yet when this loads, so it is
## a path and gets looked up in _ready.
@export_node_path("Node2D") var tracked: NodePath
## Where the feet are, relative to the node origin.
@export var tracked_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0) var lit_threshold: float = 0.5

@onready var back: Sprite2D = $Back

var _mat: ShaderMaterial
var _img: Image
var _tracked: Node2D
var _origin: Vector2
var _size: Vector2
var _was_lit := false

func _ready() -> void:
	_mat = back.material
	_img = _mat.get_shader_parameter("light_tex").get_image()
	if _img.is_compressed():
		_img.decompress()

	# The sprite is the truth; push it into the shader so both agree.
	_origin = back.global_position
	_size = back.texture.get_size() * back.global_scale
	_mat.set_shader_parameter("room_origin", _origin)
	_mat.set_shader_parameter("room_size", _size)

	_tracked = get_node_or_null(tracked) as Node2D

## 0.0 = pitch dark, 1.0 = fully in the light.
func light_at(world_pos: Vector2) -> float:
	var p := (world_pos - _origin) / _size
	if p.x < 0.0 or p.x > 1.0 or p.y < 0.0 or p.y > 1.0:
		return 0.0
	var px := Vector2i(p * Vector2(_img.get_size()))
	px = px.clamp(Vector2i.ZERO, _img.get_size() - Vector2i.ONE)
	return _img.get_pixelv(px).a * get_energy()

func get_energy() -> float:
	return _mat.get_shader_parameter("light_energy")

func set_energy(v: float) -> void:
	_mat.set_shader_parameter("light_energy", v)

func _process(_delta: float) -> void:
	if _tracked == null:
		return
	var amount := light_at(_tracked.global_position + tracked_offset)
	var lit := amount >= lit_threshold
	if lit != _was_lit:
		_was_lit = lit
		lit_changed.emit(amount)
