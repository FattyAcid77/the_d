class_name RadioBand extends Resource
## ONE frequency range, and what happens in the other room when the player
## tunes to it.
##
## Make a few of these as .tres files, drop them into a RadioReactor's
## `bands` array, and put that RadioReactor inside the scene that a PORTAL
## window shows. Now turning the radio dial changes the other room, live,
## while the player watches through the window.
##
## Sami never goes in there. The PLAYER reaches in, through the dial.

enum Do {
	SHOW,           ## make the target node visible
	HIDE,           ## make it invisible
	PLAY_ANIM,      ## play an animation on an AnimationPlayer / AnimatedSprite2D
	MODULATE,       ## tint the target
	MOVE_TO,        ## slide the target to a position
	SET_FLAG,       ## set a world flag (the main game can react)
	CALL_METHOD,    ## call a function on the target, for anything custom
	NOTHING,        ## just emit the signal and let your own code handle it
}

## For your own reference, and used in the `band_entered` signal so your code
## can tell which one fired.
@export var id: String = ""

@export_group("The frequency")
## The centre of the band, e.g. 1120.
@export var frequency: int = 1000
## How far either side still counts. 0 = must be exact.
@export var tolerance: int = 4
## Also require the radio to be switched on / open.
@export var require_radio_open: bool = true

@export_group("What happens")
@export var action: Do = Do.SHOW
## Which node inside the portal scene it happens to. Relative to the
## RadioReactor. Leave empty for SET_FLAG / NOTHING.
@export var target: NodePath
## PLAY_ANIM: the animation name. CALL_METHOD: the function name.
@export var value_name: String = ""
## MODULATE: the colour. Ignored otherwise.
@export var value_color: Color = Color(1, 1, 1, 1)
## MOVE_TO: the destination, in the portal scene's own coordinates.
@export var value_position: Vector2 = Vector2.ZERO
## MOVE_TO: seconds to slide. 0 = snap.
@export var move_time: float = 0.5
## CALL_METHOD: arguments passed to the function.
@export var value_args: Array = []

@export_group("Flags")
## SET_FLAG: which flag. Also set by any other action if you fill it in.
@export var set_flag_on_enter: String = ""
## Flag set when the player tunes AWAY from this band.
@export var set_flag_on_leave: String = ""
## The band only works once this flag is set. Empty = always live.
@export var require_flag: String = ""

@export_group("Behaviour")
## ON  = fires once and stays that way even if the player retunes.
## OFF = undoes itself when the player tunes away (SHOW becomes HIDE again).
@export var latch: bool = false
## Seconds the player must hold the frequency before it fires. Good for
## making the player sit still and listen.
@export var hold_seconds: float = 0.0
## Play this while the band is tuned in.
@export var sound: AudioStream
@export var sound_volume_db: float = 0.0


## Is this frequency inside the band?
func matches(hz: int) -> bool:
	return absi(hz - frequency) <= tolerance
