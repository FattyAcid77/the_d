extends Node
## Loc - add as an Autoload named "Loc". Put it above every other autoload,
## because the language must be set before anything draws text.

signal language_changed(code: String)

const SETTINGS_PATH := "user://language.cfg"

## The languages the game offers.
const LANGUAGES := {
	"en": "English",
	"ar": "العربية",
}

## Locales that read right-to-left (used for the UI mirror).
const RTL_LANGUAGES := ["ar", "he", "fa", "ur"]

## Used until the player picks one.
@export var default_language: String = "en"

## Flip the whole UI for RTL languages (portraits, bars, buttons swap sides).
@export var mirror_ui: bool = true

## global off switch for the first-launch language chooser.
@export var first_launch_prompt: bool = true

## Prints what it's doing while you set this up.
@export var debug_log: bool = true

var _chosen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply(current(), false)


# --- reading ---------------------------------------------------------------

func current() -> String:
	var l := TranslationServer.get_locale()
	# locales arrive like "en_US" - we only care about the language part
	return l.split("_")[0]


func is_rtl(code: String = "") -> bool:
	var c: String = code if code != "" else current()
	return RTL_LANGUAGES.has(c)


## True the very first time the game runs, so you can show the chooser.
func needs_first_prompt() -> bool:
	return not _chosen


func language_name(code: String) -> String:
	return LANGUAGES.get(code, code)


func available() -> Array:
	return LANGUAGES.keys()


# --- switching -------------------------------------------------------------

func set_language(code: String, remember: bool = true) -> void:
	if not LANGUAGES.has(code):
		push_warning("Loc: unknown language '%s'." % code)
		return
	_apply(code, true)
	if remember:
		_chosen = true
		_save_settings()


func _apply(code: String, announce: bool) -> void:
	TranslationServer.set_locale(code)
	if mirror_ui:
		_apply_mirror(is_rtl(code))
	if debug_log:
		print("Loc: language = %s (%s)%s" % [code, language_name(code),
				", RTL mirror ON" if is_rtl(code) else ""])
	if announce:
		language_changed.emit(code)


## Flips container layouts for RTL languages.
func _apply_mirror(rtl: bool) -> void:
	var root := get_tree().root
	if root == null:
		return

	var dir := Control.LAYOUT_DIRECTION_RTL if rtl else Control.LAYOUT_DIRECTION_LTR

	# The root window, only if this Godot build actually accepts it.
	if root.has_method("set_layout_direction"):
		root.call("set_layout_direction", dir)

	# Every top-level Control gets told directly; their children inherit.
	for c in _top_controls(root):
		c.layout_direction = dir


## Controls whose parent is not a Control - the root of each UI tree.
func _top_controls(node: Node, out: Array[Control] = []) -> Array[Control]:
	for child in node.get_children():
		if child is Control:
			out.append(child)
			continue
		_top_controls(child, out)
	return out


# --- saving the choice -----------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		TranslationServer.set_locale(default_language)
		_chosen = false
		return
	_chosen = bool(cfg.get_value("language", "chosen", false))
	var code := str(cfg.get_value("language", "code", default_language))
	TranslationServer.set_locale(code if LANGUAGES.has(code) else default_language)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("language", "code", current())
	cfg.set_value("language", "chosen", _chosen)
	cfg.save(SETTINGS_PATH)


## Wipes the saved choice, so the first-launch prompt shows again (testing).
func forget_choice() -> void:
	_chosen = false
	_save_settings()
	if debug_log:
		print("Loc: choice forgotten — the prompt will show next launch.")
