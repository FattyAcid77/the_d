class_name LanguageSetting extends HBoxContainer
## Drop this into your settings menu and it just works.
## It builds a label + a dropdown listing every language in Loc.LANGUAGES,
## shows the current one, and saves the choice when it changes.
##
## No setup needed — add the node, attach this script, done.

## The word next to the dropdown ("Language"). It's translated too.
@export var label_text: String = "Language"
@export var label_min_width: float = 140.0

var _label: Label
var _options: OptionButton
var _codes: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 12)

	_label = Label.new()
	_label.text = tr(label_text)
	_label.custom_minimum_size.x = label_min_width
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)

	_options = OptionButton.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_options)

	_fill()
	_options.item_selected.connect(_on_selected)
	Loc.language_changed.connect(_on_language_changed)


func _fill() -> void:
	_options.clear()
	_codes.clear()
	var current := Loc.current()
	var i := 0
	for code in Loc.available():
		_options.add_item(Loc.language_name(code))
		_codes.append(code)
		if code == current:
			_options.select(i)
		i += 1


func _on_selected(index: int) -> void:
	if index < 0 or index >= _codes.size():
		return
	Loc.set_language(str(_codes[index]))


func _on_language_changed(_code: String) -> void:
	# the dropdown's own words change with the language
	_label.text = tr(label_text)
	_fill()
