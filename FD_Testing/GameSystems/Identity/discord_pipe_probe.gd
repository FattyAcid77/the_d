class_name DiscordPipeProbe
extends Node
## The documented Discord IPC transport: the named pipe that the desktop app
## opens on Windows. We send the handshake and read the READY frame that
## carries the logged-in user, then close.
## The path is written \\?\pipe\... and not the usual \\.\pipe\...: Godot
## runs every path through simplify_path first, which eats the "." segment and
## turns it into \\pipe\..., a network share that does not exist. The \\?\
## form means the same device namespace and survives untouched.
## Windows only - on Linux/macOS the same endpoint is a unix socket, which
## FileAccess cannot open; DiscordWSProbe covers those.
## Runs on a thread because a pipe read blocks until Discord answers.

signal finished(user: Dictionary)

const PIPE_COUNT := 10
const OP_HANDSHAKE := 0
const OP_FRAME := 1

var client_id := ""
## Whole probe budget in milliseconds, shared by all pipe numbers.
var timeout_ms := 2000
var verbose := false

var _thread: Thread = null


func start() -> void:
	if client_id == "" or OS.get_name() != "Windows":
		call_deferred("_report", {})
		return
	_thread = Thread.new()
	_thread.start(_work)


func _work() -> void:
	var user := {}
	var deadline := Time.get_ticks_msec() + timeout_ms
	for i in PIPE_COUNT:
		if Time.get_ticks_msec() > deadline:
			break
		for path in pipe_paths(i):
			user = _try_pipe(path, deadline)
			if not user.is_empty():
				break
		if not user.is_empty():
			break
	call_deferred("_report", user)


## Both spellings of the same pipe, best one first.
static func pipe_paths(index: int) -> PackedStringArray:
	return PackedStringArray([
		"\\\\?\\pipe\\discord-ipc-" + str(index),
		"\\\\.\\pipe\\discord-ipc-" + str(index),
	])


func _try_pipe(path: String, deadline: int) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return {}
	f.store_buffer(_frame(OP_HANDSHAKE, JSON.stringify({"v": 1, "client_id": client_id})))
	f.flush()

	var user := {}
	while Time.get_ticks_msec() < deadline:
		var head := _read_exact(f, 8, deadline)
		if head.size() < 8:
			break
		var op := head.decode_u32(0)
		var size := head.decode_u32(4)
		var body := _read_exact(f, size, deadline)
		if body.size() < size:
			break
		var text := body.get_string_from_utf8()
		if verbose:
			print("DiscordPipeProbe: op ", op, " ", text)
		var msg = JSON.parse_string(text)
		if msg is Dictionary and msg.get("evt", "") == "READY":
			var data: Dictionary = msg.get("data", {})
			var u: Dictionary = data.get("user", {})
			if not u.is_empty() and str(u.get("id", "")) != "":
				user = u
			break
	f.close()
	return user


## Pipes hand over whatever has arrived so far, so keep asking for the rest.
func _read_exact(f: FileAccess, size: int, deadline: int) -> PackedByteArray:
	var out := PackedByteArray()
	while out.size() < size and Time.get_ticks_msec() < deadline:
		var chunk := f.get_buffer(size - out.size())
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			out.append_array(chunk)
	return out


func _frame(op: int, payload: String) -> PackedByteArray:
	var body := payload.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(8)
	out.encode_u32(0, op)
	out.encode_u32(4, body.size())
	out.append_array(body)
	return out


func _report(user: Dictionary) -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	finished.emit(user)
