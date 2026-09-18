class_name SoundLink
## Static glue. SoundLink.attach(self) in _ready turns a node's signals into
## SoundMap moments named Class.signal.

static func attach(node: Node, prefix: String = "") -> void:
	if node == null:
		return
	var snd := node.get_node_or_null("/root/Sound")
	if snd == null or not snd.has_method("attach"):
		return
	snd.attach(node, prefix)


## Play a resource's own sound if it has one, otherwise fire the map event.
static func play_or_event(sound_id: String, event_name: String, source: Node = null) -> void:
	if source == null:
		return
	var snd := source.get_node_or_null("/root/Sound")
	if snd == null:
		return
	if sound_id != "" and snd.has_method("play_from"):
		snd.play_from(sound_id, source)
	elif snd.has_method("event"):
		snd.event(event_name, source)


## Connect `callback` to `sig` on `obj` no matter how many arguments the signal carries.
static func connect_any_arity(obj: Object, sig: String, callback: Callable) -> bool:
	if obj == null or not obj.has_signal(sig):
		return false
	var argc := -1
	for s in obj.get_signal_list():
		if s["name"] == sig:
			argc = s["args"].size()
			break
	if argc < 0:
		return false
	var wrapped: Callable
	match argc:
		0: wrapped = func(): callback.call([])
		1: wrapped = func(a): callback.call([a])
		2: wrapped = func(a, b): callback.call([a, b])
		3: wrapped = func(a, b, c): callback.call([a, b, c])
		4: wrapped = func(a, b, c, d): callback.call([a, b, c, d])
		5: wrapped = func(a, b, c, d, e): callback.call([a, b, c, d, e])
		_: wrapped = func(a, b, c, d, e, f): callback.call([a, b, c, d, e, f])
	obj.connect(sig, wrapped)
	return true


## The signals declared by the node's own script
static func script_signals(node: Object) -> Array[String]:
	var out: Array[String] = []
	var script := node.get_script() as Script
	while script:
		for s in script.get_script_signal_list():
			var n := str(s["name"])
			if not out.has(n):
				out.append(n)
		script = script.get_base_script()
	return out


## "ElectroPuzzle" for a node whose script has that class_name; the node's own name as a fallback.
static func prefix_for(node: Node) -> String:
	var script := node.get_script() as Script
	if script:
		var g := script.get_global_name()
		if g != "":
			return g
	return node.name
