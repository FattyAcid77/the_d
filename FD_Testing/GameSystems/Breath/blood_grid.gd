@tool
class_name BloodGrid extends Node2D
## The floor puzzle: a grid of cells that each want a specific blood type.
## Bleed the right type onto the right cell and the puzzle solves.
##
## SETUP
##   1. Drop this node where the top-left of the grid should be.
##   2. Set `columns`, `rows` and `cell_size` — it draws itself in the editor
##      so you can line it up with your tiles exactly.
##   3. Fill `wanted` with one blood-type id per cell, reading left-to-right,
##      top-to-bottom. Use "" for cells that don't care.
##      Example for a 3x3 where only the middle row matters:
##         ["", "", "", "A", "B", "A", "", "", ""]
##   4. Set `solved_flag` — raised when the pattern is complete.
##
## Cells remember the LAST blood spilled on them, so a mistake can be
## covered by bleeding the correct type on top (unless `lock_cells` is on).

signal cell_stained(index: int, type_id: String)
signal solved

@export var columns: int = 3:
	set(v):
		columns = maxi(1, v)
		_resize_arrays()
		queue_redraw()
@export var rows: int = 3:
	set(v):
		rows = maxi(1, v)
		_resize_arrays()
		queue_redraw()
@export var cell_size := Vector2(32, 32):
	set(v):
		cell_size = v
		queue_redraw()

## One blood-type id per cell (row by row). "" = this cell is ignored.
@export var wanted: Array[String] = []:
	set(v):
		wanted = v
		_resize_arrays()
		queue_redraw()

## Once a cell has the right blood, it can't be changed.
@export var lock_cells: bool = false

## Flag raised when every wanted cell holds its type.
@export var solved_flag: String = "blood_puzzle_solved"

## Prints every hit to the Output panel: which cell, what landed, what it
## wanted. Turn this ON while building a puzzle.
@export var debug_log: bool = true

## ON = blood only "sticks" on cells that actually want blood; anything
## else fades away. OFF = any cell in the grid keeps its stain.
@export var keep_only_on_wanted: bool = false

@export_group("Editor look")
@export var show_grid_in_game: bool = false
@export var grid_color := Color(1, 1, 1, 0.15)
@export var wanted_color := Color(0.9, 0.3, 0.3, 0.35)

var current: Array[String] = []
var _is_solved := false


func _ready() -> void:
	_resize_arrays()
	if Engine.is_editor_hint():
		return
	BloodWorld.register_grid(self)
	if Flags.is_set(solved_flag):
		_is_solved = true


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		BloodWorld.unregister_grid(self)


func _resize_arrays() -> void:
	var total := columns * rows
	while wanted.size() < total:
		wanted.append("")
	while wanted.size() > total:
		wanted.remove_at(wanted.size() - 1)
	current.resize(total)
	for i in total:
		if current[i] == null:
			current[i] = ""


## World position -> cell index, or -1 if outside the grid.
func cell_at(world_pos: Vector2) -> int:
	var local := to_local(world_pos)
	if local.x < 0 or local.y < 0:
		return -1
	var cx := int(local.x / cell_size.x)
	var cy := int(local.y / cell_size.y)
	if cx < 0 or cx >= columns or cy < 0 or cy >= rows:
		return -1
	return cy * columns + cx


## Called by BloodWorld whenever blood lands anywhere.
## Returns TRUE if the blood landed on this grid (so it should stay).
func stain_at(world_pos: Vector2, type: BloodType) -> bool:
	var idx := cell_at(world_pos)
	if idx < 0:
		if debug_log:
			print("BloodGrid '%s': blood at %s is OUTSIDE the grid." % [name, world_pos])
		return false
	if _is_solved and lock_cells:
		return true
	if lock_cells and current[idx] != "" and current[idx] == wanted[idx]:
		return true                 # already correct and locked
	current[idx] = type.id
	cell_stained.emit(idx, type.id)
	queue_redraw()
	if debug_log:
		var want: String = wanted[idx] if idx < wanted.size() else ""
		var cx: int = idx % columns
		@warning_ignore("integer_division") # row index - discarding the remainder is the point
		var cy: int = idx / columns
		print("BloodGrid '%s': cell %d (col %d, row %d) got '%s' — wants '%s' %s"
				% [name, idx, cx, cy, type.id, want,
				"OK" if want == type.id else ("(ignored cell)" if want == "" else "WRONG")])
	_check()
	if keep_only_on_wanted:
		return idx < wanted.size() and wanted[idx] != ""
	return true


## Wipe the grid (a mop, a cutscene, a reset lever...).
func clear_grid() -> void:
	for i in current.size():
		current[i] = ""
	_is_solved = false
	queue_redraw()


func is_solved() -> bool:
	return _is_solved


func _check() -> void:
	if _is_solved:
		return
	for i in wanted.size():
		if wanted[i] == "":
			continue                # this cell doesn't matter
		if current[i] != wanted[i]:
			return
	_is_solved = true
	Flags.set_flag(solved_flag)
	solved.emit()
	print("BLOOD PUZZLE SOLVED — grid '%s' complete, flag '%s' raised."
			% [name, solved_flag])


func _draw() -> void:
	if not Engine.is_editor_hint() and not show_grid_in_game:
		return
	for y in rows:
		for x in columns:
			var r := Rect2(Vector2(x * cell_size.x, y * cell_size.y), cell_size)
			draw_rect(r, grid_color, false, 1.0)
			var i := y * columns + x
			if i < wanted.size() and wanted[i] != "":
				draw_rect(r.grow(-2), wanted_color, true)
				var f := ThemeDB.fallback_font
				if f:
					draw_string(f, r.position + Vector2(4, 14), wanted[i],
							HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
