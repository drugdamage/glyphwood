## Terrain for the "Pixels" picture: rock, brick, ledges, spikes and the back
## wall painted as small pixel textures (flat rectangles on a grid of 16 x 16
## texels per tile) instead of glyphs, into the same cached chunks as the text
## picture. A hash of the tile's position picks the details, so a tile looks
## the same every time it is painted.
extends RefCounted

const D := preload("res://scripts/data.gd")

## Texels across one tile.
const N := 16
const BONE := Color(0.62, 0.6, 0.54)
const STONE_H := 5
const STONE_W := 8

static var _ci: CanvasItem
static var _o := Vector2.ZERO
static var _q := 1.0


static func _mul(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


static func _h(x: int, y: int, salt: int) -> float:
	var n := (x * 374761393 + y * 668265263 + salt * 1442695041) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0


## A rectangle of w x h texels at texel x, y of the current tile.
static func _r(x: float, y: float, w: float, h: float, col: Color) -> void:
	_ci.draw_rect(Rect2(_o + Vector2(x, y) * _q, Vector2(w, h) * _q), col)


static func _begin(ci: CanvasItem, o: Vector2, s: float) -> void:
	_ci = ci
	_o = o
	_q = D.TILE * s / N


## Rock or brick: stones near open air, darker and sparser deeper in, a lit
## top with grass, worn sides, drips underneath and cracks on cracked tiles.
static func solid(ci: CanvasItem, lv, tx: int, ty: int, o: Vector2, s: float, depth: int, b: Dictionary, cracked: bool) -> void:
	_begin(ci, o, s)
	var inner: Color = b.deep.lerp(b.edge, 0.3)
	var k := 1.0 - minf(depth, 6) * 0.11
	if b.brick:
		_bricks(tx, ty, _mul(inner, 0.95 * k))
	elif depth <= 2:
		_stones(tx, ty, _mul(b.edge if depth <= 1 else inner, (0.5 if depth <= 1 else 0.6) * k))
	else:
		for i in 4:
			var hv := _h(tx, ty, i)
			if hv < 0.7:
				_r(int(hv * 97.0) % 15, int(hv * 389.0) % 15, 1 + int(hv * 7.0) % 2, 1, _mul(inner, 0.7 * k))
		var buried := _h(tx, ty, 9)
		if depth >= 3 and buried > 0.985:
			if b.look == "ember":
				_r(6, 7, 2, 1, Color(0.75, 0.25, 0.08))
				_r(9, 9, 1, 1, Color(0.6, 0.18, 0.05))
			else:
				_r(5, 8, 6, 1, _mul(BONE, 0.6))
				_r(4, 7, 1, 3, _mul(BONE, 0.55))
				_r(11, 7, 1, 3, _mul(BONE, 0.55))
	if cracked:
		var x := 3.0 + _h(tx, ty, 21) * 6.0
		for j in 6:
			_r(x, 2 + j * 2, 1, 2, _mul(b.edge, 1.15))
			x += 1.0 if j % 2 == 0 else -1.0
			_r(x + 4, 4 + j * 2, 1, 1, _mul(b.edge, 0.9))
	var up_air: bool = not lv.solid(tx, ty - 1)
	if not lv.solid(tx - 1, ty):
		_r(0, 0, 1, N, _mul(b.edge, 0.75))
	if not lv.solid(tx + 1, ty):
		_r(N - 1, 0, 1, N, _mul(b.edge, 0.45))
	if not lv.solid(tx, ty + 1):
		_r(0, N - 1, N, 1, _mul(b.fill, 0.6))
		for i in N:
			var hd := _h(tx * N + i, ty, 5)
			if hd < 0.18:
				_r(i, N, 1, 1 + int(hd * 20.0) % 3, _mul(b.edge, 0.45))
	if up_air:
		_r(0, 0, N, 2, _mul(b.top, 0.78))
		_r(0, 2, N, 1, _mul(b.edge, 0.85))
		for i in N:
			var hg := _h(tx * N + i, ty, 3)
			if hg < 0.25:
				_r(i, 0, 1, 1, _mul(b.top, 1.05))
			if hg > 0.62:
				var gh := 1 + int(hg * 31.0) % 3
				_r(i, -gh, 1, gh, _mul(b.grass, 0.7 + hg * 0.3))


## Rows of stones STONE_H texels high laid across the whole level (so they
## run on over tile edges), each stone about STONE_W wide, with a lit top and
## a shaded foot.
static func _stones(tx: int, ty: int, base: Color) -> void:
	var gx0 := tx * N
	var gy0 := ty * N
	for r in range(floori(gy0 / float(STONE_H)), floori((gy0 + N - 1) / float(STONE_H)) + 1):
		var top := r * STONE_H - gy0
		var y0 := maxi(top, 0)
		var y1 := mini(top + STONE_H - 1, N)
		if y1 <= y0:
			continue
		var i := floori((gx0 - STONE_W * 2) / float(STONE_W))
		while _edge(r, i) < gx0 + N:
			var a := _edge(r, i) - gx0
			var e := _edge(r, i + 1) - gx0 - 1
			var x0 := maxi(a, 0)
			var x1 := mini(e, N)
			if x1 > x0:
				var hv := _h(r, i, 17)
				var c := _mul(base, 0.7 + hv * 0.5)
				# rounded: the corner texels stay mortar
				var l := 1 if x0 == a else 0
				var rr := 1 if x1 == e else 0
				_r(x0 + l, y0, x1 - x0 - l - rr, y1 - y0, c)
				_r(x0, maxi(y0, top + 1), x1 - x0, mini(y1, top + STONE_H - 2) - maxi(y0, top + 1), c)
				if top >= 0:
					_r(x0 + l, top, x1 - x0 - l - rr, 1, _mul(c, 1.3))
				if top + STONE_H - 2 < N:
					_r(x0 + l, top + STONE_H - 2, x1 - x0 - l - rr, 1, _mul(c, 0.68))
			i += 1


## Where stone i of row r begins, in texels from the level's left edge.
static func _edge(r: int, i: int) -> int:
	return i * STONE_W + int(_h(r, i, 23) * 7.0) + (STONE_W / 2 if r % 2 == 1 else 0)


## Courses of bricks four texels high, every other course shifted half a brick.
static func _bricks(tx: int, ty: int, base: Color) -> void:
	for row in 4:
		var y := row * 4
		var shift := 4 if (ty * 4 + row) % 2 == 1 else 0
		for n in 3:
			var x := -shift + n * 8
			var x0 := maxi(x, 0)
			var x1 := mini(x + 7, N)
			if x1 - x0 < 1:
				continue
			var hv := _h(tx * 3 + n, ty * 4 + row, 19)
			var c := _mul(base, 0.8 + hv * 0.35)
			_r(x0, y, x1 - x0, 3, c)
			_r(x0, y, x1 - x0, 1, _mul(c, 1.25))
			if hv > 0.93:
				_r(x0 + 2, y + 1, 2, 1, _mul(c, 0.6))


## Masonry joints (or loose earth in the wild biomes) on the dim back wall.
static func backwall(ci: CanvasItem, tx: int, ty: int, o: Vector2, s: float, b: Dictionary) -> void:
	_begin(ci, o, s)
	match b.look:
		"hollow", "crypt":
			var joint := _mul(b.edge, 0.12)
			for row in 2:
				var y := row * 8 + 7
				_r(0, y, N, 1, joint)
				var x := 4 if (ty * 2 + row) % 2 == 1 else 12
				_r(x, y - 7, 1, 7, joint)
			if _h(tx, ty, 31) > 0.9:
				_r(3, 3, 3, 2, _mul(b.edge, 0.16))
		_:
			for i in 3:
				var hv := _h(tx, ty, 40 + i)
				if hv < 0.6:
					_r(int(hv * 131.0) % 15, int(hv * 541.0) % 15, 1 + int(hv * 9.0) % 2, 1, _mul(b.deep, 0.5))
			if b.look == "ember" and _h(tx, ty, 44) > 0.97:
				_r(7, 7, 1, 1, Color(0.5, 0.15, 0.05))


## A plank ledge you can jump up through.
static func ledge(ci: CanvasItem, lv, tx: int, ty: int, o: Vector2, s: float, b: Dictionary, oneway: int) -> void:
	_begin(ci, o, s)
	var c := _mul(b.top, 0.62)
	_r(0, 0, N, 3, c)
	_r(0, 0, N, 1, _mul(c, 1.35))
	_r(0, 3, N, 1, _mul(c, 0.45))
	for i in [5, 11]:
		_r(i + int(_h(tx, ty, 50) * 3.0), 1, 1, 1, _mul(c, 0.6))
	if lv.at(tx - 1, ty) != oneway:
		_r(1, 4, 2, 3, _mul(b.edge, 0.5))
	if lv.at(tx + 1, ty) != oneway:
		_r(N - 3, 4, 2, 3, _mul(b.edge, 0.5))


## A row of iron spikes on the floor of a pit.
static func spikes(ci: CanvasItem, tx: int, o: Vector2, s: float) -> void:
	_begin(ci, o, s)
	_r(0, N - 2, N, 2, Color(0.28, 0.12, 0.11))
	for i in 4:
		var hv := _h(tx, i, 60)
		var x := i * 4.0
		var top := 6.0 + hv * 3.0
		var tri := PackedVector2Array([_o + Vector2(x, N - 2) * _q, _o + Vector2(x + 2, top) * _q, _o + Vector2(x + 4, N - 2) * _q])
		_ci.draw_colored_polygon(tri, Color(0.82, 0.3 + hv * 0.1, 0.26))
		_r(x + 2, top + 1, 1, N - 3 - top, Color(1.0, 0.62, 0.5))
