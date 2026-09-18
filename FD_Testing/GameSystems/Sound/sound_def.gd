class_name SoundDef extends Resource
## One library sound: id -> stream, bus, pitch spread. Drop a .tres under
## Sounds/Resource or Sound/Library and the id exists.

@export var id: String = ""

## The audio file.
@export var stream: AudioStream

## Which volume slider owns this sound.
@export_enum("Master", "Music", "Ambience", "SFX", "UI", "Dialog")
var category: String = "SFX"

## Loudness trim for this one sound, in dB (0 = as recorded).
@export var volume_db: float = 0.0

@export_group("Pitch variation")
## Every play picks a random pitch between these two, so repeated sounds
@export var pitch_min: float = 1.0
@export var pitch_max: float = 1.0

@export_group("Floor surfaces (footsteps)")
## When this sound plays from a body standing inside a FloorSurface
@export var surface_variants: Dictionary[String, String] = {}

@export_group("Positional")
## When this sound is triggered by something in the world (a puzzle, a wound, a spill)
@export var positional: bool = false
## How far away a positional sound is still audible, in world pixels.
@export var max_distance: float = 640.0


func random_pitch() -> float:
	if pitch_min >= pitch_max:
		return maxf(0.01, pitch_min)
	return randf_range(pitch_min, pitch_max)
