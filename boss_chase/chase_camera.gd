class_name ChaseCamera extends Camera2D

# Camera limits taken from the tilemap's own footprint.
#
# The usual system in this project (background_scenes/bgrd_script.gd) derives
# limits from a child literally named "Sprite2D" — a tilemap corridor has no
# such node, so that path is unusable here. bgrd_script.gd:42-71 has a
# commented-out calculate_master_bounds() that did exactly this rect math.
# This is that idea rewritten standalone: it reads one layer instead of merging
# children, and writes straight to limit_* instead of through the shared
# MapBoundsData resource.
#
# Deliberately NOT uncommenting the original: that file is `class_name
# bgrd_node`, referenced by @export var camera_adj on both existing players, so
# re-enabling its _ready() would start writing bounds for every level in the
# game.

@export var bounds_layer: TileMapLayer
@export var padding: int = 0

## Fallback when there's no tilemap yet.
##
## Wider than the 176px corridor on purpose. At zoom 1.2 the viewport shows
## ~533px across, and if the horizontal limits are narrower than that Godot
## can't centre the camera and pins it off to one side. Making the range match
## the view keeps the camera locked at x = 88, which is what we want anyway —
## the corridor is narrower than the screen, so there is no sideways scrolling
## to do.
@export var fallback_rect: Rect2 = Rect2(-180.0, -16.0, 536.0, 2080.0)


func _ready() -> void:
	limit_smoothed = false     # hard clamp, same as Sami_Camera.gd:7
	var r: Rect2 = fallback_rect

	if bounds_layer != null and bounds_layer.tile_set != null:
		var cells: Rect2i = bounds_layer.get_used_rect()
		if cells.size != Vector2i.ZERO:
			var tile: Vector2i = bounds_layer.tile_set.tile_size
			r = Rect2(
				bounds_layer.to_global(Vector2(cells.position * tile)),
				Vector2(cells.size * tile))

	limit_left = int(r.position.x) - padding
	limit_top = int(r.position.y) - padding
	limit_right = int(r.position.x + r.size.x) + padding
	limit_bottom = int(r.position.y + r.size.y) + padding
	reset_smoothing()
