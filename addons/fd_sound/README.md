# FD Sound (editor plugin): sounds, flags and ids

Install: this folder goes in `res://addons/`, then Project Settings -> Plugins
-> tick FD Sound. Needs GameSystems' `Sound` autoload.

- Every sound_id / *_sound_id / music_id field: tick or cross (does the id
  exist), search list, play button.
- A MusicSet .tres: tick layers and play them together at the top.
- MusicZone / AmbienceZone: layers as tick boxes from its set, play the mix.
- Dialog lines and action steps: Pick fills the first arg for play_sound,
  play_music, play_set, music_layer and ambience_layer.
- Flag fields and lists: pick from every flag in the project; the mark says
  whether something sets it (or reads it). Hover for where.
- Death cause, item, window, room and state fields: pick from the real ids;
  red when the id doesn't exist.
- SoundHook: a table. Each hook picks a signal or animation of the node it
  listens to, and the sound it plays.

Full notes: GameSystems README, section 23.
