extends Node
## MapRooms - the map's memory. Add as an Autoload named "MapRooms".

signal room_discovered(id: String)
signal room_changed(id: String)

const ROOMS_DIR := "res://FD_Testing/GameSystems/Map/Rooms"

## The flag prefix used to remember discovered rooms.
@export var flag_prefix: String = "map:"

## The size of the map canvas your art is authored on.
@export var map_canvas: Vector2 = Vector2(640, 360)

## Show the full map from the start, for testing.
@export var reveal_all: bool = false

@export var debug_log: bool = false

var rooms: Array[MapRoomDef] = []
var current_room: String = ""
var current_bounds: Rect2 = Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_rooms()


func _load_rooms() -> void:
	rooms.clear()
	# ResList: works in the editor and in an exported build.
	if not ResList.dir_exists(ROOMS_DIR):
		if debug_log:
			print("MapRooms: no %s folder yet." % ROOMS_DIR)
		return
	for path in ResList.tres_files(ROOMS_DIR):
		var r = load(path)
		if r is MapRoomDef:
			rooms.append(r)
	if debug_log:
		print("MapRooms: loaded %d rooms." % rooms.size())


# --- reading ---------------------------------------------------------------

func get_room(id: String) -> MapRoomDef:
	for r in rooms:
		if r.id == id:
			return r
	return null


## Has he found this room?
func is_discovered(id: String) -> bool:
	if reveal_all:
		return true
	var r := get_room(id)
	if r == null:
		return false
	if r.require_flag != "" and not _flag(r.require_flag):
		return false
	if r.known_from_start:
		return true
	return _flag(flag_prefix + id)


## Every room he can currently see on the map.
func discovered_rooms() -> Array[MapRoomDef]:
	var out: Array[MapRoomDef] = []
	for r in rooms:
		if is_discovered(r.id):
			out.append(r)
	return out


func discovered_count() -> int:
	return discovered_rooms().size()


# --- discovering -----------------------------------------------------------

## Marks a room found.
func discover(id: String) -> void:
	if id == "" or _flag(flag_prefix + id):
		return
	var flags := get_node_or_null("/root/Flags")
	if flags:
		flags.set_flag(flag_prefix + id)
	if debug_log:
		print("MapRooms: discovered '%s'." % id)
	room_discovered.emit(id)


## Called by the MapRoom node when its scene loads.
func set_current_room(id: String, bounds: Rect2, also_discover: bool) -> void:
	current_bounds = bounds
	if also_discover:
		discover(id)
	if current_room != id:
		current_room = id
		room_changed.emit(id)


func clear_current_room(id: String) -> void:
	if current_room == id:
		current_room = ""
		current_bounds = Rect2()


# --- where Sami is ---------------------------------------------------------

## Sami's position on the 640x360 map canvas, or Vector2(-1,-1) if he can't be placed
func player_map_position(player_world: Vector2) -> Vector2:
	if current_room == "":
		return Vector2(-1, -1)
	var def := get_room(current_room)
	if def == null:
		return Vector2(-1, -1)
	var on_map := def.rect_on_map()
	if on_map.size.x <= 0.0 or on_map.size.y <= 0.0:
		return Vector2(-1, -1)
	if current_bounds.size.x <= 0.0 or current_bounds.size.y <= 0.0:
		return on_map.position + on_map.size * 0.5  # centre as a fallback

	var f := (player_world - current_bounds.position) / current_bounds.size
	f.x = clampf(f.x, 0.0, 1.0)
	f.y = clampf(f.y, 0.0, 1.0)
	return on_map.position + f * on_map.size


func _flag(name: String) -> bool:
	var flags := get_node_or_null("/root/Flags")
	return flags != null and flags.is_set(name)


## Wipes every discovered room, for testing.
func forget_all() -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags == null or not flags.has_method("clear_flag"):
		return
	for r in rooms:
		flags.clear_flag(flag_prefix + r.id)
	if debug_log:
		print("MapRooms: map forgotten.")
