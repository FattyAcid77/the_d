class_name PopupWindowDef extends Resource
## Everything about one popup window. Make a .tres per window in Windows/Defs/
## and spawn it with: PopupWindows.open(my_def) # or by id:
## PopupWindows.open_id("whisper_1") Every behaviour is chosen per window -
## placement, closing, dragging, what it shows, whether it sits above or below
## the game.

enum Kind {
	TEXT,  # words that talk to the player
	PORTAL,  # a view into a world
	SOUND,  # no visuals needed - it just emits sound
	IMAGE,  # a single picture
}

enum Placement {
	FIXED,  # exactly where you say
	RANDOM,  # anywhere on the desktop
	NEAR_PLAYER,  # follows Sami's position on screen
	CENTER,  # middle of the screen
	EDGE,  # clinging to a screen edge
}

enum Depth {
	ABOVE_GAME,  # always on top of everything
	BELOW_GAME,  # behind the game window (see the note in popup_windows.gd)
	NORMAL,  # ordinary window, whatever the OS decides
}

enum CloseMode {
	TIMER,  # closes itself after `lifetime`
	USER,  # the user must close it (X / Esc / click)
	FLAG,  # stays until `close_flag` is set
	NEVER,  # only closes when code says so
}

enum TextMotion {
	TYPEWRITER,  # letter by letter, like the dialog box
	SCROLL,  # crawls across the window
	STATIC,  # just appears
}

## Unique id, used by PopupWindows.open_id().
@export var id: String = ""
@export var kind: Kind = Kind.TEXT

@export_group("Window")
@export var size := Vector2i(320, 180)
## The window's name - shown in its title bar and in the taskbar.
@export var title: String = "Window"
## off = a real window with a title bar, an X, and a taskbar entry.
@export var borderless: bool = false
## Draw the title inside the window too (useful when borderless is on).
@export var show_title_inside: bool = false
@export var transparent: bool = false
@export var background_color := Color(0.04, 0.04, 0.06, 1.0)
## Can the USER drag this window around?
@export var user_can_drag: bool = false
@export var user_can_resize: bool = false
## off = a normal window the OS can focus and list in the taskbar.
@export var unfocusable: bool = false
## Show it in the taskbar like any other program.
@export var show_in_taskbar: bool = true
@export var always_on_top: bool = true
@export var depth: Depth = Depth.ABOVE_GAME

@export_group("Skin and logo")
## your window art instead of the operating system's.
@export var skin: WindowSkin

## The logo shown in this window's title bar.
@export var icon: Texture2D


@export_group("Where it appears")
@export var placement: Placement = Placement.RANDOM
## For FIXED: the exact desktop position.
@export var fixed_position := Vector2i(100, 100)
## For NEAR_PLAYER / EDGE / CENTER: nudge it by this much.
@export var offset := Vector2i.ZERO
## For RANDOM: keep this far from the screen edges.
@export var random_margin: int = 60

@export_group("How it closes")
@export var close_mode: CloseMode = CloseMode.TIMER
## For TIMER: seconds before it goes.
@export var lifetime: float = 6.0
## For FLAG: the flag that dismisses it.
@export var close_flag: String = ""
## Flag set the moment it opens (story can react).
@export var open_flag: String = ""
## Flag set when it closes.
@export var closed_flag: String = ""
## Only ever open once per save.
@export var once_only: bool = false

@export_group("Changing into another window")
## the window chain.
@export var change_to: String = ""
## Seconds before the change.
@export var change_after: float = 4.0
## on = same window, new contents.
@export var change_morph: bool = true
## Morph only: keep this window's position instead of using the new def's placement.
@export var change_keep_position: bool = true
## Morph only: keep this window's size too, instead of resizing to the new def's size.
@export var change_keep_size: bool = false
## Seconds to fade the old contents out and the new ones in.
@export var change_fade: float = 0.2
## How many times this chain may run before it stops, to stop an A->B->A loop running forever.
@export var change_max_steps: int = 0


@export_group("Appearing / leaving")
## Fade in and out (needs transparency on some systems; safe either way).
@export var fade_seconds: float = 0.25
## Grow from nothing instead of just appearing.
@export var grow_in: bool = false
## Jitter the window position while it's open (unsettling).
@export var shake_pixels: float = 0.0

@export_group("TEXT windows")
@export_multiline var text: String = ""
@export var text_motion: TextMotion = TextMotion.TYPEWRITER
@export var text_speed: float = 24.0  # chars/sec, or pixels/sec if SCROLL
@export var font_size: int = 20
@export var text_color := Color(0.9, 0.95, 1.0)
@export var text_align_center: bool = true
## Loop the text forever (SCROLL looks good looping).
@export var text_loop: bool = false

@export_group("PORTAL windows")
## on = look at this game world through a camera somewhere else off = show a completely separate
@export var portal_same_world: bool = false
## For same-world portals: where the camera sits in the level.
@export var portal_camera_position := Vector2.ZERO
@export var portal_zoom := Vector2(1, 1)
## For separate-world portals: the scene to run inside the window.
@export var portal_scene: PackedScene

## does the view move when the player drags the window?
@export_enum("Fixed", "Desktop", "World") var portal_follow: int = 0

## How far the view moves per pixel the window moves.
@export var portal_follow_scale: Vector2 = Vector2.ONE

## Flip the direction.
@export var portal_follow_invert: bool = false

## Seconds for the view to catch up to the window.
@export var portal_follow_smooth: float = 0.0

## Separate-world portals only.
@export var portal_make_camera: bool = true

@export_group("IMAGE windows")
@export var image: Texture2D
@export var image_fills_window: bool = true

@export_group("Sound")
## one-shot: the noise the window makes as it appears (a chime, a glitch).
@export var open_sound: AudioStream
@export var open_sound_volume_db: float = 0.0

## ambient: plays the whole time the window is open (a hum, a whisper).
@export var sound: AudioStream
@export var sound_loops: bool = true
@export var sound_volume_db: float = 0.0
## Fade the ambient sound in/out with the window.
@export var sound_fade: float = 0.4

## one-shot: the noise it makes as it closes.
@export var close_sound: AudioStream
@export var close_sound_volume_db: float = 0.0
