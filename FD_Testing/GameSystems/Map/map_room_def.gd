class_name MapRoomDef extends Resource
## one room on the map. Make one .tres per room in Map/Rooms/ and the map
## builds itself.

@export_group("Which room")
## Must match the `room_id` on the MapRoom node in that room's scene.
@export var id: String = ""
## Shown to the player.
@export var display_name: String = ""

@export_group("The art")
## This room drawn on the full 640x360 map canvas, everything else clear.
@export var art: Texture2D

## Where this room's floor sits on the map canvas, in pixels.
@export var map_rect: Rect2 = Rect2()

@export_group("Discovery")
## Already on the map before he's ever been there (a lobby, a plan on a wall).
@export var known_from_start: bool = false
## Only appears once this flag is set, even after he's been inside.
@export var require_flag: String = ""

@export_group("Sound")
## Played when this room is discovered.
@export var sound_id: String = ""

var _cached := Rect2()


## Where this room sits on the 640x360 map.
func rect_on_map() -> Rect2:
	if map_rect.size.x > 0.0 and map_rect.size.y > 0.0:
		return map_rect
	if _cached.size.x > 0.0:
		return _cached
	if art == null:
		return Rect2()
	var img := art.get_image()
	if img == null:
		return Rect2()
	var used := img.get_used_rect()  # the non-transparent part
	_cached = Rect2(used.position, used.size)
	return _cached
