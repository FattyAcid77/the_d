class_name MusicSet extends Resource
## A piece as stems. One .tres per piece. Rooms pick a mix of these layers,
## not a track.

@export var id: String = ""

## Music beds go on the Music slider; room-tone beds on Ambience.
@export_enum("Music", "Ambience") var category: String = "Music"

## The stems.
@export var layers: Array[MusicLayer] = []

@export_group("Tempo (for bar-aligned changes)")
@export var bpm: float = 120.0
@export var beats_per_bar: int = 4

@export_group("Flags that turn layers on anywhere")
## layer name -> flag name.
@export var flag_layers: Dictionary[String, String] = {}

@export_group("Fades")
## Seconds a layer takes to rise or fall.
@export var layer_fade: float = 1.5
## Seconds to crossfade when a different set replaces this one.
@export var set_fade: float = 2.0


func layer_names() -> Array[String]:
	var out: Array[String] = []
	for l in layers:
		if l and l.name != "":
			out.append(l.name)
	return out


func get_layer(layer_name: String) -> MusicLayer:
	for l in layers:
		if l and l.name == layer_name:
			return l
	return null


## Seconds in one bar.
func bar_seconds() -> float:
	if bpm <= 0.0 or beats_per_bar <= 0:
		return 0.0
	return 60.0 / bpm * float(beats_per_bar)


func beat_seconds() -> float:
	return 0.0 if bpm <= 0.0 else 60.0 / bpm
