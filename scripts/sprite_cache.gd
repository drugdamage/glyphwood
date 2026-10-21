## Turns a glyph sprite frame (rows of text, optional palette masks) into flat
## arrays once, so the renderer can draw it without parsing strings every frame.
extends RefCounted

const S := preload("res://scripts/sprites.gd")


## One sprite frame as flat arrays: column offset from the anchor, height above
## the foot (in glyph rows), the glyph facing right and left, and its palette index.
static func compile(fr: Variant, cmap: Dictionary, anchor: float) -> Array:
	var rows: Array = fr.g if fr is Dictionary else fr
	var masks: Array = fr.m if fr is Dictionary else []
	var dx := PackedFloat32Array()
	var dy := PackedFloat32Array()
	var right := PackedStringArray()
	var left := PackedStringArray()
	var pidx := PackedInt32Array()
	var n := rows.size()
	for i in n:
		var line: String = rows[i]
		var mask: String = masks[i] if i < masks.size() else ""
		for j in line.length():
			var ch := line[j]
			if ch == " ":
				continue
			var pi := 0
			if mask != "" and j < mask.length() and mask[j] != " ":
				pi = int(mask[j])
			elif cmap.has(ch):
				pi = cmap[ch]
			dx.append(j - anchor)
			dy.append(n - 1 - i + 0.5)
			right.append(ch)
			left.append(S.MIRROR.get(ch, ch))
			pidx.append(pi)
	return [dx, dy, right, left, pidx]
