class_name MusicLayer extends Resource
## One stem of a MusicSet.

@export var name: String = ""

## The stem.
@export var stream: AudioStream

## Loudness trim for this stem when it's on, in dB.
@export var volume_db: float = 0.0

## Starts audible when the set begins (before any zone says otherwise).
@export var on_by_default: bool = false

@export_group("Dialog")
## Dips by Sound.duck_db while a dialog runs.
@export var ducks_in_dialog: bool = false
