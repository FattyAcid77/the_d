class_name BoardInventory extends Control
## The INVENTORY tab: Sami on the left with everything he's carrying drawn
## on him, the grid on the right, and USE / DROP underneath.
##
## THE AVATAR
## Every item's `avatar_layer` is authored on the same 640x360 canvas as the
## base Sami, so this just draws them all at (0,0) in `avatar_order` and they
## land exactly where you drew them. The axe goes on his back because that's
## where you painted it. Carrying three bandages draws one bandage.
##
## THE TOOLTIP
## Hovering a slot pops the item's name and description next to the mouse.

## The panel art loads itself, for the same reason the board's does: this is
## built in code by the Board autoload, so there's no Inspector to drag a
## texture into.
const PANEL_PATH := "res://FD_Testing/GameSystems/Board/Art/inventory.png"

## Sami's base body, the empty grid, USE and DROP. Loaded automatically.
var panel_art: Texture2D

@export_group("The small slots (4 across, 3 down)")
## Top-left corner of the FIRST small slot, in canvas pixels.
@export var grid_origin: Vector2 = Vector2(326, 131)
@export var slot_size: Vector2 = Vector2(17, 16)
@export var slot_gap: Vector2 = Vector2(1, 3)
## How big an item's icon is drawn inside a small slot.
@export var icon_size: float = 13.0

@export_group("The two big slots")
## Top-left of the FIRST big slot.
@export var big_origin: Vector2 = Vector2(326, 190)
@export var big_size: Vector2 = Vector2(35, 35)
@export var big_gap: float = 1.5
## Icons in the big slots are drawn larger.
@export var big_icon_size: float = 28.0

@export_group("The stack number")
## The little count in the bottom-right of a slot, e.g. a "5" on five bandages.
@export var show_counts: bool = true
@export var count_font_size: int = 8
@export var count_color: Color = Color(0.97, 0.95, 0.88)
## A dark plate behind the number so it reads on any icon.
@export var count_plate: Color = Color(0.12, 0.10, 0.08, 0.85)
@export var count_plate_pad: Vector2 = Vector2(2, 1)
## Hide the number when there is only one. OFF shows "1" on everything.
@export var hide_count_when_one: bool = true

@export_group("Selection")
@export var selected_color: Color = Color(1, 0.95, 0.6, 0.45)
@export var hover_color: Color = Color(1, 1, 1, 0.18)

@export_group("The buttons")
## Clickable areas for USE and DROP, in canvas pixels, matching your art.
@export var use_rect: Rect2 = Rect2(324, 245, 35, 14)
@export var drop_rect: Rect2 = Rect2(365, 245, 35, 14)
@export var button_press_tint: Color = Color(1, 1, 1, 0.25)

@export_group("The tooltip")
@export var tooltip_bg: Color = Color(0.09, 0.08, 0.07, 0.95)
@export var tooltip_border: Color = Color(0.75, 0.7, 0.55, 0.9)
@export var tooltip_text_color: Color = Color(0.95, 0.93, 0.85)
@export var tooltip_name_size: int = 8
@export var tooltip_desc_size: int = 7
@export var tooltip_width: float = 108.0
@export var tooltip_offset: Vector2 = Vector2(9, 7)
@export var tooltip_font: Font

@export_group("Dragging")
## Drag items from slot to slot to rearrange them. Dropping onto a full slot
## swaps the two; dropping onto the same kind merges the stacks.
@export var can_drag_items: bool = true
## How far the mouse must move before it counts as a drag and not a click.
@export var drag_threshold: float = 3.0
## The icon follows the mouse at this size while being carried.
@export var drag_icon_size: float = 14.0
@export var drag_icon_alpha: float = 0.85

@export_group("Debug")
## Outline every slot and button so you can line them up with the art.
@export var show_layout: bool = false

var selected: int = -1
var _hover: int = -1
var _mouse := Vector2.ZERO
var _pressed := ""
var _drag_from: int = -1        ## slot being dragged out of
var _drag_item: MedicalItem
var _drag_count: int = 0
var _dragging := false


func _ready() -> void:
	# Sized to the 640x360 art canvas, NOT the viewport. The Board scales and
	# centres the canvas, so drawing and mouse coordinates are both in plain
	# art pixels — which is what makes the slots clickable at any resolution.
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(PANEL_PATH):
		panel_art = load(PANEL_PATH) as Texture2D
	else:
		push_error("BoardInventory: missing %s" % PANEL_PATH)
	var bag := get_node_or_null("/root/Bag")
	if bag:
		bag.changed.connect(refresh)


func refresh() -> void:
	var bag := get_node_or_null("/root/Bag")
	if bag and (selected < 0 or bag.is_empty_slot(selected)):
		selected = -1
	queue_redraw()


# --- where the slots are ---------------------------------------------------

## Where slot `i` sits, in art coordinates. The first columns*rows are the
## small ones; anything after that is one of the big slots along the bottom.
func slot_rect(i: int) -> Rect2:
	var bag := get_node_or_null("/root/Bag")
	var cols: int = int(bag.columns) if bag else 4
	var small: int = int(bag.small_count()) if bag else 12

	if i >= small:
		var b: int = i - small
		return Rect2(big_origin + Vector2(float(b) * (big_size.x + big_gap), 0.0),
				big_size)

	var x: int = i % cols
	var y: int = i / cols
	return Rect2(grid_origin + Vector2(x, y) * (slot_size + slot_gap), slot_size)


## Icons are bigger in the big slots.
func icon_size_for(i: int) -> float:
	var bag := get_node_or_null("/root/Bag")
	if bag and bag.is_big_slot(i):
		return big_icon_size
	return icon_size


func slot_at(pos: Vector2) -> int:
	var bag := get_node_or_null("/root/Bag")
	if bag == null:
		return -1
	for i in bag.slot_count():
		if slot_rect(i).has_point(pos):
			return i
	return -1


# --- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		_hover = slot_at(_mouse)
		# a press that has moved far enough becomes a drag
		if _drag_from >= 0 and not _dragging \
				and event.velocity.length() > 0.0 \
				and slot_rect(_drag_from).grow(drag_threshold).has_point(_mouse) == false:
			_dragging = true
		queue_redraw()              # the tooltip follows the mouse
		return

	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var bag := get_node_or_null("/root/Bag")
	if bag == null:
		return

	# --- letting go ---
	if not event.pressed:
		if _dragging:
			_drop_on(slot_at(event.position), bag)
		_dragging = false
		_drag_from = -1
		_drag_item = null
		if _pressed != "":
			_pressed = ""
		queue_redraw()
		accept_event()
		return

	# --- pressing down ---
	var i: int = slot_at(event.position)
	if i >= 0:
		selected = i if not bag.is_empty_slot(i) else -1
		if can_drag_items and not bag.is_empty_slot(i):
			_drag_from = i
			_drag_item = bag.item_at(i)
			_drag_count = bag.count_at(i)
		queue_redraw()
		accept_event()
		return

	if use_rect.has_point(event.position):
		_pressed = "use"
		if selected >= 0:
			bag.use_slot(selected)
		queue_redraw()
		accept_event()
	elif drop_rect.has_point(event.position):
		_pressed = "drop"
		if selected >= 0:
			bag.drop_slot(selected)
		queue_redraw()
		accept_event()


## Where a dragged item lands. Same slot = nothing. Empty = move.
## Same kind = merge the stacks. Different = swap the two slots.
func _drop_on(to: int, bag: Node) -> void:
	if to < 0 or _drag_from < 0 or to == _drag_from:
		return
	var from_slot = bag.slots[_drag_from]
	var to_slot = bag.slots[to]
	if from_slot == null:
		return

	if to_slot == null:
		bag.slots[to] = from_slot
		bag.slots[_drag_from] = null
	elif to_slot["item"] and from_slot["item"] \
			and to_slot["item"].type == from_slot["item"].type:
		var cap: int = maxi(1, int(to_slot["item"].max_stack))
		var space: int = cap - int(to_slot["count"])
		var move: int = mini(space, int(from_slot["count"]))
		if move > 0:
			to_slot["count"] = int(to_slot["count"]) + move
			from_slot["count"] = int(from_slot["count"]) - move
			if int(from_slot["count"]) <= 0:
				bag.slots[_drag_from] = null
		else:
			bag.slots[to] = from_slot
			bag.slots[_drag_from] = to_slot
	else:
		bag.slots[to] = from_slot
		bag.slots[_drag_from] = to_slot

	selected = to
	bag.changed.emit()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	var bag := get_node_or_null("/root/Bag")

	if panel_art:
		draw_texture(panel_art, Vector2.ZERO)

	# THE PAPERDOLL: every kind of item he holds, drawn where you painted it
	if bag:
		for item in bag.unique_items():
			if item.avatar_layer:
				draw_texture(item.avatar_layer, Vector2.ZERO)

	if bag == null:
		return

	# the grid
	for i in bag.slot_count():
		var r := slot_rect(i)
		if i == selected:
			draw_rect(r, selected_color, true)
		elif i == _hover:
			draw_rect(r, hover_color, true)
		if show_layout:
			draw_rect(r, Color(0, 1, 0, 0.8), false, 1.0)

		if _dragging and i == _drag_from:
			continue                    # it's on the mouse right now
		var item: MedicalItem = bag.item_at(i)
		if item == null or item.texture == null:
			continue
		var isz := icon_size_for(i)
		var icon := Rect2(r.position + (r.size - Vector2(isz, isz)) * 0.5,
				Vector2(isz, isz))
		draw_texture_rect(item.texture, icon, false)

		var n: int = bag.count_at(i)
		if show_counts and (n > 1 or not hide_count_when_one):
			_draw_count(r, n)

	if show_layout:
		draw_rect(use_rect, Color(1, 0.5, 0, 0.9), false, 1.0)
		draw_rect(drop_rect, Color(1, 0.5, 0, 0.9), false, 1.0)

	if _pressed == "use":
		draw_rect(use_rect, button_press_tint, true)
	elif _pressed == "drop":
		draw_rect(drop_rect, button_press_tint, true)

	# the carried item follows the mouse
	if _dragging and _drag_item and _drag_item.texture:
		var d := Rect2(_mouse - Vector2(drag_icon_size, drag_icon_size) * 0.5,
				Vector2(drag_icon_size, drag_icon_size))
		draw_texture_rect(_drag_item.texture, d, false,
				Color(1, 1, 1, drag_icon_alpha))
		if _hover >= 0:
			draw_rect(slot_rect(_hover), Color(1, 1, 1, 0.30), false, 1.0)
	elif _hover >= 0:
		_draw_tooltip(bag.item_at(_hover))


## The little stack number, tucked into the slot's bottom-right on a dark
## plate so it stays readable on top of any icon.
func _draw_count(slot: Rect2, n: int) -> void:
	var f := tooltip_font if tooltip_font else ThemeDB.fallback_font
	var txt := str(n)
	var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, count_font_size)
	var plate := Rect2(
			slot.position + slot.size - sz - count_plate_pad * 2.0 - Vector2(1, 1),
			sz + count_plate_pad * 2.0)
	draw_rect(plate, count_plate, true)
	draw_string(f, plate.position + count_plate_pad + Vector2(0, sz.y * 0.78),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, count_font_size, count_color)


## The hover pop-up: name on top, description under it, next to the mouse
## and nudged back on screen if it would run off the edge.
func _draw_tooltip(item: MedicalItem) -> void:
	if item == null:
		return
	var f := tooltip_font if tooltip_font else ThemeDB.fallback_font
	var name_text := tr(item.display_name)
	var desc := tr(item.tooltip_text())

	var pad := Vector2(4, 3)
	var name_h := float(tooltip_name_size) + 2.0
	var desc_h := 0.0
	var lines: PackedStringArray = []
	if desc.strip_edges() != "":
		lines = _wrap(f, desc, tooltip_width - pad.x * 2.0)
		desc_h = lines.size() * (float(tooltip_desc_size) + 2.0) + 2.0

	var box := Rect2(_mouse + tooltip_offset,
			Vector2(tooltip_width, name_h + desc_h + pad.y * 2.0))

	# keep it on the 640x360 canvas
	if box.position.x + box.size.x > 636.0:
		box.position.x = _mouse.x - box.size.x - tooltip_offset.x
	if box.position.y + box.size.y > 356.0:
		box.position.y = 356.0 - box.size.y

	draw_rect(box, tooltip_bg, true)
	draw_rect(box, tooltip_border, false, 1.0)

	var at := box.position + pad + Vector2(0, float(tooltip_name_size))
	draw_string(f, at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			tooltip_name_size, tooltip_text_color)
	at.y += name_h
	for l in lines:
		at.y += float(tooltip_desc_size) + 2.0
		draw_string(f, at, l, HORIZONTAL_ALIGNMENT_LEFT, -1,
				tooltip_desc_size, Color(tooltip_text_color, 0.8))


func _wrap(f: Font, text: String, width: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var test := word if line == "" else line + " " + word
		if f.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1,
				tooltip_desc_size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
