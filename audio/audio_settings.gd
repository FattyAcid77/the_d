extends CanvasLayer

# The audio settings screen. Four sliders — Master over the top of Music, SFX
# and UI — each with a Test button, plus a way back out.
#
# Self-contained on purpose: it reads the live bus volumes when it opens and
# writes every change straight to user://settings.cfg, so nothing outside this
# scene has to know it exists. Drop it into any menu and it works.

## Emitted when the back button is pressed, for menus that want to react.
signal closed

## What each Test button plays. Exported so they can be swapped without code.
@export var test_music: AudioStream
@export var test_sfx: AudioStream

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ui_slider: HSlider = %UISlider

@onready var master_test: Button = %MasterTest
@onready var music_test: Button = %MusicTest
@onready var sfx_test: Button = %SFXTest
@onready var ui_test: Button = %UITest

@onready var back_button: Button = %BackButton

# Where the SFX preview plays from. The SFX bus is positional, so a sound with
# no position sits dead centre and tells you nothing about how it'll actually
# sound in the world.
var _preview_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player is Node2D:
		_preview_pos = player.global_position

	refresh()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	ui_slider.value_changed.connect(_on_ui_changed)

	master_test.pressed.connect(test_master)
	music_test.pressed.connect(test_music_bus)
	sfx_test.pressed.connect(test_sfx_bus)
	ui_test.pressed.connect(test_ui)

	back_button.pressed.connect(close)

	# Re-read the buses every time we're shown, so the sliders can never sit at
	# a stale position if something changed a volume while we were hidden.
	# (CanvasLayer isn't a CanvasItem, so this is the signal — there's no
	# NOTIFICATION_VISIBILITY_CHANGED to hook here.)
	visibility_changed.connect(_on_visibility_changed)

	# Deliberately NOT Audio.setup_button_audio(self). That wires every Button
	# to the UI click, which would mean pressing "Test" on the SFX row plays a
	# UI sound on top of the effect. Mute SFX to demo it and you'd still hear
	# the click and think it was broken. Each test button plays its own bus and
	# nothing else; only Back gets the standard UI sounds.
	back_button.pressed.connect(Audio.ui_select)
	back_button.focus_entered.connect(Audio.ui_focus_change)


func _on_visibility_changed() -> void:
	if visible:
		refresh()


## Pull the current bus volumes into the sliders without firing their signals.
func refresh() -> void:
	master_slider.set_value_no_signal(Audio.get_bus_volume(Audio.master_bus()))
	music_slider.set_value_no_signal(Audio.get_bus_volume(Audio.music_bus()))
	sfx_slider.set_value_no_signal(Audio.get_bus_volume(Audio.sfx_bus()))
	ui_slider.set_value_no_signal(Audio.get_bus_volume(Audio.ui_bus()))


func close() -> void:
	visible = false
	closed.emit()


#region /// test buttons

## Master sits above every other bus, so proving it works means hearing it
## affect more than one of them at once.
func test_master() -> void:
	Audio.ui_success()
	if test_sfx != null:
		Audio.play_spatial_sound(test_sfx, _preview_pos)


## Starts the demo track. play_music() ignores a request for whatever is
## already playing, so pressing this twice won't restart it — press it, then
## drag the Music slider to hear the level change live.
func test_music_bus() -> void:
	if test_music != null:
		Audio.play_music(test_music)


func test_sfx_bus() -> void:
	if test_sfx != null:
		Audio.play_spatial_sound(test_sfx, _preview_pos)


func test_ui() -> void:
	Audio.ui_select()

#endregion


#region /// slider handlers

func _on_master_changed(value: float) -> void:
	Audio.set_bus_volume(Audio.master_bus(), value)
	Audio.save_settings()


func _on_music_changed(value: float) -> void:
	Audio.set_bus_volume(Audio.music_bus(), value)
	# no preview — if music is playing it IS the preview, and if it isn't,
	# that's what the Test button is for
	Audio.save_settings()


func _on_sfx_changed(value: float) -> void:
	Audio.set_bus_volume(Audio.sfx_bus(), value)
	Audio.save_settings()


func _on_ui_changed(value: float) -> void:
	Audio.set_bus_volume(Audio.ui_bus(), value)
	Audio.ui_focus_change()   # drag-along preview, this bus is cheap to spam
	Audio.save_settings()

#endregion
