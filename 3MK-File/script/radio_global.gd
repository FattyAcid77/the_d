extends Node

# the dial, and nothing else. RadioGlobal.radio is the single source of truth
# for what the radio is tuned to — radio_ui.gd writes it, everything else
# reads it.

@export var filter:bool = true   # read by Main Scenes/filter.gd

const RADIO_MIN: int = 530
const RADIO_MAX: int = 1700

var radio: int = 530 :
	set(val):
		radio = clamp(val, RADIO_MIN, RADIO_MAX)
