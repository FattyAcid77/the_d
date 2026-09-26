class_name GifDecoder extends RefCounted
## Reads a .gif in plain GDScript, because Godot can't. Every frame comes out
## as a full RGBA image with its delay: local palettes, transparency,
## interlacing and the three disposal methods are handled. Thread safe.


static func is_gif(bytes: PackedByteArray) -> bool:
	return bytes.size() >= 13 and bytes.slice(0, 4).get_string_from_ascii() == "GIF8"


## {"frames": Array[Image], "delays": PackedFloat32Array (seconds), "size": Vector2i},
## or {} when the bytes aren't a readable gif. Stops early at max_frames or
## once max_pixels have been decoded; wider than max_width is scaled down.
## Set stop[0] = true from another thread to give up halfway.
static func decode(bytes: PackedByteArray, max_frames: int = 240, max_width: int = 960,
		max_pixels: int = 30000000, stop: Array = []) -> Dictionary:
	if not is_gif(bytes):
		return {}
	var w := bytes.decode_u16(6)
	var h := bytes.decode_u16(8)
	if w <= 0 or h <= 0 or w > 4096 or h > 4096:
		return {}
	var pos := 13
	var global_pal := PackedInt32Array()
	if bytes[10] & 0x80:
		var n := 2 << (bytes[10] & 7)
		global_pal = _palette(bytes, pos, n)
		pos += n * 3
	var limit := mini(max_frames, maxi(1, max_pixels / (w * h)))

	var canvas := PackedInt32Array()
	canvas.resize(w * h)
	var saved := PackedInt32Array()
	var frames: Array[Image] = []
	var delays := PackedFloat32Array()
	var disposal := 0
	var delay_cs := 0
	var trans := -1
	var last_disposal := 0
	var last_rect := Rect2i()
	var size := bytes.size()

	while pos < size and frames.size() < limit:
		if not stop.is_empty() and stop[0]:
			return {}
		var block := bytes[pos]
		pos += 1
		if block == 0x3B:
			break
		if block == 0x21:
			if pos >= size:
				break
			var label := bytes[pos]
			pos += 1
			# graphic control: disposal, delay and the transparent colour of the next image
			if label == 0xF9 and pos + 5 <= size and bytes[pos] >= 4:
				var flags := bytes[pos + 1]
				disposal = (flags >> 2) & 7
				delay_cs = bytes.decode_u16(pos + 2)
				trans = bytes[pos + 4] if flags & 1 else -1
			pos = _skip_blocks(bytes, pos)
			continue
		if block != 0x2C or pos + 10 > size:
			break

		var rect := Rect2i(bytes.decode_u16(pos), bytes.decode_u16(pos + 2),
				bytes.decode_u16(pos + 4), bytes.decode_u16(pos + 6))
		var flags := bytes[pos + 8]
		pos += 9
		var pal := global_pal
		if flags & 0x80:
			var n := 2 << (flags & 7)
			if pos + n * 3 > size:
				break
			pal = _palette(bytes, pos, n)
			pos += n * 3
		var min_code := bytes[pos]
		var read := _read_blocks(bytes, pos + 1)
		pos = read[1]

		# undo the previous frame the way it asked to be undone
		if last_disposal == 2:
			_clear(canvas, w, h, last_rect)
		elif last_disposal == 3 and not saved.is_empty():
			canvas = saved.duplicate()
		if disposal == 3:
			saved = canvas.duplicate()

		if rect.size.x > 0 and rect.size.y > 0 and not pal.is_empty() and min_code >= 1 and min_code <= 11:
			var index := _lzw(read[0], min_code, rect.size.x * rect.size.y)
			_draw(canvas, w, h, index, pal, rect, trans, flags & 0x40 != 0)

		var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, canvas.to_byte_array())
		if w > max_width:
			img.resize(max_width, maxi(1, roundi(h * max_width / float(w))), Image.INTERPOLATE_BILINEAR)
		frames.append(img)
		# browsers play 0 and 1 hundredths as 10, and so do the gifs made for them
		delays.append((delay_cs if delay_cs >= 2 else 10) / 100.0)
		last_disposal = disposal
		last_rect = rect
		disposal = 0
		delay_cs = 0
		trans = -1

	if frames.is_empty():
		return {}
	return {"frames": frames, "delays": delays, "size": Vector2i(frames[0].get_width(), frames[0].get_height())}


## Colours packed as ints whose bytes are R G B A, so a whole row of them turns
## into image data with one to_byte_array().
static func _palette(bytes: PackedByteArray, at: int, count: int) -> PackedInt32Array:
	var pal := PackedInt32Array()
	pal.resize(count)
	for i in count:
		var o := at + i * 3
		if o + 2 >= bytes.size():
			break
		pal[i] = bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16) | (0xFF << 24)
	return pal


static func _skip_blocks(bytes: PackedByteArray, pos: int) -> int:
	while pos < bytes.size():
		var n := bytes[pos]
		pos += 1 + n
		if n == 0:
			break
	return pos


## The image data is split in sub-blocks of up to 255 bytes. Returns [data, next_pos].
static func _read_blocks(bytes: PackedByteArray, pos: int) -> Array:
	var data := PackedByteArray()
	while pos < bytes.size():
		var n := bytes[pos]
		pos += 1
		if n == 0:
			break
		data.append_array(bytes.slice(pos, pos + n))
		pos += n
	return [data, pos]


## Variable-width LZW, straight to palette indices.
static func _lzw(data: PackedByteArray, min_size: int, count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(count)
	var prefix := PackedInt32Array()
	prefix.resize(4096)
	var suffix := PackedByteArray()
	suffix.resize(4096)
	var head := PackedByteArray()
	head.resize(4096)
	var length := PackedInt32Array()
	length.resize(4096)
	var clear := 1 << min_size
	for i in clear:
		prefix[i] = -1
		suffix[i] = i & 0xFF
		head[i] = i & 0xFF
		length[i] = 1

	var code_size := min_size + 1
	var mask := (1 << code_size) - 1
	var next := clear + 2
	var prev := -1
	var at := 0
	var bits := 0
	var nbits := 0
	var i := 0
	var n := data.size()
	while at < count:
		while nbits < code_size:
			if i >= n:
				return out
			bits |= data[i] << nbits
			nbits += 8
			i += 1
		var code := bits & mask
		bits >>= code_size
		nbits -= code_size

		if code == clear:
			code_size = min_size + 1
			mask = (1 << code_size) - 1
			next = clear + 2
			prev = -1
			continue
		if code == clear + 1:
			break
		if prev < 0:
			if code > clear:
				break
			out[at] = suffix[code]
			at += 1
			prev = code
			continue

		# a code one past the table is the previous string plus its own first byte
		var emit := code
		var tail := -1
		if code >= next:
			if code > next:
				break
			emit = prev
			tail = head[prev]
		var end := at + length[emit]
		var p := end - 1
		var c := emit
		while c >= 0:
			if p < count:
				out[p] = suffix[c]
			p -= 1
			c = prefix[c]
		at = end
		if tail >= 0:
			if at < count:
				out[at] = tail
			at += 1

		if next < 4096:
			prefix[next] = prev
			suffix[next] = head[emit]
			head[next] = head[prev]
			length[next] = length[prev] + 1
			next += 1
			if next > mask and code_size < 12:
				code_size += 1
				mask = (1 << code_size) - 1
		prev = code
	return out


static func _draw(canvas: PackedInt32Array, cw: int, ch: int, index: PackedByteArray,
		pal: PackedInt32Array, rect: Rect2i, trans: int, interlaced: bool) -> void:
	var x0 := maxi(rect.position.x, 0)
	var x1 := mini(rect.end.x, cw)
	if x0 >= x1:
		return
	var span := x1 - x0
	var skip := x0 - rect.position.x
	var pal_size := pal.size()
	var rows := _rows(rect.size.y, interlaced)
	for sy in rect.size.y:
		var y := rect.position.y + rows[sy]
		if y < 0 or y >= ch:
			continue
		var s := sy * rect.size.x + skip
		var d := y * cw + x0
		for k in span:
			var c := index[s + k]
			if c != trans and c < pal_size:
				canvas[d + k] = pal[c]


## Which canvas row each stored row lands on. Interlaced gifs store every 8th
## row first, then the 4th, 2nd and odd ones.
static func _rows(height: int, interlaced: bool) -> PackedInt32Array:
	var rows := PackedInt32Array()
	if not interlaced:
		rows.resize(height)
		for y in height:
			rows[y] = y
		return rows
	for pass_ in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = pass_[0]
		while y < height:
			rows.append(y)
			y += pass_[1]
	return rows


static func _clear(canvas: PackedInt32Array, cw: int, ch: int, rect: Rect2i) -> void:
	var r := rect.intersection(Rect2i(0, 0, cw, ch))
	for y in range(r.position.y, r.end.y):
		var d := y * cw
		for x in range(r.position.x, r.end.x):
			canvas[d + x] = 0
