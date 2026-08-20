@tool
extends EditorScript
## TRANSLATION AUDIT — the safety net for the English-as-key approach.
##
## Because the English text IS the key, editing an English line breaks its
## Arabic link until the CSV is updated. This finds those breaks.
##
## HOW TO RUN IT
##   1. Open this file in Godot's script editor
##   2. File > Run  (or Ctrl+Shift+X)
##   3. Read the Output panel
##
## It reports:
##   MISSING    — text in your .tres files that isn't in the CSV at all
##                (usually a line you edited or a new one you wrote)
##   UNTRANSLATED — in the CSV but with an empty Arabic column
##   UNUSED     — in the CSV but no longer anywhere in the game
##                (usually the OLD version of a line you edited)
##
## A MISSING and an UNUSED that look similar = the same line, edited.
## Copy the Arabic from the unused row to the new one.

const CSV_PATH := "res://FD_Testing/GameSystems/Localization/translations.csv"
const SCAN_DIR := "res://FD_Testing/GameSystems"

## Fields that hold player-visible text. `spoken` is NOT here — those are
## the statue's puzzle numbers, and must never be translated.
const TEXT_FIELDS := ["text", "label", "note", "title", "display_name",
		"effect", "result_title", "result_text", "board_title", "topic_label"]

## Folders whose strings are DATA, not text.
const SKIP := ["Prescription"]


func _run() -> void:
	var csv := _read_csv()
	if csv.is_empty():
		print("AUDIT: couldn't read %s" % CSV_PATH)
		return
	var in_game := _scan_resources()

	var missing: Array[String] = []
	var untranslated: Array[String] = []
	for s in in_game:
		if not csv.has(s):
			missing.append(s)
		elif str(csv[s]).strip_edges() == "":
			untranslated.append(s)

	var unused: Array[String] = []
	for k in csv.keys():
		if not in_game.has(k):
			unused.append(k)

	print("\n======== TRANSLATION AUDIT ========")
	print("strings in game : %d" % in_game.size())
	print("rows in CSV     : %d" % csv.size())

	print("\n-- MISSING from the CSV (%d) --" % missing.size())
	for s in missing:
		print("   %s" % s)

	print("\n-- UNTRANSLATED, Arabic column empty (%d) --" % untranslated.size())
	for s in untranslated:
		print("   %s" % s)

	print("\n-- UNUSED, in CSV but not in the game (%d) --" % unused.size())
	for s in unused:
		print("   %s" % s)

	if missing.is_empty() and untranslated.is_empty():
		print("\nAll good — every string is in the CSV and translated.")
	print("===================================\n")


func _read_csv() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	var header := f.get_csv_line()      # keys, en, ar, ...
	var ar_col := 2
	for i in header.size():
		if header[i].strip_edges().to_lower() == "ar":
			ar_col = i
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 0 or row[0].strip_edges() == "":
			continue
		out[row[0]] = row[ar_col] if row.size() > ar_col else ""
	return out


func _scan_resources() -> Dictionary:
	var found := {}
	_scan_dir(SCAN_DIR, found)
	return found


func _scan_dir(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path + "/" + name
		if dir.current_is_dir():
			if not SKIP.has(name) and not name.begins_with("."):
				_scan_dir(full, found)
		elif name.get_extension() == "tres":
			_scan_file(full, found)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, found: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line()
		for field in TEXT_FIELDS:
			var prefix: String = str(field) + " = \""
			if line.begins_with(prefix):
				var v: String = line.substr(prefix.length())
				v = v.substr(0, v.rfind("\""))
				v = v.strip_edges()
				# skip pure numbers — puzzle data, not text
				if v != "" and not v.is_valid_int() and not _is_number_list(v):
					found[v] = true


func _is_number_list(s: String) -> bool:
	for part in s.split(" ", false):
		if not part.is_valid_int():
			return false
	return true
