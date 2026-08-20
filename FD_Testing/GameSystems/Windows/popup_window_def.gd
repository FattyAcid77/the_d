class_name PopupWindowDef extends Resource
## Everything about ONE popup window. Make a .tres per window in
## Windows/Defs/ and spawn it with:
##
##     PopupWindows.open(my_def)          # or by id:
##     PopupWindows.open_id("whisper_1")
##
## Every behaviour is chosen PER WINDOW — placement, closing, dragging,
## what it shows, whether it sits above or below the game.

enum Kind {
	TEXT,      ## words that talk to the player
	PORTAL,    ## a view into a world
	SOUND,     ## no visuals needed — it just emits sound
	IMAGE,     ## a single picture
}

enum Placement {
	FIXED,          ## exactly where you say
	RANDOM,         ## anywhere on the desktop
	NEAR_PLAYER,    ## follows Sami's position on screen
	CENTER,         ## middle of the screen
	EDGE,           ## clinging to a screen edge
}

enum Depth {
	ABOVE_GAME,     ## always on top of everything
	BELOW_GAME,     ## behind the game window (see the note in popup_windows.gd)
	NORMAL,         ## ordinary window, whatever the OS decides
}

enum CloseMode {
	TIMER,          ## closes itself after `lifetime`
	USER,           ## the user must close it (X / Esc / click)
	FLAG,           ## stays until `close_flag` is set
	NEVER,          ## only closes when code says so
}

enum TextMotion {
	TYPEWRITER,     ## letter by letter, like the dialog box
	SCROLL,         ## crawls across the window
	STATIC,         ## just appears
}

## Unique id, used by PopupWindows.open_id().
@export var id: String = ""
@export var kind: Kind = Kind.TEXT

@export_group("Window")
@export var size := Vector2i(320, 180)
## The window's NAME — shown in its title bar and in the taskbar.
## NOTE: a title bar only exists when `borderless` is OFF.
@export var title: String = "Window"
## OFF = a REAL window with a title bar, an X, and a taskbar entry.
## ON  = a bare rectangle with no chrome (use for ghostly/portal windows).
@export var borderless: bool = false
## Draw the title INSIDE the window too (useful when borderless is ON).
@export var show_title_inside: bool = false
@export var transparent: bool = false
@export var background_color := Color(0.04, 0.04, 0.06, 1.0)
## Can the USER drag this window around?
## (With borderless OFF the OS title bar already drags it.)
@export var user_can_drag: bool = false
@export var user_can_resize: bool = false
## OFF = a normal window the OS can focus and list in the taskbar.
## ON  = it can never take focus (ghostly, but feels less "real").
@export var unfocusable: bool = false
## Show it in the taskbar like any other program.
@export var show_in_taskbar: bool = true
@export var always_on_top: bool = true
@export var depth: Depth = Depth.ABOVE_GAME

@export_group("Skin and logo")
## YOUR window art instead of the operating system's. Drag a WindowSkin .tres
## here (Windows/window_skin.gd) and this window is drawn with your nine-slice
## frame, your title bar, your logo and your close button.
##
## Setting a skin FORCES borderless on — the OS chrome has to go for yours to
## show. The skin then provides dragging, closing and resizing itself.
## Leave empty for a plain OS window, exactly as before.
@export var skin: WindowSkin

## The logo shown in this window's title bar. Overrides the skin's
## default_icon, so one skin can serve many windows with different logos.
## Change it live with window.set_icon_texture(), or per step of a chain.
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
## Flag set the moment it OPENS (story can react).
@export var open_flag: String = ""
## Flag set when it closes.
@export var closed_flag: String = ""
## Only ever open once per save.
@export var once_only: bool = false

@export_group("Changing into another window")
## THE WINDOW CHAIN. After `change_after` seconds this window turns into the
## window with id `change_to`. Set change_to and you have a sequence:
##   whisper_1  ->  whisper_2  ->  whisper_3
##
## MORPH (default) keeps the SAME real OS window and swaps what's inside it.
## The window never blinks, never moves, keeps its taskbar entry — it just
## becomes something else while you watch. That's the unsettling one.
##
## Turn morph OFF and it properly closes and opens a new window instead
## (which can then land somewhere else, per the new def's placement).
##
## Leave change_to empty for no chaining at all.
@export var change_to: String = ""
## Seconds before the change. 0 = as soon as it opens.
@export var change_after: float = 4.0
## ON = same window, new contents. OFF = close this, open a fresh one.
@export var change_morph: bool = true
## Morph only: keep this window's position instead of using the new def's
## placement. ON is usually what you want — it's the same window, so it
## shouldn't jump across the desktop.
@export var change_keep_position: bool = true
## Morph only: keep this window's size too, instead of resizing to the new
## def's size. OFF lets the window grow/shrink as it changes, which is
## a nice effect on its own.
@export var change_keep_size: bool = false
## Seconds to fade the old contents out and the new ones in. 0 = instant cut.
@export var change_fade: float = 0.2
## How many times this chain may run before it stops, to stop an A->B->A
## loop running forever. 0 = no limit.
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
@export var text_speed: float = 24.0        ## chars/sec, or pixels/sec if SCROLL
@export var font_size: int = 20
@export var text_color := Color(0.9, 0.95, 1.0)
@export var text_align_center: bool = true
## Loop the text forever (SCROLL looks good looping).
@export var text_loop: bool = false

@export_group("PORTAL windows")
## ON  = look at THIS game world through a camera somewhere else
## OFF = show a completely separate scene
## NOT SUPPORTED — leave this OFF. Sharing the level's world with a window
## crashes Godot outright (see README 37). To show THIS level from another
## angle, put a COPY of the level in portal_scene below; it runs as its own
## world, which is safe and does the same job.
@export var portal_same_world: bool = false
## For same-world portals: where the camera sits in the level.
@export var portal_camera_position := Vector2.ZERO
@export var portal_zoom := Vector2(1, 1)
## For separate-world portals: the scene to run inside the window.
@export var portal_scene: PackedScene

## DOES THE VIEW MOVE WHEN THE PLAYER DRAGS THE WINDOW?
##
##   FIXED    the view never moves, however far the window is dragged.
##            (What it used to do, and still the right choice for a fixed
##            security-camera feel.)
##
##   DESKTOP  the window becomes a HOLE that slides over the other world.
##            Drag the window right and you see further right. The world
##            appears pinned to your monitor while the window moves over it.
##            This is the one that feels like a real window.
##
##   WORLD    only for portal_same_world. The window shows THIS level at
##            whatever spot the window is physically covering on screen —
##            so it acts like a piece of glass laid over the game.
@export_enum("Fixed", "Desktop", "World") var portal_follow: int = 0

## How far the view moves per pixel the window moves.
##   1.0  world pinned to the monitor — most convincing
##   0.5  the view drifts slower than the window, a dreamy lag
##   2.0  exaggerated, the view races ahead
@export var portal_follow_scale: Vector2 = Vector2.ONE

## Flip the direction. ON makes the view move WITH the window rather than
## the window moving over the world — good for an unsettling wrong-feeling.
@export var portal_follow_invert: bool = false

## Seconds for the view to catch up to the window. 0 = instant and exact.
## A small number like 0.15 gives a heavy, laggy feel.
@export var portal_follow_smooth: float = 0.0

## Separate-world portals only. If the scene has no Camera2D of its own,
## one is made for you. Turn this OFF if your scene manages its own camera
## and you don't want this window touching it.
@export var portal_make_camera: bool = true

@export_group("IMAGE windows")
@export var image: Texture2D
@export var image_fills_window: bool = true

@export_group("Sound")
## ONE-SHOT: the noise the window makes as it APPEARS (a chime, a glitch).
@export var open_sound: AudioStream
@export var open_sound_volume_db: float = 0.0

## AMBIENT: plays the whole time the window is open (a hum, a whisper).
## Works for ANY kind — a SOUND window is just one with nothing to show.
@export var sound: AudioStream
@export var sound_loops: bool = true
@export var sound_volume_db: float = 0.0
## Fade the ambient sound in/out with the window.
@export var sound_fade: float = 0.4

## ONE-SHOT: the noise it makes as it CLOSES.
@export var close_sound: AudioStream
@export var close_sound_volume_db: float = 0.0
