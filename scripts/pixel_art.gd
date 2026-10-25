## Small pixel-art pictures for the world's props and decorations: lanterns,
## chests, the merchant, lore stones, the exit, graves, candles and the rest.
## Each picture is a grid of letters, one per pixel, that name colours in PAL
## ("." is see-through); a pixel is one world unit, so a tile is 16 x 16. A
## picture becomes a texture the first time it is drawn (one per set of
## colours) and is then drawn in a single call.
## Lower-case e / E / u, q / Q and v take the biome's edge, grass and water
## colours (see biome_pal), so the same grave or reed fits every biome.
extends RefCounted

const PAL := {
	"#": Color(0.06, 0.04, 0.05), "k": Color(0.11, 0.08, 0.1), "z": Color(0.22, 0.2, 0.24),
	"w": Color(0.4, 0.27, 0.17), "b": Color(0.54, 0.38, 0.24), "d": Color(0.26, 0.17, 0.11),
	"i": Color(0.36, 0.36, 0.41), "I": Color(0.62, 0.62, 0.68),
	"G": Color(0.86, 0.66, 0.26), "y": Color(0.62, 0.44, 0.16), "Y": Color(1.0, 0.92, 0.55),
	"s": Color(0.44, 0.42, 0.46), "S": Color(0.6, 0.58, 0.63),
	"B": Color(0.86, 0.83, 0.73), "c": Color(0.58, 0.54, 0.46),
	"r": Color(0.55, 0.06, 0.09), "R": Color(0.92, 0.2, 0.16),
	"o": Color(1.0, 0.56, 0.2), "O": Color(1.0, 0.86, 0.5),
	"W": Color(0.88, 0.85, 0.76), "h": Color(0.68, 0.6, 0.43), "n": Color(0.55, 0.44, 0.33),
	"N": Color(0.7, 0.58, 0.45), "p": Color(0.3, 0.19, 0.36), "P": Color(0.46, 0.31, 0.53),
	"a": Color(0.62, 0.84, 0.98), "A": Color(0.88, 0.97, 1.0), "m": Color(0.85, 0.32, 0.26),
	"M": Color(1.0, 0.6, 0.5), "f": Color(1.0, 0.55, 0.7), "F": Color(1.0, 0.9, 0.6),
}

const ART := {
	# ------------------------------------------------------------ props
	"lantern": [
		"....I....", "...iIi...", "..iiiii..", ".i#####i.", ".i#oOo#i.", ".i#OYO#i.", ".i#oOo#i.", ".i#####i.",
		"..iiiii..", "....d....", "....d....", "....d....", "....d....", "....d....", "....d....", "....d....",
		"....d....", "....d....", "....d....", "....d....", "....d....", "....d....", "....d....", "....d....",
		"....d....", "....d....", "...ddd...", "..ddddd..",
	],
	"chest": [
		"..############..", ".#bbbbbbbbbbbb#.", "#bbbbbbbbbbbbbb#", "#iiiiiiGGiiiiii#", "#wwwwwwGGwwwwww#",
		"#wwwwwGkkGwwwww#", "#wwwwwwGGwwwwww#", "#iiiiiiiiiiiiii#", "#wwwwwwwwwwwwww#", "#wwwwwwwwwwwwww#",
		"################",
	],
	"chest_open": [
		".##############.", ".#bbbbbbbbbbbb#.", ".##############.", "#..y..Y...y..y.#", "#kkkyyYyykyYykk#",
		"#iiiiiiiiiiiiii#", "#wwwwwwwwwwwwww#", "#wwwwwwwwwwwwww#", "#iiiiiiiiiiiiii#", "#wwwwwwwwwwwwww#",
		"################",
	],
	"sign": [
		"....######....", "..##zzzzzz##..", ".#zzzzzzzzzz#.", "#zzzzzzzzzzzz#", "#zzzzzYYzzzzz#", "#zzzzYzzYzzzz#",
		"#zzzzzzYYzzzz#", "#zzzzzzYzzzzz#", "#zzzzzzzzzzzz#", "#zzzzzzYzzzzz#", "#zzzzzzzzzzzz#", "#kkkkkkkkkkkk#",
		"##############",
	],
	"shop": [
		"..........ppp...........", ".........pPPPp.......i..", "........pPpppPp.....iOi.", "........pkkkkkp.....iOi.",
		"........pkRkRkp......i..", "........ppkkkpp......d..", ".......pppppppppp....d..", "......pPpppGppppPp...d..",
		".....pPpppGGGpppPp...d..", "bbbbbbbbbbbbbbbbbbbbbbbb", "dwwwwwwwwwwwwwwwwwwwwwwd", "dwwGGwwwwiiwwwwwyywwwwwd",
		"dwwwwwwwwwwwwwwwwwwwwwwd", "dddddddddddddddddddddddd", "d......................d", "d......................d",
		"d......................d", "dd....................dd",
	],
	"post_lamp": [
		"...I...", "..iIi..", ".i###i.", ".i#O#i.", ".i#Y#i.", ".i###i.", "..iii..",
	],
	# ------------------------------------------------------------ pickups
	"heart": [".rr.rr.", "rRRrRRr", "rRMRRRr", ".rRRRr.", "..rRr..", "...r..."],
	"gem": ["..Y..", ".YGY.", "YGGGy", ".yGy.", "..y.."],
	"orb": [".rrr.", "rRMRr", "rMMRr", "rRRRr", ".rrr."],
	# ------------------------------------------------------------ floor decorations
	"flower": [".f.", "fFf", ".f.", ".q.", ".q.", "qq."],
	"mushroom": [".mmmm.", "mMmmMm", "mmmmmm", "..WW..", "..WW.."],
	"mushroom2": [".mmmm.....", "mMmmMm....", "mmmmmm.mm.", "..WW..mMmm", "..WW...WW."],
	"fern": ["q.....q", ".q...q.", "q.q.q.q", ".qqqqq.", "..qqq..", "...q..."],
	"rock": ["..eeee..", ".eEEeee.", "eEeeeeeu", "eeeeeeuu"],
	"bones": [".........BBB..", "B.......BkBkB.", "BBBBBBB.BBBBB.", "B......B.BcB.."],
	"skull": [".BBBB.", "BBBBBB", "BkBBkB", "BBBBBB", ".BcBc."],
	"crystal": ["...A...", "..AaA..", "..Aaa..", ".AaaaA.", "Aa.Aaa.", "Aa.aaaA", "aa.aaaa"],
	"grave": ["..EEEE..", ".EeeeeE.", "EeeEEeeu", "eeEEEEeu", "eeeEEeeu", "eeeEEeeu", "eeeeeeeu", "eeeeeeeu", "uuuuuuuu"],
	"cross": ["..eE..", "..eE..", "eeEEee", "eEEEEu", "..eE..", "..eu..", "..eu..", "..eu..", ".euuu."],
	"candle": [".o.", ".O.", ".W.", ".W.", ".W.", "cWc"],
	"candle2": [".o.....", ".O...o.", ".W...O.", ".W...W.", ".W...W.", "cWc.cWc"],
	"vent": ["..o.o..", ".o.O.o.", "uu.O.uu", "uuoOouu"],
	"reeds": ["...h....", "...h....", "q..q..q.", "q..q.q..", ".q.q.q..", ".q.qq...", "..qq...."],
	"stump": ["....d...", "....d...", ".dddddd.", "dwwwwwwd", "dwdwwdwd", "dwwwwwwd", "ddwwwwdd"],
	"gallows": [
		"dddddddddd", "d......h..", "d......h..", "d......h..", "d.....hhh.", "d.....h.h.", "d.....hhh.", "d.........",
		"d.........", "d.........", "d.........", "d.........", "d.........", "d.........", "d.........", "d.........",
		"d.........", "d.........", "d.........", "d.........", "dd........", "ddd.......",
	],
	"pew": ["d.........", "d.........", "dbbbbbbbbb", "dwwwwwwwwd", "d........d", "d........d"],
	"candelabra": [".o.o.o.", ".O.O.O.", ".W.W.W.", ".G.G.G.", ".GGGGG.", "...G...", "...G...", "...G...", "..GGG..", ".GGGGG."],
	"font": ["eEEEEEEu", ".evvvvu.", "..eeeu..", "...eu...", "...eu...", "..eeeu..", ".eeeeeu."],
	"urn": ["..nnnn..", "...nn...", ".nnNnnn.", "nnNnnnnu", "nnNnnnnu", ".nnnnnu.", "..nnnu..", ".nnnnnu."],
	"sarcophagus": [
		".EEEEEEEEEEEEEEEE.", "EeeeeeeeGeeeeeeeeu", "EeeeeeeGGGeeeeeeeu", "EeeeeeeeGeeeeeeeeu", "Eeeeeeeeeeeeeeeeeu",
		"uuuuuuuuuuuuuuuuuu", "eeeeeeeeeeeeeeeeeu", "eeeeeeeeeeeeeeeeeu", "uuuuuuuuuuuuuuuuuu",
	],
	"ice": ["....A...", "...AA...", "...Aa..A", "A.AAa.Aa", "AaAaaAaa", "aaaaaaaa"],
}

static var _cache := {}


## The biome's colours for the lower-case letters that follow it.
static func biome_pal(b: Dictionary) -> Dictionary:
	var e: Color = b.edge
	return {
		"e": _mul(e, 0.95), "E": _mul(e, 1.35), "u": _mul(e, 0.55),
		"q": _mul(b.grass, 0.85), "Q": _mul(b.grass, 1.2), "v": b.water.lerp(Color(1, 1, 1), 0.35),
	}


static func _mul(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


## The texture of picture [name] with [pal] over the default colours.
static func tex(name: String, pal: Dictionary = {}) -> ImageTexture:
	var key := name + str(pal.hash())
	if _cache.has(key):
		return _cache[key]
	var rows: Array = ART[name]
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != ".":
				img.set_pixel(x, y, pal.get(ch, PAL.get(ch, Color.MAGENTA)))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Draws picture [name] standing on [foot] (screen pixels of [ci]), [s]
## screen pixels to a world unit, mirrored when [flip].
static func draw(ci: CanvasItem, name: String, foot: Vector2, s: float, pal: Dictionary = {}, flip: bool = false,
		mod: Color = Color(1, 1, 1)) -> void:
	var t := tex(name, pal)
	var size := Vector2(t.get_size()) * s
	var r := Rect2(Vector2(foot.x - size.x * 0.5, foot.y - size.y), size)
	if flip:
		# a negative width mirrors the texture in place: the rect keeps its left edge
		r = Rect2(r.position, Vector2(-size.x, size.y))
	ci.draw_texture_rect(t, r, false, mod)


## The exit: a pointed stone arch [w] x [h] world units with a glowing way
## through it, lighter towards the floor.
static func door_tex(w: int, h: int, stone: Color, glow: Color) -> ImageTexture:
	var key := "door%d/%d/%s/%s" % [w, h, stone, glow]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# a lancet: each side is an arc of radius = the span, centred on the far
	# springing point, so the apex stands 0.87 of the span above the springing
	var spring := w * 0.866
	for y in h:
		for x in w:
			var px := x + 0.5
			var dy := y + 0.5 - spring
			var inside := func(m: float) -> bool:
				if dy >= 0.0:
					return px >= m and px <= w - m
				var r := w - 2.0 * m
				return (px - m) * (px - m) + dy * dy <= r * r and (px - w + m) * (px - w + m) + dy * dy <= r * r
			if not inside.call(0.0):
				continue
			var c: Color
			if inside.call(3.0):
				var k := float(y) / h
				c = glow.darkened(0.75 - k * 0.55)
				if (x + y) % 7 == 0 and k > 0.4:
					c = c.lightened(0.15)
			else:
				var hv := float((x * 7 + y * 13) % 11) / 11.0
				c = _mul(stone, 0.75 + hv * 0.35)
				if (y + (x / 4) % 2 * 2) % 5 == 0:
					c = _mul(stone, 0.5)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## A rectangle of [w] x [h] world units at world-unit offset [x], [y] from [o].
static func box(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), c)
