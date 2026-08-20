class_name WindowSpace
## The bridge between TWO different coordinate systems.
##
## Popup windows live in DESKTOP PIXELS — where they are on your monitor,
## (0,0) being the top-left corner of the screen.
##
## Your game lives in WORLD COORDINATES — where things are in the level,
## which the camera then draws wherever it likes.
##
## Nothing in Godot connects those two on its own. This does. It's what
## lets a popup window bump into a rock that exists inside the game.
##
## It accounts for: where the main game window sits on the desktop, the
## project's stretch/scaling settings, and wherever the camera happens to
## be looking right now.
##
## Plain static helper — NOT an autoload, nothing to register.


## Where the main game window's top-left corner is on the desktop.
static func game_window_origin() -> Vector2:
	return Vector2(DisplayServer.window_get_position(0))


## A point on the DESKTOP -> a point in the GAME WORLD.
## Returns Vector2.ZERO if there's no viewport to ask.
static func desktop_to_world(tree: SceneTree, desktop: Vector2) -> Vector2:
	var vp := tree.root as Viewport
	if vp == null:
		return Vector2.ZERO

	# 1. desktop -> pixels inside the main game window
	var in_window := desktop - game_window_origin()

	# 2. window pixels -> viewport coordinates (undoes stretch / scaling)
	var stretch := vp.get_final_transform()
	var in_viewport := stretch.affine_inverse() * in_window

	# 3. viewport coordinates -> world (undoes the camera)
	var canvas := vp.get_canvas_transform()
	return canvas.affine_inverse() * in_viewport


## A point in the GAME WORLD -> a point on the DESKTOP.
static func world_to_desktop(tree: SceneTree, world: Vector2) -> Vector2:
	var vp := tree.root as Viewport
	if vp == null:
		return Vector2.ZERO
	var in_viewport := vp.get_canvas_transform() * world
	var in_window := vp.get_final_transform() * in_viewport
	return in_window + game_window_origin()


## A window's rectangle on the desktop, expressed in WORLD coordinates.
## This is the shape that gets tested against things in the level.
static func window_rect_in_world(tree: SceneTree, win: Window) -> Rect2:
	var tl := desktop_to_world(tree, Vector2(win.position))
	var br := desktop_to_world(tree, Vector2(win.position + win.size))
	return Rect2(tl, br - tl).abs()


## Is this desktop point currently over the main game window at all?
## Useful for "only react while the window is on top of the game".
static func is_over_game_window(desktop: Vector2) -> bool:
	var origin := game_window_origin()
	var size := Vector2(DisplayServer.window_get_size(0))
	return Rect2(origin, size).has_point(desktop)
