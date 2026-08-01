class_name PrescriptionCheckpoint extends Resource
## One checkpoint of the prescription save system. Each checkpoint has a
## NUMBER that generates its medicine code, and describes exactly what a
## fresh game should look like when the code is entered.
##
## Save as .tres in GameSystems/Prescription/Checkpoints/.
##
## !! THE NUMBER MUST NEVER CHANGE once players have written codes down.
## Add new checkpoints with NEW numbers; never reuse or renumber old ones.

## 0..255, unique, PERMANENT. This is what the medicine name encodes.
@export_range(0, 255) var number: int = 0

## For you, in the editor ("After statue solved", "Act 2 start"...).
@export var title: String = ""

## The ProgressState the game should be in after entering this code.
@export var state_name: String = "Start"

## Flags that should be set (the story knowledge the player "has" here).
@export var set_flags: Array[String] = []

## The level to load when this code is entered. Leave empty to stay on the
## current scene (e.g. if your main scene handles level loading itself).
@export var scene: PackedScene
