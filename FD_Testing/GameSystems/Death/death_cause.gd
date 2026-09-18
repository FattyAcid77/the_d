class_name DeathCause extends Resource
## One way the player can die. Make a .tres per cause in Death/Causes/.

@export var id: String = ""

## What gets written on the clipboard ("bled out", "نزيف", ...).
@export var label: String = ""

## Which printed checkbox this cause ticks: 0 = first row, 1 = second, ...
@export var row: int = 0

## Optional longer line under the cause.
@export_multiline var note: String = ""

## Played the moment Sami dies of this cause.
@export var sound_id: String = ""
