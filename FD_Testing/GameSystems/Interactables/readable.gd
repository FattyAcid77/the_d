class_name Readable extends Area2D
## A note, letter or poster the player can read. Walk up, press interact, the
## PNG fills the screen with our text laid over it, paper sound in and out,
## interact or Esc closes it. Pauses the game while it's up.
##
##   Readable (Area2D)
##   ├── CollisionShape2D
##   ├── Sprite2D            the note lying on the desk (optional)
##   └── Prompt              shown while the player is in range (optional)

signal opened
signal closed

@export_group("The page")
## The paper art.
@export var image: Texture2D
## What's written on it. Goes through tr(), so it can be translated.
@export_multiline var text: String = ""
## Where the text sits on the image, as fractions of it (0..1).
@export var text_area: Rect2 = Rect2(0.12, 0.14, 0.76, 0.72)
@export var font: Font
@export var font_size: int = 22
@export var text_color: Color = Color(0.15, 0.12, 0.08)
@export_enum("Left", "Center", "Right") var text_align: int = 0
## How tall the page is on screen, as a fraction of the screen height.
@export var screen_fraction: float = 0.85

@export_group("Sounds")
## Ids from the sound library.
@export var open_sound_id: String = ""
@export var close_sound_id: String = ""

@export_group("Flags")
## Set when the player has read it.
@export var read_flag: String = ""
## Only exists once this flag is set.
@export var require_flag: String = ""
## Gone once this flag is set.
@export var hide_flag: String = ""

@export_group("Behaviour")
@export var pause_game: bool = true
@export var dim_color: Color = Color(0, 0, 0, 0.6)
@export var player_group: String = "Player"

var is_open := false
var _player_in := false
var _layer: CanvasLayer
var _page: TextureRect
var _label: Label
var _lock := 0.0
var _was_paused := false
@onready var prompt: Node2D = get_node_or_null("Prompt")


func _ready() -> void:
	SoundLink.attach(self)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	if prompt:
		prompt.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_visible()
	var flags := get_node_or_null("/root/Flags")
	if flags and flags.has_signal("flag_changed"):
		flags.flag_changed.connect(func(_f, _v): _refresh_visible())


func _refresh_visible() -> void:
	var flags := get_node_or_null("/root/Flags")
	var show := true
	if flags:
		if require_flag != "" and not flags.is_set(require_flag):
			show = false
		if hide_flag != "" and flags.is_set(hide_flag):
			show = false
	visible = show
	monitoring = show


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta
		return
	if is_open:
		if InputAccess.just_pressed() or InputAccess.just_pressed("ui_cancel"):
			close()
		return
	if _player_in and visible and InputAccess.just_pressed():
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_build()
	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	_lock = 0.15
	var snd := get_node_or_null("/root/Sound")
	if snd and open_sound_id != "":
		snd.play(open_sound_id)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _layer:
		_layer.queue_free()
		_layer = null
	if pause_game:
		get_tree().paused = _was_paused
	_lock = 0.15
	var flags := get_node_or_null("/root/Flags")
	if flags and read_flag != "":
		flags.set_flag(read_flag)
	var snd := get_node_or_null("/root/Sound")
	if snd and close_sound_id != "":
		snd.play(close_sound_id)
	closed.emit()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	var root := Control.new()
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)

	var dim := ColorRect.new()
	dim.layout_direction = Control.LAYOUT_DIRECTION_LTR
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_page = TextureRect.new()
	_page.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_page.texture = image
	_page.stretch_mode = TextureRect.STRETCH_SCALE
	_page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_page)

	_label = Label.new()
	_label.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_label.text = tr(text)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text_direction = Control.TEXT_DIRECTION_AUTO   # Arabic reads right to left on its own
	_label.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][text_align]
	_label.add_theme_color_override("font_color", text_color)
	_label.add_theme_font_size_override("font_size", font_size)
	if font:
		_label.add_theme_font_override("font", font)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_label)

	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	if _page == null or image == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var art := image.get_size()
	var s := screen.y * screen_fraction / art.y
	if art.x * s > screen.x * 0.95:
		s = screen.x * 0.95 / art.x
	var size := art * s
	_page.size = size
	_page.position = (screen - size) * 0.5
	_label.position = Vector2(text_area.position.x * size.x, text_area.position.y * size.y)
	_label.size = Vector2(text_area.size.x * size.x, text_area.size.y * size.y)


func _is_player(body: Node2D) -> bool:
	return body != null and body.is_in_group(player_group)


func _on_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_in = true
		if prompt:
			prompt.visible = visible


func _on_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_in = false
		if prompt:
			prompt.visible = false
