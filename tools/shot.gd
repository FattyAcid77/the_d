extends SceneTree
## Screenshot tool. Loads a scene, lets it settle, saves a PNG, quits.
##
##   godot --path <project> --script res://tools/shot.gd -- <scene> <out.png> [frames]
##
## Nothing in the game uses this - it is only run from the command line.

var _left: int = 90
var _out: String = ""


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("need: <scene path> <output png> [frames]")
		quit(1)
		return
	_out = args[1]
	if args.size() > 2:
		_left = int(args[2])
	var packed: PackedScene = load(args[0])
	if packed == null:
		printerr("could not load ", args[0])
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_left -= 1
	if _left > 0:
		return false
	var img: Image = root.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out, "  ", img.get_width(), "x", img.get_height())
	return true
