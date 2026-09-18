class_name WindowSpace
## The bridge between two different coordinate systems. Popup windows live in
## desktop pixels - where they are on your monitor, (0,0) being the top-left
## corner of the screen.

static func game_window_origin() -> Vector2:
	return Vector2(DisplayServer.window_get_position(0))


## A point on the desktop -> a point in the game world.
static func desktop_to_world(tree: SceneTree, desktop: Vector2) -> Vector2:
	var vp := tree.root as Viewport
	if vp == null:
		return Vector2.ZERO

	# 1.
	var in_window := desktop - game_window_origin()

	# 2.
	var stretch := vp.get_final_transform()
	var in_viewport := stretch.affine_inverse() * in_window

	# 3.
	var canvas := vp.get_canvas_transform()
	return canvas.affine_inverse() * in_viewport


## A point in the game world -> a point on the desktop.
static func world_to_desktop(tree: SceneTree, world: Vector2) -> Vector2:
	var vp := tree.root as Viewport
	if vp == null:
		return Vector2.ZERO
	var in_viewport := vp.get_canvas_transform() * world
	var in_window := vp.get_final_transform() * in_viewport
	return in_window + game_window_origin()


## A window's rectangle on the desktop, expressed in world coordinates.
static func window_rect_in_world(tree: SceneTree, win: Window) -> Rect2:
	var tl := desktop_to_world(tree, Vector2(win.position))
	var br := desktop_to_world(tree, Vector2(win.position + win.size))
	return Rect2(tl, br - tl).abs()


## Is this desktop point currently over the main game window at all?
static func is_over_game_window(desktop: Vector2) -> bool:
	var origin := game_window_origin()
	var size := Vector2(DisplayServer.window_get_size(0))
	return Rect2(origin, size).has_point(desktop)
