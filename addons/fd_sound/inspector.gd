@tool
extends EditorInspectorPlugin
## Decides which inspector fields get the sound tools.
##   sound_id, *_sound_id, music_id  -> SoundDef picker (SoundField)
##   MusicZone / AmbienceZone layers -> checkboxes from its music_set (ZoneLayers)
##   a MusicSet .tres                -> stem preview on top (SetPreview)
##   a dialog line or action's args  -> pick row for sound, music and set verbs (ArgPicker)
##   a SoundHook's hooks             -> table of signal/animation -> sound (HookTable)
##   *_flag fields                   -> flag picker with set/read marks (NameField)
##   *_flags lists                   -> one flag picker per entry (FlagList)
##   death cause, item, window, room, state fields -> id picker (NameField)

const Library := preload("library.gd")
const SoundField := preload("sound_field.gd")
const ZoneLayers := preload("zone_layers.gd")
const SetPreview := preload("set_preview.gd")
const ArgPicker := preload("arg_picker.gd")
const HookTable := preload("hook_table.gd")
const Names := preload("names.gd")
const NameField := preload("name_field.gd")
const FlagList := preload("flag_list.gd")

var tools  # tools.gd


func _can_handle(object: Object) -> bool:
	return object is Node or object is Resource


func _parse_begin(object: Object) -> void:
	if Library.is_a(object, "MusicSet"):
		add_custom_control(SetPreview.new(object, tools))


func _parse_property(object: Object, type: Variant.Type, name: String,
		_hint: PropertyHint, _hint_text: String, _usage: int, _wide: bool) -> bool:
	if type == TYPE_STRING and (name == "sound_id" or name.ends_with("_sound_id") or name == "music_id"):
		add_property_editor(name, SoundField.new(tools, name == "music_id"))
		return true
	# names only on our own scripts, never on engine classes
	if object.get_script() != null:
		var role := Names.flag_role(name)
		if type == TYPE_STRING and role != "":
			add_property_editor(name, NameField.new(tools, "flag:" + role))
			return true
		if type == TYPE_ARRAY and role != "":
			var v = object.get(name)
			if v is Array and (v as Array).get_typed_builtin() == TYPE_STRING:
				add_property_editor(name, FlagList.new(tools, "flag:" + role))
				return true
		var kind := Names.id_kind(name)
		if type == TYPE_STRING and kind != "":
			add_property_editor(name, NameField.new(tools, kind))
			return true
	if name == "hooks" and Library.is_a(object, "SoundHook"):
		add_property_editor(name, HookTable.new(tools))
		return true
	if name == "layers" and Library.is_a(object, "MusicZone"):
		add_property_editor(name, ZoneLayers.new(tools))
		return true
	if name == "action_args" and Library.is_a(object, "DialogLine"):
		add_custom_control(ArgPicker.new(object, "action_name", "action_args", tools))
	elif name == "args" and Library.is_a(object, "DialogActionStep"):
		add_custom_control(ArgPicker.new(object, "action", "args", tools))
	return false
