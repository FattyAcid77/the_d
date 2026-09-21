class_name DiscordWSProbe
extends Node
## Asks the Discord desktop app who is logged in, over its local RPC server
## (127.0.0.1, ports 6463-6472). Nothing is shown to the player: we read the
## READY event Discord sends on connect and disconnect again.
## Pure WebSocketPeer, no addon. Emits finished({}) when nobody answers.

signal finished(user: Dictionary)

const PORT_FIRST := 6463
const PORT_LAST := 6472

var client_id := ""
## Leave empty. Discord treats a missing Origin header as "a local app is
## calling" and lets it through; any origin it does not know is rejected.
var origin := ""
## How long one port gets before we move to the next one.
var port_timeout := 1.2
var verbose := false

var _ws: WebSocketPeer = null
var _port := PORT_FIRST
var _deadline := 0.0
var _done := false


func start() -> void:
	if client_id == "":
		push_warning("DiscordWSProbe: no client_id, skipping.")
		call_deferred("_finish", {})
		return
	_port = PORT_FIRST
	_open_port()


func _open_port() -> void:
	_ws = WebSocketPeer.new()
	if origin != "":
		_ws.handshake_headers = PackedStringArray(["Origin: " + origin])
	var url := "ws://127.0.0.1:%d/?v=1&client_id=%s&encoding=json" % [_port, client_id]
	var err := _ws.connect_to_url(url)
	_deadline = Time.get_ticks_msec() / 1000.0 + port_timeout
	if err != OK:
		_next_port()
	elif verbose:
		print("DiscordWSProbe: trying port ", _port)


func _next_port() -> void:
	if _ws:
		_ws.close()
		_ws = null
	_port += 1
	if _port > PORT_LAST:
		_finish({})
	else:
		_open_port()


func _process(_delta: float) -> void:
	if _done or _ws == null:
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			_read(_ws.get_packet().get_string_from_utf8())
			if _done:
				return
	elif state == WebSocketPeer.STATE_CLOSED:
		_next_port()
		return
	if Time.get_ticks_msec() / 1000.0 > _deadline:
		_next_port()


func _read(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	if verbose:
		print("DiscordWSProbe: ", text)
	if msg.get("evt", "") != "READY":
		return
	var data: Dictionary = msg.get("data", {})
	var user: Dictionary = data.get("user", {})
	if user.is_empty() or str(user.get("id", "")) == "":
		# Connected, but this Discord build hides the user from an unauthorised app.
		_finish({})
	else:
		_finish(user)


func _finish(user: Dictionary) -> void:
	if _done:
		return
	_done = true
	if _ws:
		_ws.close()
		_ws = null
	set_process(false)
	finished.emit(user)
