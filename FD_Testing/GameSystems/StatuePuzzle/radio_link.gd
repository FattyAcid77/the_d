extends Node
## RadioLink - add as an Autoload named "RadioLink". The one place our systems
## talk to the other dev's radio.

signal frequency_changed(hz: int)
signal radio_opened
signal radio_closed

## Emits frequency_changed only when the value actually moves.
var _last_hz: int = -1
var _last_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var hz := frequency()
	if hz != _last_hz:
		_last_hz = hz
		frequency_changed.emit(hz)
	var open := is_open()
	if open != _last_open:
		_last_open = open
		if open:
			radio_opened.emit()
		else:
			radio_closed.emit()


# --- reading ---------------------------------------------------------------

## True if the radio system exists in this project at all.
func available() -> bool:
	return get_node_or_null("/root/RadioGlobal") != null


## The current frequency in Hz.
func frequency() -> int:
	var rg := get_node_or_null("/root/RadioGlobal")
	if rg == null:
		return min_hz()
	return int(rg.radio)


func min_hz() -> int:
	var rg := get_node_or_null("/root/RadioGlobal")
	return int(rg.RADIO_MIN) if rg else 530


func max_hz() -> int:
	var rg := get_node_or_null("/root/RadioGlobal")
	return int(rg.RADIO_MAX) if rg else 1700


## The wave shape the radio is currently showing (set by radio_ui.gd).
func wavelength() -> float:
	var wc := get_node_or_null("/root/WaveCanvas20")
	return float(wc.wavelength) if wc else 0.0


func amplitude() -> float:
	var wc := get_node_or_null("/root/WaveCanvas20")
	return float(wc.amplitude) if wc else 0.0


## Is the radio UI on screen right now?
func is_open() -> bool:
	for p in get_tree().get_nodes_in_group("radio_panel"):
		if "sami_radio" in p:
			return not p.sami_radio  # their flag is inverted: false = open
		if p.get_child_count() > 0:
			return true
	return false


## Is the radio tuned to `hz` (within `tolerance`)?
func is_tuned_to(hz: int, tolerance: int = 0) -> bool:
	return absi(frequency() - hz) <= tolerance


# --- writing (for cutscenes, tests and story beats) ------------------------

## Force the radio to a frequency.
func set_frequency(hz: int) -> void:
	var rg := get_node_or_null("/root/RadioGlobal")
	if rg == null:
		return
	var snapped: int = int(round(float(hz) / 10.0)) * 10
	rg.radio = clampi(snapped, min_hz(), max_hz())


## Is this a frequency the player can actually reach?
func is_reachable(hz: int) -> bool:
	return hz >= min_hz() and hz <= max_hz() and hz % 10 == 0
