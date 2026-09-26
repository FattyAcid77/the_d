@tool
extends Node
## What the inspector parts share: the players that preview sounds and sets
## in the editor, and the one searchable pick list.

var library  # library.gd
var names  # names.gd
var playing_id := ""
var playing_set := ""
var _one: AudioStreamPlayer
var _stems := {}  # layer name -> AudioStreamPlayer
var _stem_db := {}  # layer name -> its volume when on
var _popup: PopupPanel
var _title: Label
var _filter: LineEdit
var _list: ItemList
var _foot: Label
var _rows: Array = []
var _on_pick: Callable


func _ready() -> void:
	_one = AudioStreamPlayer.new()
	add_child(_one)
	_one.finished.connect(func(): playing_id = "")
	_build_popup()


# --- preview ------------------------------------------------------------------

func play_sound(id: String) -> bool:
	stop()
	var s: Dictionary = library.sounds.get(id, {})
	if s.is_empty() or s.stream == null:
		return false
	_one.stream = s.stream
	_one.volume_db = s.volume_db
	var lo: float = s.pitch_min
	var hi: float = s.pitch_max
	_one.pitch_scale = maxf(0.01, randf_range(lo, hi) if hi > lo else lo)
	_one.play()
	playing_id = id
	return true


## Plays every stem at once so they stay in sync; the off ones sit silent.
func play_set(key: String, layers: Array, on: Array) -> void:
	stop()
	for l in layers:
		if l.stream == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = l.stream
		add_child(p)
		_stems[l.name] = p
		_stem_db[l.name] = l.volume_db
		p.volume_db = l.volume_db if on.has(l.name) else -80.0
	for p in _stems.values():
		p.play()
	playing_set = key


func set_layer(layer: String, on: bool) -> void:
	var p: AudioStreamPlayer = _stems.get(layer)
	if p:
		create_tween().tween_property(p, "volume_db", _stem_db[layer] if on else -80.0, 0.4)


func is_stem_audible(layer: String) -> bool:
	var p: AudioStreamPlayer = _stems.get(layer)
	return p != null and p.playing and p.volume_db > -79.0


func stop() -> void:
	_one.stop()
	playing_id = ""
	for p in _stems.values():
		p.queue_free()
	_stems.clear()
	_stem_db.clear()
	playing_set = ""


# --- the pick list -------------------------------------------------------------

## rows: [{id, note}]. on_pick(id) runs with the chosen id.
func pick(title: String, rows: Array, on_pick: Callable, empty_text := "") -> void:
	_rows = rows
	_on_pick = on_pick
	_title.text = title
	_filter.text = ""
	_fill("")
	_foot.text = empty_text if rows.is_empty() else "%d to choose from. Type to filter, click to pick." % rows.size()
	_popup.popup_centered(Vector2i(380, 440))
	_filter.grab_focus()


func is_picking() -> bool:
	return _popup.visible


## Picks the first row that matches, like a click on it.
func choose(id: String) -> bool:
	for i in _list.item_count:
		if _list.get_item_metadata(i) == id:
			_chosen(i)
			return true
	return false


func _build_popup() -> void:
	_popup = PopupPanel.new()
	add_child(_popup)
	var box := VBoxContainer.new()
	_popup.add_child(box)
	_title = Label.new()
	box.add_child(_title)
	_filter = LineEdit.new()
	_filter.placeholder_text = "filter"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(_fill)
	_filter.text_submitted.connect(func(_t): if _list.item_count > 0: _chosen(0))
	box.add_child(_filter)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(360, 360)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_clicked.connect(func(i, _p, _b): _chosen(i))
	box.add_child(_list)
	_foot = Label.new()
	_foot.modulate = Color(1, 1, 1, 0.6)
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.custom_minimum_size = Vector2(360, 0)  # wraps at the list's width instead of growing tall
	box.add_child(_foot)


func _fill(filter: String) -> void:
	_list.clear()
	var f := filter.strip_edges().to_lower()
	for r in _rows:
		if f != "" and not str(r.id).to_lower().contains(f) and not str(r.note).to_lower().contains(f):
			continue
		var i := _list.add_item("%s     %s" % [r.id, r.note])
		_list.set_item_metadata(i, r.id)


func _chosen(i: int) -> void:
	var id: String = _list.get_item_metadata(i)
	_popup.hide()
	if _on_pick.is_valid():
		_on_pick.call(id)
