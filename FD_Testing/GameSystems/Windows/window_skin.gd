class_name WindowSkin extends Resource
## your window look, drawn inside a borderless window - frame, title bar, logo
## and close button, all from your own art. why it works this way Godot cannot
## restyle a real OS title bar, and it cannot give each window its own taskbar
## icon - DisplayServer.set_icon() has no window argument, so it changes the
## icon for the whole application at once.

@export_group("The frame")
## Your nine-slice window art.
@export var frame: Texture2D
## Where the corners of your art end, in pixels.
@export var patch_left: int = 12
@export var patch_top: int = 12
@export var patch_right: int = 12
@export var patch_bottom: int = 12
## off makes the middle of the nine-slice transparent
@export var draw_center: bool = true
## Tint the whole frame.
@export var frame_modulate: Color = Color(1, 1, 1, 1)
## Pixel art stays crisp.
@export var pixel_perfect: bool = true

@export_group("The title bar")
## Height of the bar at the top of your art, in pixels.
@export var title_bar_height: int = 24
## Optional separate nine-slice just for the bar.
@export var title_bar_texture: Texture2D
@export var show_title_text: bool = true
@export var title_font: Font
@export var title_font_size: int = 14
@export var title_color: Color = Color(1, 1, 1, 0.9)
## Where the words sit in the bar.
@export_enum("Left", "Center", "Right") var title_align: int = 0
## Nudge the words.
@export var title_offset: Vector2 = Vector2(4, 0)

@export_group("The logo")
## Default logo for windows using this skin.
@export var default_icon: Texture2D
@export var icon_size: Vector2 = Vector2(16, 16)
## Where the logo sits inside the title bar.
@export var icon_offset: Vector2 = Vector2(4, 4)
## The title text is pushed right by this much when a logo is showing.
@export var title_indent_when_icon: float = 22.0

@export_group("The close button")
@export var show_close_button: bool = true
@export var close_normal: Texture2D
@export var close_hover: Texture2D
@export var close_pressed: Texture2D
@export var close_size: Vector2 = Vector2(16, 16)
## From the top-right corner of the window.
@export var close_offset: Vector2 = Vector2(6, 4)
## Fallback drawn when you haven't supplied close art yet.
@export var close_fallback_color: Color = Color(1, 1, 1, 0.7)

@export_group("Content area")
## How far the words/picture inside sit from each edge of the frame.
@export var content_margin_left: int = 10
@export var content_margin_right: int = 10
@export var content_margin_top: int = 6
@export var content_margin_bottom: int = 10

@export_group("Dragging and resizing")
## Drag the window by its title bar, like a normal program.
@export var drag_from_title_bar: bool = true
## Drag by grabbing anywhere on the window.
@export var drag_from_anywhere: bool = false
## A grab corner at the bottom-right for resizing.
@export var show_resize_grip: bool = false
@export var resize_grip_texture: Texture2D
@export var resize_grip_size: Vector2 = Vector2(14, 14)
## Smallest the player may shrink it to.
@export var min_size: Vector2i = Vector2i(120, 80)

@export_group("Sound")
## Played when the close button is clicked.
@export var close_click_sound: AudioStream


## The pixels reserved at the top for the title bar.
func top_inset() -> float:
	return float(title_bar_height)
