extends Node2D
## The statue's moods: "SHAKING", "YES", "YES 2", "NO", "RAISE HAND".
##
## The painted shadow is its own node on top of the room, so Shadow.modulate.a
## dials it from invisible to solid without anyone repainting anything. It is
## set to 0.12 to match the layer opacity in the .aseprite file.

@onready var shadow: AnimatedSprite2D = $Shadow
@onready var body: AnimatedSprite2D = $Body


## Both halves have the same animation names, so they always move together.
func play(mood: String) -> void:
	body.play(mood)
	shadow.play(mood)
