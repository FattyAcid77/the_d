class_name RadioTrack extends Resource
## One station on the main menu radio. Give it a library id, or drop the audio
## file straight into `stream`.

## The music's SoundDef id.
@export var sound_id: String = ""
## Or the audio file itself, no SoundDef needed.
@export var stream: AudioStream
## Loudness trim for `stream`, in dB. A SoundDef brings its own.
@export var volume_db: float = 0.0
## Plays static until the player has heard this music somewhere in the game.
@export var locked_until_heard: bool = false


## What Profile remembers this music by.
func keys() -> PackedStringArray:
	var out := PackedStringArray()
	if sound_id != "":
		out.append(sound_id)
	if stream and stream.resource_path != "":
		out.append(stream.resource_path)
	return out
