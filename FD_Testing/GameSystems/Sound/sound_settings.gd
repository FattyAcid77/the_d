class_name SoundSettings extends VBoxContainer
## Self-building volume sliders for a plain menu. The Board's settings tab
## draws its own.

const LABELS := {
	"Master": "Volume",
	"Music": "Music",
	"Ambience": "Ambience",
	"SFX": "Effects",
	"UI": "Interface",
	"Dialog": "Dialog",
}

## Play a preview blip when a slider is released
@export var preview_sound_id: String = "slider_preview"

@export var label_min_width: float = 90.0
@export var slider_min_width: float = 140.0

var _sliders := {}  # category -> HSlider


func _ready() -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null:
		var warn := Label.new()
		warn.text = "Sound autoload missing"
		add_child(warn)
		return

	for cat in snd.CATEGORIES:
		var row := HBoxContainer.new()
		add_child(row)

		var lbl := Label.new()
		lbl.text = tr(LABELS.get(cat, cat))
		lbl.custom_minimum_size.x = label_min_width
		row.add_child(lbl)

		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.value = snd.get_volume(cat)
		sl.custom_minimum_size.x = slider_min_width
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sl)

		sl.value_changed.connect(_on_changed.bind(cat))
		sl.drag_ended.connect(_on_released.bind(cat))
		_sliders[cat] = sl

	# stay honest if something else changes a volume (the Board's tab, say)
	snd.volume_changed.connect(_on_external_change)


func _on_changed(value: float, cat: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd:
		snd.set_volume(cat, value)


func _on_released(_moved: bool, cat: String) -> void:
	var snd := get_node_or_null("/root/Sound")
	if snd == null or not snd.has_sound(preview_sound_id):
		return
	# preview on the bus that was just moved, so you hear the new level
	var d = snd.get_def(preview_sound_id)
	if cat == "Music":
		snd.ui(preview_sound_id)  # don't stomp the actual music
	elif d:
		snd.play_stream(d.stream, cat, d.volume_db)


func _on_external_change(cat: String, value: float) -> void:
	if _sliders.has(cat):
		var sl: HSlider = _sliders[cat]
		if not absf(sl.value - value) < 0.005:
			sl.set_value_no_signal(value)
