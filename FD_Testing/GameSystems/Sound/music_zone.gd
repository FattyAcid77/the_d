class_name MusicZone extends Area2D
## Area that picks the music for a room. Layered (music_set + layers) or
## simple (one track). Nested zones: innermost wins.

@export_group("Layered (stems)")
## The piece, from Sound/Sets/.
@export var music_set: MusicSet
## Which stems are on in this room.
@export var layers: Array[String] = []
## Stems that come in N seconds after he enters
@export var delayed_layers: Dictionary[String, float] = {}
## Stems that are on while a flag is set, in this room: "choir" -> "found_body"
@export var flag_layers: Dictionary[String, String] = {}
## When a change lands: on the next bar (musical), next beat, or now.
@export_enum("Now", "Beat", "Bar") var align: int = 2

@export_group("Simple (one track)")
## Library id (Sound/Library/*.tres).
@export var music_id: String = ""
## Or the audio file itself.
@export var music_stream: AudioStream
## Loudness trim for this room's track, in dB.
@export var music_volume_db: float = 0.0
## Crossfade when he walks in.
@export var fade_in: float = -1.0
## Crossfade when he walks out.
@export var fade_out: float = -1.0

@export_group("Flags")
## The zone only works once this flag is set.
@export var require_flag: String = ""
## The zone is dead once this flag is set.
@export var hide_flag: String = ""

@export_group("The player")
@export var player_group: String = "Player"

@export_group("Debug")
@export var debug_log: bool = false

var _inside := false


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


## Simple mode: the stream this zone plays.
func zone_stream() -> AudioStream:
	var snd := get_node_or_null("/root/Sound")
	if music_id != "" and snd:
		var d = snd.get_def(music_id)
		if d and d.stream:
			return d.stream
	return music_stream


func _armed() -> bool:
	var flags := get_node_or_null("/root/Flags")
	if flags == null:
		return true
	if require_flag != "" and not flags.is_set(require_flag):
		return false
	if hide_flag != "" and flags.is_set(hide_flag):
		return false
	return true


func _is_player(body: Node2D) -> bool:
	return body != null and player_group != "" and body.is_in_group(player_group)


func _on_entered(body: Node2D) -> void:
	if _inside or not _is_player(body) or not _armed():
		return
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		push_warning("MusicZone '%s': no Sound autoload." % name)
		return
	if music_set != null:
		_inside = true
		if debug_log:
			print("MusicZone '%s': enter set '%s' layers %s." % [name, music_set.id, layers])
		snd.beds.zone_enter(self)
		return
	var stream := zone_stream()
	if stream == null:
		return  # a zone with no track yet is legal - it just does nothing
	_inside = true
	if debug_log:
		print("MusicZone '%s': enter." % name)
	snd._zone_enter(self, stream, fade_in, music_volume_db)


func _on_exited(body: Node2D) -> void:
	if not _inside or not _is_player(body):
		return
	_inside = false
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		return
	if debug_log:
		print("MusicZone '%s': exit." % name)
	if music_set != null:
		snd.beds.zone_exit(self)
	else:
		snd._zone_exit(self, fade_out)


func _exit_tree() -> void:
	if _inside:
		var snd := get_node_or_null("/root/Sound")
		if snd:
			if music_set != null:
				snd.beds.zone_exit(self)
			else:
				snd._zone_exit(self, fade_out)
		_inside = false
