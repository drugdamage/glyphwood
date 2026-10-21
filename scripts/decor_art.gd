## Floor decorations painted into the cached terrain chunks: graves, crosses,
## candles, reeds, pews, sarcophagi and the rest, one small glyph picture each.
extends RefCounted


static func _mul(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


## Paints one floor decoration into a terrain chunk; [r] is the renderer.
static func paint_floor(r, ci: CanvasItem, d: Dictionary, o: Vector2, cell: Vector2, b: Dictionary) -> void:
	var fs: int = r.fs
	var font: Font = r.font
	var bold: Font = r.bold
	var t: float = r.t
	var v: int = d.v
	var c := func(i: float, j: float) -> Vector2: return o + Vector2((i + 0.5) * cell.x, (j + 0.5) * cell.y)
	match d.kind:
		"flower":
			var fc: Color = [Color(1.0, 0.55, 0.7), Color(1.0, 0.9, 0.45), Color(0.9, 0.9, 1.0), Color(0.75, 0.6, 1.0)][v]
			r._gc(ci, c.call(1 + v % 2, 2), "|", _mul(b.grass, 0.8), fs, font)
			r._gc(ci, c.call(1 + v % 2, 1), "*", fc, fs, bold)
		"mushroom":
			var mc := Color(0.55, 0.75, 1.0) if b.look == "hollow" else Color(1.0, 0.45, 0.35)
			r._gc(ci, c.call(1, 2), "|", Color(0.85, 0.8, 0.7), fs, font)
			r._gc(ci, c.call(1, 1.3), "n", mc, fs, bold)
			if v > 1:
				r._gc(ci, c.call(2.5, 2), "n", mc * 0.8, int(fs * 0.8), bold)
		"fern":
			r._gc(ci, c.call(1, 2), "\\", _mul(b.grass, 0.75), fs, font)
			r._gc(ci, c.call(2, 1.6), "|", _mul(b.grass, 0.85), fs, font)
			r._gc(ci, c.call(3, 2), "/", _mul(b.grass, 0.75), fs, font)
		"rock":
			r._gc(ci, c.call(1, 2), "(", _mul(b.edge, 0.8), fs, font)
			r._gc(ci, c.call(2, 2), "_" if v < 2 else "o", _mul(b.edge, 0.9), fs, font)
			r._gc(ci, c.call(3, 2), ")", _mul(b.edge, 0.8), fs, font)
		"bones":
			r._gc(ci, c.call(1, 2), "=", Color(0.8, 0.78, 0.7), fs, font)
			r._gc(ci, c.call(2, 2), "o" if v % 2 == 0 else "°", Color(0.85, 0.83, 0.75), fs, font)
		"crystal":
			var cc := Color(0.5, 0.85, 1.0) if b.look != "ember" else Color(1.0, 0.45, 0.3)
			r._gc(ci, c.call(2, 0.4), "^", cc, fs, bold)
			r._gc(ci, c.call(1.5, 1.2), "/", cc * 0.9, fs, bold)
			r._gc(ci, c.call(2.5, 1.2), "\\", cc * 0.9, fs, bold)
			r._gc(ci, c.call(2, 2), "V" if v % 2 == 0 else "W", cc * 0.75, fs, bold)
		"grave":
			var gc := _mul(b.edge, 1.15)
			r._gc(ci, c.call(2, 0.2), "_", gc, fs, font)
			r._gc(ci, c.call(1, 1), "/" if v < 2 else "|", gc, fs, font)
			r._gc(ci, c.call(2, 1), "+" if v % 2 == 0 else "-", _mul(gc, 0.8), fs, bold)
			r._gc(ci, c.call(3, 1), "\\" if v < 2 else "|", gc, fs, font)
			r._gc(ci, c.call(1, 2), "|", gc, fs, font)
			r._gc(ci, c.call(2, 2), "_", gc, fs, font)
			r._gc(ci, c.call(3, 2), "|", gc, fs, font)
		"cross":
			var cc2 := _mul(b.edge, 1.1)
			r._gc(ci, c.call(2, 0), "|", cc2, fs, bold)
			r._gc(ci, c.call(1, 0.9), "-", cc2, fs, bold)
			r._gc(ci, c.call(2, 0.9), "+", cc2, fs, bold)
			r._gc(ci, c.call(3, 0.9), "-", cc2, fs, bold)
			r._gc(ci, c.call(2, 2), "|", _mul(cc2, 0.85), fs, bold)
		"skull":
			var sc := Color(0.85, 0.82, 0.74)
			r._gc(ci, c.call(1.5 + v % 2, 1.4), "_", sc, fs, font)
			r._gc(ci, c.call(1 + v % 2, 2), "(", sc, fs, font)
			r._gc(ci, c.call(1.5 + v % 2, 2), "°" if v < 2 else "x", Color(0.15, 0.1, 0.1), fs, bold)
			r._gc(ci, c.call(2 + v % 2, 2), ")", sc, fs, font)
		"candle":
			var fl := 0.8 + 0.2 * sin(t * 11.0 + d.x)
			r._gc(ci, c.call(1, 0.9), "'", Color(1.0, 0.75, 0.35) * fl, fs, bold)
			r._gc(ci, c.call(1, 1.6), "|", Color(0.88, 0.85, 0.76), fs, font)
			r._gc(ci, c.call(1, 2), "_", Color(0.88, 0.85, 0.76), fs, font)
			if v > 1:
				r._gc(ci, c.call(2.6, 1.5), "'", Color(1.0, 0.75, 0.35) * fl, fs, bold)
				r._gc(ci, c.call(2.6, 2), "|", Color(0.88, 0.85, 0.76), fs, font)
		"vent":
			r._gc(ci, c.call(1, 2), "/", Color(0.5, 0.25, 0.15), fs, font)
			r._gc(ci, c.call(2, 2), "w", Color(1.0, 0.5, 0.15), fs, bold)
			r._gc(ci, c.call(3, 2), "\\", Color(0.5, 0.25, 0.15), fs, font)
		"reeds":
			var rc := _mul(b.grass, 0.8 + v * 0.05)
			r._gc(ci, c.call(0.6, 2), "|", rc, fs, font)
			r._gc(ci, c.call(1.2, 1.3), "|", rc, fs, font)
			r._gc(ci, c.call(1.2, 0.5), "0", Color(0.42, 0.28, 0.16), fs, bold)
			r._gc(ci, c.call(2.2, 1.7), "/", rc, fs, font)
			r._gc(ci, c.call(2.8, 2), "|", _mul(rc, 0.85), fs, font)
		"stump":
			var wc := Color(0.36, 0.28, 0.2)
			r._gc(ci, c.call(1, 2), "(", wc, fs, font)
			r._gc(ci, c.call(2, 2), "_", wc, fs, font)
			r._gc(ci, c.call(3, 2), ")", wc, fs, font)
			r._gc(ci, c.call(2, 1.2), "|", _mul(wc, 1.1), fs, bold)
			r._gc(ci, c.call(2.7, 0.6), "/", _mul(wc, 0.9), fs, font)
		"gallows":
			var post := Color(0.42, 0.32, 0.22)
			var rope := Color(0.7, 0.62, 0.45)
			for j in 3:
				r._gc(ci, c.call(0.5, 2 - j), "|", post, fs, bold)
			r._gc(ci, c.call(0.5, -1), "+", post, fs, bold)
			r._gc(ci, c.call(1.5, -1), "-", post, fs, bold)
			r._gc(ci, c.call(2.5, -1), "-", post, fs, bold)
			r._gc(ci, c.call(2.5, -0.1), "|", rope, fs, font)
			r._gc(ci, c.call(2.5, 0.8), "O", rope, fs, font)
		"pew":
			var pc := Color(0.4, 0.28, 0.2)
			r._gc(ci, c.call(0, 0.3), "n", pc, fs, bold)
			for i in 4:
				r._gc(ci, c.call(i, 1.1), "=" if i % 3 != 0 else "|", pc, fs, bold)
			r._gc(ci, c.call(0, 2), "|", _mul(pc, 0.85), fs, font)
			r._gc(ci, c.call(3, 2), "|", _mul(pc, 0.85), fs, font)
		"candelabra":
			var gold := Color(0.75, 0.6, 0.3)
			var fl2 := 0.8 + 0.2 * sin(t * 9.0 + d.x)
			r._gc(ci, c.call(2, 2), "^", gold, fs, bold)
			r._gc(ci, c.call(2, 1.4), "|", gold, fs, bold)
			r._gc(ci, c.call(1, 0.9), "\\", gold, fs, font)
			r._gc(ci, c.call(2, 0.9), "+", gold, fs, bold)
			r._gc(ci, c.call(3, 0.9), "/", gold, fs, font)
			for i in [1, 2, 3]:
				var lift := 0.3 if i == 2 else 0.0
				r._gc(ci, c.call(i, 0.2 - lift), "|", Color(0.9, 0.87, 0.78), fs, font)
				r._gc(ci, c.call(i, -0.5 - lift), "'", Color(1.0, 0.78, 0.4) * fl2, fs, bold)
		"font":
			var st := _mul(b.edge, 1.1)
			r._gc(ci, c.call(1, 1), "\\", st, fs, font)
			r._gc(ci, c.call(2, 1), "~", b.water.lerp(Color(1, 1, 1), 0.4), fs, bold)
			r._gc(ci, c.call(3, 1), "/", st, fs, font)
			r._gc(ci, c.call(2, 1.8), "|", st, fs, bold)
			r._gc(ci, c.call(1.5, 2.1), "_", st, fs, font)
			r._gc(ci, c.call(2.5, 2.1), "_", st, fs, font)
		"urn":
			var bc := Color(0.55, 0.45, 0.35) if v % 2 == 0 else _mul(b.edge, 1.2)
			r._gc(ci, c.call(2, 0.9), "_", bc, fs, font)
			r._gc(ci, c.call(1.3, 1.6), "(", bc, fs, font)
			r._gc(ci, c.call(2, 1.6), "§" if v < 2 else "o", _mul(bc, 0.8), fs, bold)
			r._gc(ci, c.call(2.7, 1.6), ")", bc, fs, font)
			r._gc(ci, c.call(2, 2.1), "-", bc, fs, font)
		"sarcophagus":
			var sc2 := _mul(b.edge, 1.15)
			r._gc(ci, c.call(0, 1), "[", sc2, fs, font)
			r._gc(ci, c.call(4, 1), "]", sc2, fs, font)
			r._gc(ci, c.call(0, 2), "[", sc2, fs, font)
			r._gc(ci, c.call(4, 2), "]", sc2, fs, font)
			for i in [1, 2, 3]:
				r._gc(ci, c.call(i, 1), "†" if i == 2 else "=", Color(0.75, 0.68, 0.5) if i == 2 else sc2, fs, bold)
				r._gc(ci, c.call(i, 2), "_", _mul(sc2, 0.85), fs, font)
		"ice":
			var ic := Color(0.7, 0.9, 1.0)
			r._gc(ci, c.call(1, 2), "^", _mul(ic, 0.85), fs, bold)
			r._gc(ci, c.call(2, 1.2), "A" if v % 2 == 0 else "^", ic, fs, bold)
			r._gc(ci, c.call(2, 2), "|", _mul(ic, 0.9), fs, bold)
			r._gc(ci, c.call(3, 2), "^", _mul(ic, 0.8), fs, bold)
