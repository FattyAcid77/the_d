class_name DeathCause extends Resource
## One way the player can die. Make a .tres per cause in Death/Causes/.
## They're loaded automatically and the one that killed you is written on
## the death clipboard.
##
## Every cause the player has ever died from is remembered in Flags under
## "died_of:<id>", so later you can show a full list of discovered deaths
## (a little collection screen, if you want one).

## Short id used in code: Deaths.kill("bleeding")
@export var id: String = ""

## What gets written on the clipboard ("BLED OUT", "نزيف", ...).
## Leave EMPTY if your board art already prints the cause names — then only
## the check mark is drawn.
@export var label: String = ""

## Which printed checkbox this cause ticks: 0 = first row, 1 = second, ...
## (The board art lists Bleeding / Infection / Unknown = rows 0 / 1 / 2.)
@export var row: int = 0

## Optional longer line under the cause.
@export_multiline var note: String = ""
