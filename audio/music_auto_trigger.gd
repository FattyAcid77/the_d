class_name MusicAutoTrigger extends Node

# Drop one of these into a level and it starts that level's music on load —
# no script on the level itself, nothing to remember to call.
#
# Because Audio.play_music() ignores a request for the track that's already
# playing, neighbouring rooms can share a track and it just keeps going. Give a
# room an empty track to fade the music out entirely.

@export var track: AudioStream
@export var reverb: Audio.REVERB_TYPE = Audio.REVERB_TYPE.NONE


func _ready() -> void:
	Audio.play_music(track)
	# Reverb is set separately from the track, so a room can keep the same music
	# but sound bigger or smaller than the one next door.
	Audio.set_reverb(reverb)
