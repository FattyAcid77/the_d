extends Resource
class_name MirrorFrequencyEntry

## Radio frequency (Hz) that activates this mirror. Range: 530-1700.
@export var frequency: int = 530

## Path to the BeamMirror node in the scene.
@export var mirror_path: NodePath
