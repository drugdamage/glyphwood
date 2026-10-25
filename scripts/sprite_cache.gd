## Turns a pixel sprite frame (rows of palette letters, see sprites.gd) into a
## texture once, with a dark outline round it, so the renderer draws a whole
## creature in one call. A white copy of the same shape is made for hit
## flashes and dash afterimages. Weapons are turned to any of WEAPON_STEPS
## angles in pixels of their own, so they stay crisp in the hand.
extends RefCounted

const G := preload("res://scripts/gear_sprites.gd")
const S := preload("res://scripts/sprites.gd")
const B1 := preload("res://scripts/boss_sprites_1.gd")
const B2 := preload("res://scripts/boss_sprites_2.gd")
## Angles a weapon can point at (a full turn).
const WEAPON_STEPS := 32
## Longest weapon icon in texels: a pole arm shows its head.
const ICON_LEN := 30

## Colours shared by every sprite, for the letters that are not palette shades.
const FIXED := {
	"k": Color(0.06, 0.04, 0.06), "o": Color(0.55, 0.04, 0.06), "O": Color(0.86, 0.1, 0.1),
	"x": Color(0.18, 0.17, 0.2), "y": Color(0.4, 0.39, 0.44), "z": Color(0.68, 0.68, 0.74),
	"w": Color(0.28, 0.18, 0.12), "W": Color(0.45, 0.3, 0.2), "u": Color(0.84, 0.8, 0.68), "v": Color(0.56, 0.52, 0.43),
	"r": Color(1.0, 0.25, 0.12), "R": Color(1.0, 0.78, 0.45), "q": Color(0.6, 1.0, 0.45), "s": Color(0.6, 0.9, 1.0),
	"S": Color(0.9, 0.98, 1.0), "m": Color(0.32, 0.2, 0.34), "n": Color(0.16, 0.1, 0.12), "p": Color(0.6, 0.5, 0.75),
	"t": Color(0.3, 0.32, 0.22), "T": Color(0.5, 0.52, 0.34), "#": Color(0.03, 0.02, 0.03), "*": Color(1.0, 0.97, 0.9),
}
const OUTLINE := Color(0.03, 0.02, 0.03)

static var _tex := {}
static var _weapons := {}
static var _big := {}
static var _warm_done := {}


## The pixel art of foe or boss [kind]: its palette and animations.
static func foe_def(kind: String) -> Dictionary:
	if S.FOES.has(kind):
		return S.FOES[kind]
	return B1.BOSSES.get(kind, B2.BOSSES.get(kind, S.FOES.crawler))


## The colour of letter [ch] with palette [pal]: a digit is a palette colour,
## a-j a darker shade and A-J a lighter one of colours 0-9.
static func color(ch: String, pal: Array) -> Color:
	var c := ch.unicode_at(0)
	if c >= 48 and c <= 57:
		return pal[mini(c - 48, pal.size() - 1)]
	if c >= 97 and c <= 106 and c - 97 < pal.size():
		var d: Color = pal[c - 97]
		return Color(d.r * 0.6, d.g * 0.6, d.b * 0.6)
	if c >= 65 and c <= 74 and c - 65 < pal.size():
		var l: Color = pal[c - 65]
		return Color(minf(1.0, l.r * 1.15 + (1.0 - l.r) * 0.3), minf(1.0, l.g * 1.15 + (1.0 - l.g) * 0.3),
			minf(1.0, l.b * 1.15 + (1.0 - l.b) * 0.3))
	return FIXED.get(ch, Color.MAGENTA)


## The texture of frame [fr] in palette [pal] (white all over when [white]),
## one texel bigger than the frame on every side for the outline.
static func tex(fr: Array, pal: Array, white: bool = false) -> ImageTexture:
	var key := fr.hash() ^ (pal.hash() * 31) ^ (1 if white else 0)
	var t: ImageTexture = _tex.get(key)
	if t != null:
		return t
	var h := fr.size()
	var w := 0
	for row in fr:
		w = maxi(w, (row as String).length())
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	var solid := {}
	for y in h:
		var row: String = fr[y]
		for x in row.length():
			var ch := row[x]
			if ch == "." or ch == " ":
				continue
			img.set_pixel(x + 1, y + 1, Color(1, 1, 1) if white else color(ch, pal))
			solid[Vector2i(x + 1, y + 1)] = true
	if not white:
		for q: Vector2i in solid:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not solid.has(q + d):
					img.set_pixelv(q + d, OUTLINE)
	t = ImageTexture.create_from_image(img)
	# textures are small: forgetting them all at once would make every
	# creature on screen rebuild in the same frame, a hitch
	if _tex.size() > 6000:
		_tex.clear()
	_tex[key] = t
	return t


## Width of frame [fr] in texels (without the outline).
static func width(fr: Array) -> int:
	var w := 0
	for row in fr:
		w = maxi(w, (row as String).length())
	return w


## Weapon [id] (an item) turned to angle [a] (radians, +y down), the other
## way round when [flip] (for a hero facing left: mirrored across the grip's
## axis before turning). Returns [texture, pivot]: the pivot is the corner
## between pixels where the hand closes on the grip.
static func weapon(id: String, a: float, flip: bool) -> Array:
	var step := posmod(roundi(a / TAU * WEAPON_STEPS), WEAPON_STEPS)
	var key := "%s|%d|%s" % [id, step, flip]
	var hit: Array = _weapons.get(key, [])
	if not hit.is_empty():
		return hit
	var d: Dictionary = G.WEAPONS.get(id, G.WEAPONS.rusty_blade)
	var rows: Array = d.rows
	var big := _scaled(id, rows, d.pivot.y, flip)
	hit = _turn(big, d.pal, Vector2i((rows[0] as String).length(), rows.size()), Vector2(d.pivot), step)
	# every weapon at every angle is under a thousand small textures: kept
	_weapons[key] = hit
	return hit


## Turns one more angle of the weapons in [ids] ahead of time, so a swing
## never waits for a picture: a few per frame, called every frame.
static func warm(ids: Array, per_frame: int = 2) -> void:
	for id in ids:
		if id == "" or _warm_done.has(id):
			continue
		for k in WEAPON_STEPS * 2:
			var key := "%s|%d|%s" % [id, k / 2, k % 2 == 1]
			if _weapons.has(key):
				continue
			weapon(id, (k / 2) * TAU / WEAPON_STEPS, k % 2 == 1)
			per_frame -= 1
			if per_frame <= 0:
				return
		_warm_done[id] = true


## The picture of weapon [id] for its icon: its head end, at most ICON_LEN
## texels long, pointing up and to the right, [px] pixels square (turned from
## the smooth 4x copy, so every weapon fills the same box: a halberd as much as
## a dagger); 0 keeps one pixel a texel.
static func weapon_icon(id: String, px: int = 0) -> ImageTexture:
	var key := "%s|icon|%d" % [id, px]
	if _weapons.has(key):
		return _weapons[key][0]
	var d: Dictionary = G.WEAPONS.get(id, G.WEAPONS.rusty_blade)
	var rows: Array = d.rows
	var x0 := maxi(0, (rows[0] as String).length() - ICON_LEN)
	var cut: Array = []
	for r in rows:
		cut.append((r as String).substr(x0))
	while cut.size() > 1 and (cut[0] as String).replace(".", "") == "":
		cut.pop_front()
	while cut.size() > 1 and (cut[-1] as String).replace(".", "") == "":
		cut.pop_back()
	var size := Vector2i((cut[0] as String).length(), cut.size())
	# a rect turned by 45 degrees spans its width and height over root 2; the outline adds a pixel a side
	var sc := 1.0 if px <= 0 else (px - 2.0) / ((size.x + size.y) * 0.7071)
	var hit := _turn(_scale2x(_scale2x(cut)), d.pal, size, Vector2(size) * 0.5, WEAPON_STEPS - WEAPON_STEPS / 8, sc)
	_weapons[key] = hit
	return hit[0]


## Turns [big] (rows blown up 4x from a [size] sprite) by [step] about [pv]
## (texels of the sprite), [sc] pixels to a texel, and outlines it. Returns
## [texture, pivot].
static func _turn(big: Array, pal: Array, size: Vector2i, pv: Vector2, step: int, sc: float = 1.0) -> Array:
	var th := step * TAU / WEAPON_STEPS
	var cs := cos(th)
	var sn := sin(th)
	# the turned bounds, a pixel wider on every side for the outline
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in [-pv, Vector2(size.x, 0) - pv, Vector2(0, size.y) - pv, Vector2(size) - pv]:
		var r := Vector2(q.x * cs - q.y * sn, q.x * sn + q.y * cs) * sc
		lo = lo.min(r)
		hi = hi.max(r)
	var org := Vector2i(floori(lo.x) - 1, floori(lo.y) - 1)
	var dim := Vector2i(ceili(hi.x) + 1, ceili(hi.y) + 1) - org
	var img := Image.create(dim.x, dim.y, false, Image.FORMAT_RGBA8)
	var solid := {}
	for y in dim.y:
		for x in dim.x:
			# back through the turn to the source, sampled at 4x
			var q := Vector2(x + org.x + 0.5, y + org.y + 0.5) / sc
			var sx := floori((q.x * cs + q.y * sn + pv.x) * 4.0)
			var sy := floori((-q.x * sn + q.y * cs + pv.y) * 4.0)
			if sx < 0 or sy < 0 or sy >= big.size() or sx >= (big[sy] as String).length():
				continue
			var ch: String = big[sy][sx]
			if ch == ".":
				continue
			img.set_pixel(x, y, color(ch, pal))
			solid[Vector2i(x, y)] = true
	for q: Vector2i in solid:
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = q + dv
			if not solid.has(n) and n.x >= 0 and n.y >= 0 and n.x < dim.x and n.y < dim.y:
				img.set_pixelv(n, OUTLINE)
	return [ImageTexture.create_from_image(img), -org]


## The rows of a weapon blown up 4x by Scale2x twice (smooth diagonals for
## turning), mirrored across the grip's axis (between rows [cy] - 1 and [cy])
## when [flip].
static func _scaled(id: String, rows: Array, cy: int, flip: bool) -> Array:
	var key := "%s|%s" % [id, flip]
	if _big.has(key):
		return _big[key]
	var src_rows := rows
	if flip:
		src_rows = []
		for y in rows.size():
			var src := 2 * cy - 1 - y
			src_rows.append(rows[src] if src >= 0 and src < rows.size() else ".".repeat((rows[0] as String).length()))
	var big := _scale2x(_scale2x(src_rows))
	_big[key] = big
	return big


static func _scale2x(rows: Array) -> Array:
	var h := rows.size()
	var w := (rows[0] as String).length()
	var out: Array = []
	for y in h:
		var r0 := ""
		var r1 := ""
		for x in w:
			var p: String = rows[y][x]
			var a: String = rows[y - 1][x] if y > 0 else "."
			var b: String = rows[y][x + 1] if x < w - 1 else "."
			var c: String = rows[y][x - 1] if x > 0 else "."
			var d: String = rows[y + 1][x] if y < h - 1 else "."
			r0 += (c if c == a and c != d and a != b else p) + (a if a == b and a != c and b != d else p)
			r1 += (c if d == c and d != b and c != a else p) + (b if b == d and b != a and d != c else p)
		out.append(r0)
		out.append(r1)
	return out
