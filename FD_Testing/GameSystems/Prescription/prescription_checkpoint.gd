class_name PrescriptionCheckpoint extends Resource
## One checkpoint of the prescription save system. Each checkpoint has a
## number that generates its medicine code, and describes exactly what a fresh
## game should look like when the code is entered.

@export_range(0, 255) var number: int = 0

## For you, in the editor ("After statue solved", "Act 2 start"...).
@export var title: String = ""

## The ProgressState the game should be in after entering this code.
@export var state_name: String = "Start"

## Flags that should be set (the story knowledge the player "has" here).
@export var set_flags: Array[String] = []

## The level to load when this code is entered.
@export var scene: PackedScene

@export_group("Sound")
## Played when this checkpoint's code is accepted.
@export var sound_id: String = ""
