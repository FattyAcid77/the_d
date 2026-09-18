class_name SoundBeds extends Node
## Layered music/ambience engine, child of Sound. One MusicSet per category
## playing all stems in sync; zones, flags, delays and dialog verbs decide
## which stems are up. Changes land on the bar.

signal layer_changed(category: String, layer: String, on: bool)
signal set_changed(category: String, set: MusicSet)

const SILENT_DB := -60.0
const ALIGN_NOW := 0
const ALIGN_BEAT := 1
const ALIGN_BAR := 2

## One running bed.
class Bed:
	var set: MusicSet
	var player: AudioStreamPlayer
	var sync: AudioStreamSynchronized
	var index := {}  # layer name -> stem index in the sync stream
	var current_db := {}  # layer name -> the db actually applied now
	var target_on := {}  # layer name -> bool, what the merge decided
	var pending := {}  # layer name -> bool, waiting for the bar
	var pending_align := ALIGN_BAR
	var tweens := {}  # layer name -> Tween
	var clock := 0.0  # seconds since the stems started
	var last_bar := -1
	var last_beat := -1
	var manual := {}  # layer name -> bool (dialog overrides)
	var base_layers: Array = []  # the mix play_set asked for (used when no zone)
	var ducked := false
	var dying := false

var _beds := {}  # "Music"/"Ambience" -> Bed
var _zones := {}  # category -> Array of zone Nodes, innermost last
var _delayed := {}  # zone -> {layer: seconds_left}
var _fired := {}  # zone -> Array of layer names already fired
var _snd: Node  # the Sound autoload (our parent)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snd = get_parent()
	_connect_flags.call_deferred()


func _connect_flags() -> void:
	var flags := get_node_or_null("/root/Flags")
	if flags and flags.has_signal("flag_changed"):
		flags.flag_changed.connect(_on_flag_changed)


func _process(delta: float) -> void:
	# delayed layers count down while their zone is the innermost one
	for zone in _delayed.keys():
		if not is_instance_valid(zone):
			_delayed.erase(zone)
			continue
		var cat := _zone_category(zone)
		if _innermost_zone(cat) != zone:
			continue
		var table: Dictionary = _delayed[zone]
		var fired_any := false
		for layer in table.keys():
			table[layer] -= delta
			if table[layer] <= 0.0:
				table.erase(layer)
				var f: Array = _fired.get(zone, [])
				f.append(layer)
				_fired[zone] = f
				fired_any = true
		if fired_any:
			_recompute(cat, _zone_align(zone))

	# the bar clock: apply pending changes on the boundary they wait for
	for cat in _beds.keys():
		var bed: Bed = _beds[cat]
		if bed.dying:
			continue
		bed.clock += delta
		var bar := bed.set.bar_seconds()
		var beat := bed.set.beat_seconds()
		var bar_i := int(floor(bed.clock / bar)) if bar > 0.0 else -1
		var beat_i := int(floor(bed.clock / beat)) if beat > 0.0 else -1
		var on_bar := bar_i != bed.last_bar
		var on_beat := beat_i != bed.last_beat
		bed.last_bar = bar_i
		bed.last_beat = beat_i
		if bed.pending.is_empty():
			continue
		var go := false
		match bed.pending_align:
			ALIGN_NOW: go = true
			ALIGN_BEAT: go = on_beat or beat <= 0.0
			_: go = on_bar or bar <= 0.0
		if go:
			_apply_pending(bed)


# --- public: sets -------------------------------------------------------------

## Start (or re-mix) a set.
func play_set(set: MusicSet, layers: Array = [], align: int = ALIGN_BAR,
		fade: float = -1.0) -> void:
	if set == null:
		return
	var cat := set.category
	var bed: Bed = _beds.get(cat)
	if bed and not bed.dying and bed.set == set:
		if not layers.is_empty():
			bed.base_layers = layers.duplicate()
		_recompute(cat, align)
		return
	if bed:
		_fade_out_bed(bed, fade if fade >= 0.0 else set.set_fade)
	_beds[cat] = _start_bed(set, layers)
	set_changed.emit(cat, set)
	_recompute(cat, ALIGN_NOW)  # the opening mix lands with the downbeat


func stop_set(category: String, fade: float = -1.0) -> void:
	var bed: Bed = _beds.get(category)
	if bed == null:
		return
	_fade_out_bed(bed, fade if fade >= 0.0 else bed.set.set_fade)
	_beds.erase(category)
	set_changed.emit(category, null)


func current_set(category: String) -> MusicSet:
	var bed: Bed = _beds.get(category)
	return bed.set if bed and not bed.dying else null


## Is this layer audible (or fading in) right now?
func is_layer_on(category: String, layer: String) -> bool:
	var bed: Bed = _beds.get(category)
	return bed != null and bool(bed.target_on.get(layer, false))


## Manual override from dialog / code.
func set_layer(category: String, layer: String, state, align: int = ALIGN_BAR) -> void:
	var bed: Bed = _beds.get(category)
	if bed == null:
		return
	if state == null:
		bed.manual.erase(layer)
	else:
		bed.manual[layer] = bool(state)
	_recompute(category, align)


# --- public: zones (MusicZone / AmbienceZone call these) -----------------------

func zone_enter(zone: Node) -> void:
	var set: MusicSet = zone.get("music_set")
	if set == null:
		return
	var cat := set.category
	var list: Array = _zones.get(cat, [])
	list.erase(zone)
	list.append(zone)
	_zones[cat] = list
	# arm the room's delayed layers from zero every time he walks in
	var d: Dictionary = zone.get("delayed_layers")
	if d and not d.is_empty():
		_delayed[zone] = d.duplicate()
	_fired[zone] = []
	play_set(set, zone.get("layers"), _zone_align(zone))


func zone_exit(zone: Node) -> void:
	var set: MusicSet = zone.get("music_set")
	var cat := set.category if set else ""
	_delayed.erase(zone)
	_fired.erase(zone)
	if cat == "":
		return
	var list: Array = _zones.get(cat, [])
	list.erase(zone)
	list = list.filter(func(z): return is_instance_valid(z))
	_zones[cat] = list
	var outer := _innermost_zone(cat)
	if outer:
		var oset: MusicSet = outer.get("music_set")
		play_set(oset, outer.get("layers"), _zone_align(outer))
	else:
		# no zone at all: the bed keeps playing its last mix
		_recompute(cat, _zone_align(zone))


# --- ducking --------------------------------------------------------------------

func duck(on: bool, duck_db: float, fade: float) -> void:
	for cat in _beds.keys():
		var bed: Bed = _beds[cat]
		if bed.dying or bed.ducked == on:
			continue
		bed.ducked = on
		for layer in bed.index.keys():
			var ml := bed.set.get_layer(layer)
			if ml and ml.ducks_in_dialog and bed.target_on.get(layer, false):
				_tween_layer(bed, layer, _on_db(bed, layer) + (duck_db if on else 0.0), fade)


## True if a layered bed is playing on this category
func has_bed(category: String) -> bool:
	var bed: Bed = _beds.get(category)
	return bed != null and not bed.dying


# --- internals ------------------------------------------------------------------

func _start_bed(set: MusicSet, layers: Array) -> Bed:
	var bed := Bed.new()
	bed.set = set
	bed.base_layers = layers.duplicate()
	bed.sync = AudioStreamSynchronized.new()
	var n := 0
	for ml in set.layers:
		if ml == null or ml.name == "":
			continue
		bed.index[ml.name] = n
		bed.sync.set_sync_stream(n, ml.stream)
		bed.sync.set_sync_stream_volume(n, SILENT_DB)
		bed.current_db[ml.name] = SILENT_DB
		bed.target_on[ml.name] = false
		n += 1
	bed.sync.stream_count = n
	bed.player = AudioStreamPlayer.new()
	bed.player.stream = bed.sync
	bed.player.bus = _snd._bus(set.category) if _snd and _snd.has_method("_bus") else set.category
	add_child(bed.player)
	if n > 0:
		bed.player.play()
	return bed


func _fade_out_bed(bed: Bed, fade: float) -> void:
	bed.dying = true
	for t in bed.tweens.values():
		if t and t.is_valid():
			t.kill()
	var tw := create_tween()
	tw.tween_property(bed.player, "volume_db", SILENT_DB, maxf(0.05, fade))
	tw.tween_callback(bed.player.queue_free)


## Merge the five sources into target_on, then queue the diff.
func _recompute(cat: String, align: int) -> void:
	var bed: Bed = _beds.get(cat)
	if bed == null or bed.dying:
		return
	var flags := get_node_or_null("/root/Flags")
	var zone := _innermost_zone(cat)
	# the room's mix when he's in a zone; otherwise whatever play_set asked for
	var base: Array = zone.get("layers") if zone else bed.base_layers
	var fired: Array = _fired.get(zone, []) if zone else []
	var zflags: Dictionary = zone.get("flag_layers") if zone else {}
	var changed := false
	for layer in bed.index.keys():
		var on := false
		if bed.manual.has(layer):
			on = bool(bed.manual[layer])
		else:
			var ml := bed.set.get_layer(layer)
			if zone == null and ml and ml.on_by_default:
				on = true
			if base.has(layer) or fired.has(layer):
				on = true
			if flags:
				if zflags.has(layer) and str(zflags[layer]) != "" \
						and flags.is_set(str(zflags[layer])):
					on = true
				if bed.set.flag_layers.has(layer) \
						and str(bed.set.flag_layers[layer]) != "" \
						and flags.is_set(str(bed.set.flag_layers[layer])):
					on = true
		if bool(bed.target_on.get(layer, false)) != on:
			bed.target_on[layer] = on
			bed.pending[layer] = on
			changed = true
		elif bed.pending.has(layer) and bed.pending[layer] != on:
			bed.pending.erase(layer)  # flipped back before the bar - cancel
	if not changed:
		return
	bed.pending_align = align
	if align == ALIGN_NOW or bed.set.bar_seconds() <= 0.0:
		_apply_pending(bed)


func _apply_pending(bed: Bed) -> void:
	for layer in bed.pending.keys():
		var on: bool = bed.pending[layer]
		var db := _on_db(bed, layer) if on else SILENT_DB
		var ml := bed.set.get_layer(layer)
		if on and bed.ducked and ml and ml.ducks_in_dialog and _snd:
			db += float(_snd.get("duck_db"))
		_tween_layer(bed, layer, db, bed.set.layer_fade)
		layer_changed.emit(bed.set.category, layer, on)
	bed.pending.clear()


func _on_db(bed: Bed, layer: String) -> float:
	var ml := bed.set.get_layer(layer)
	return ml.volume_db if ml else 0.0


func _tween_layer(bed: Bed, layer: String, to_db: float, fade: float) -> void:
	var old: Tween = bed.tweens.get(layer)
	if old and old.is_valid():
		old.kill()
	var idx: int = bed.index[layer]
	var tw := create_tween()
	tw.tween_method(func(v: float):
			bed.current_db[layer] = v
			if is_instance_valid(bed.sync):
				bed.sync.set_sync_stream_volume(idx, v),
		float(bed.current_db.get(layer, SILENT_DB)), to_db, maxf(0.01, fade))
	bed.tweens[layer] = tw


func _on_flag_changed(_flag: String, _value) -> void:
	for cat in _beds.keys():
		var zone := _innermost_zone(cat)
		_recompute(cat, _zone_align(zone) if zone else ALIGN_BAR)


func _innermost_zone(cat: String) -> Node:
	var list: Array = _zones.get(cat, [])
	for i in range(list.size() - 1, -1, -1):
		if is_instance_valid(list[i]):
			return list[i]
	return null


func _zone_category(zone: Node) -> String:
	var set: MusicSet = zone.get("music_set")
	return set.category if set else "Music"


func _zone_align(zone: Node) -> int:
	if zone == null:
		return ALIGN_BAR
	var a = zone.get("align")
	return int(a) if a != null else ALIGN_BAR
