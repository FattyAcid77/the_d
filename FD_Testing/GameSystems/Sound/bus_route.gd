class_name BusRoute
## BusRoute.use(player, "SFX") - put any audio player on a bus if the bus
## exists, else leave it alone.

static func use(player: Node, bus_name: String) -> void:
	if player == null:
		return
	if AudioServer.get_bus_index(bus_name) == -1:
		return
	if "bus" in player:
		player.bus = bus_name
