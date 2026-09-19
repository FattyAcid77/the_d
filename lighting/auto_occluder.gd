@tool
class_name AutoOccluder extends LightOccluder2D
## Traces a sprite's own outline into a light blocker, so props cast real
## shadows without anyone drawing polygons by hand.
##
## USE IT:
##   1. Add a LightOccluder2D under (or beside) the sprite, attach this script.
##   2. Drag the sprite into `source`.
##   3. Tick `rebuild`.
##
## Works on Sprite2D and AnimatedSprite2D. For an animated one it traces the
## frame that is showing.

## The picture to trace.
@export var source: Node2D:
	set(value):
		source = value
		_build()

## How coarse the outline is, in pixels. Bigger = fewer points = cheaper.
@export_range(2, 40) var step: int = 8:
	set(value):
		step = value
		_build()

## How much of the picture actually blocks light, measured up from the bottom.
## 1.0 traces the whole outline - right for a wall. Lower it for something
## standing on the floor: a statue should cast a shadow from its base, not
## drop its whole body into darkness. 0.3 is a good starting point.
@export_range(0.05, 1.0) var footprint: float = 1.0:
	set(value):
		footprint = value
		_build()

## Tick to trace again after the art or the frame changes.
@export var rebuild: bool = false:
	set(_value):
		rebuild = false
		_build()


func _build() -> void:
	var img: Image = _image()
	if img == null:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	var from_y: int = int(h * (1.0 - footprint))

	# walk across the picture, remembering the top and bottom of each slice
	var top: Array[Vector2] = []
	var bottom: Array[Vector2] = []
	for x in range(0, w, step):
		var hi: int = -1
		var lo: int = -1
		for y in range(from_y, h):
			var solid: bool = false
			for i in range(x, mini(x + step, w)):
				if img.get_pixel(i, y).a > 0.03:
					solid = true
					break
			if solid:
				if hi < 0:
					hi = y
				lo = y
		if hi >= 0:
			top.append(Vector2(x, hi))
			bottom.append(Vector2(x, lo))

	if top.size() < 2:
		return
	bottom.reverse()
	var points: PackedVector2Array = PackedVector2Array(top + bottom)

	# the sprite's own offset, so the outline lands on the art
	var off: Vector2 = source.position
	if "centered" in source and source.centered:
		off -= Vector2(w, h) * 0.5
	if "offset" in source:
		off += source.offset
	for i in points.size():
		points[i] = points[i] + off

	var poly := OccluderPolygon2D.new()
	poly.polygon = points
	occluder = poly


## The image showing right now, whichever kind of sprite it is.
func _image() -> Image:
	if source == null:
		return null
	if source is Sprite2D and source.texture != null:
		return source.texture.get_image()
	if source is AnimatedSprite2D and source.sprite_frames != null:
		var frames: SpriteFrames = source.sprite_frames
		var anim: String = String(source.animation)
		if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
			var tex: Texture2D = frames.get_frame_texture(anim, source.frame)
			if tex != null:
				return tex.get_image()
	return null
