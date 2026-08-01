extends Node
## BloodWorld — add as an Autoload named "BloodWorld".
## Puts blood on the floor and tells any BloodGrid underneath about it.
##
##     BloodWorld.spill(blood_type, world_position)
##
## Grids register themselves, so a spill anywhere automatically reaches the
## right puzzle without wiring.

signal spilled(type: BloodType, world_pos: Vector2)

## Stains that land on a puzzle grid stay this long. 0 = forever.
@export var stain_lifetime: float = 0.0
## Stains that land ANYWHERE ELSE fade after this many seconds.
## 0 = they stay forever too.
@export var stray_stain_lifetime: float = 8.0
## How long the fade-out itself takes.
@export var fade_seconds: float = 1.2
## Drawn size when a BloodType has no texture.
@export var default_stain_size: float = 10.0
## Draw order for stains. 0 sits on the floor with everything else; use a
## POSITIVE number if your TileMap is hiding the blood, negative to tuck it
## under characters. (-1 hides it behind a z_index 0 floor — a common trap.)
@export var stain_z_index: int = 0
## Prints every spill to the Output panel — turn on while setting up.
@export var debug_log: bool = false

var _grids: Array = []
var _stain_root: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func register_grid(g: Node) -> void:
	if not _grids.has(g):
		_grids.append(g)


func unregister_grid(g: Node) -> void:
	_grids.erase(g)


## Drop blood at a world position.
func spill(type: BloodType, world_pos: Vector2) -> void:
	if type == null:
		push_warning("BloodWorld.spill() got no BloodType — is `stage_blood` filled in on the Breath node?")
		return
	if debug_log:
		print("BloodWorld: spilling '%s' at %s" % [type.id, world_pos])
	# ask the grids first — one of them may want to keep this splat
	var kept := false
	for g in _grids:
		if is_instance_valid(g) and g.has_method("stain_at"):
			if g.stain_at(world_pos, type):
				kept = true
	if _grids.is_empty() and debug_log:
		print("BloodWorld: no BloodGrid registered — is one in the level?")
	_make_stain(type, world_pos, kept)
	spilled.emit(type, world_pos)


func _make_stain(type: BloodType, world_pos: Vector2, permanent: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if _stain_root == null or not is_instance_valid(_stain_root) \
			or _stain_root.get_parent() != scene_root:
		_stain_root = Node2D.new()
		_stain_root.name = "BloodStains"
		_stain_root.z_index = stain_z_index
		scene_root.add_child(_stain_root)

	var node: Node2D
	if type.texture:
		var s := Sprite2D.new()
		s.texture = type.texture
		s.modulate = type.color
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node = s
	else:
		var blob := _Blob.new()
		blob.color = type.color
		blob.radius = default_stain_size
		node = blob
	node.scale = Vector2.ONE * type.stain_scale
	if type.random_rotation:
		node.rotation = randf() * TAU
	_stain_root.add_child(node)
	node.global_position = world_pos      # must be AFTER add_child, or it lands wrong

	# blood on a puzzle grid sticks around; blood on plain floor dries up
	var life: float = stain_lifetime if permanent else stray_stain_lifetime
	if life > 0.0:
		_fade_out(node, life)


func _fade_out(node: Node2D, after: float) -> void:
	var t := get_tree().create_timer(after)
	await t.timeout
	if not is_instance_valid(node):
		return
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 0.0, fade_seconds)
	await tw.finished
	if is_instance_valid(node):
		node.queue_free()


## A tiny drawn blob, so blood works before the artist makes stain art.
class _Blob extends Node2D:
	var color := Color(0.6, 0.05, 0.05)
	var radius := 10.0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(radius * 0.6, radius * 0.3), radius * 0.45, color)
		draw_circle(Vector2(-radius * 0.5, radius * 0.4), radius * 0.35, color)
