class_name MapRoom extends Node2D
## Drop one of these into each room scene and the map does the rest. The
## moment the scene loads, this tells MapRooms which room Sami is in, marks it
## discovered (saved as a flag), and hands over the room's bounds so the
## little Sami on the map can track his real position inside it.

@export_group("Which room")
## Must match the `id` on this room's MapRoomDef .tres.
@export var room_id: String = ""

## The room's area in world coordinates, used to work out where Sami is inside it.
@export var bounds: Rect2 = Rect2()

@export_group("Behaviour")
## Mark this room discovered as soon as the scene loads.
@export var discover_on_enter: bool = true

## Draw the bounds in-game while you're lining them up.
@export var show_bounds: bool = false


func _ready() -> void:
	add_to_group("map_rooms")
	if room_id == "":
		push_warning("MapRoom in '%s' has no room_id." % get_tree().current_scene)
		return
	var mr := get_node_or_null("/root/MapRooms")
	if mr == null:
		push_warning("MapRoom: no MapRooms autoload registered.")
		return
	mr.set_current_room(room_id, world_bounds(), discover_on_enter)


func _exit_tree() -> void:
	var mr := get_node_or_null("/root/MapRooms")
	if mr and mr.current_room == room_id:
		mr.clear_current_room(room_id)


## The room's rectangle in world coordinates.
func world_bounds() -> Rect2:
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		return Rect2(global_position + bounds.position, bounds.size)

	for c in get_children():
		if c is CollisionShape2D and c.shape:
			if c.shape is RectangleShape2D:
				var s: Vector2 = (c.shape as RectangleShape2D).size
				return Rect2(global_position + c.position - s * 0.5, s)
			if c.shape.has_method("get_rect"):
				var r: Rect2 = c.shape.get_rect()
				return Rect2(global_position + c.position + r.position, r.size)
		if c is CollisionPolygon2D and c.polygon.size() > 1:
			var mn: Vector2 = c.polygon[0]
			var mx: Vector2 = c.polygon[0]
			for pt in c.polygon:
				mn = mn.min(pt)
				mx = mx.max(pt)
			return Rect2(global_position + c.position + mn, mx - mn)

	push_warning("MapRoom '%s': no bounds and no CollisionShape2D — "
			% room_id + "the marker can't track Sami inside this room.")
	return Rect2(global_position, Vector2(320, 180))


func _draw() -> void:
	if not show_bounds:
		return
	var b := world_bounds()
	draw_rect(Rect2(b.position - global_position, b.size),
			Color(0.2, 1.0, 0.4, 0.25), true)
	draw_rect(Rect2(b.position - global_position, b.size),
			Color(0.2, 1.0, 0.4, 0.9), false, 1.0)
