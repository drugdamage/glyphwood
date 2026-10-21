## Generates the parallax background for a level as lists of glyphs:
## a far layer (mountains, cavern walls) and a mid layer (trees, pillars,
## chains, lava falls). Positions are in layer units; the renderer scrolls
## each layer at its own speed.
extends RefCounted

const D := preload("res://scripts/data.gd")

const FAR := 0.25
const MID := 0.55
const FAR_CELL := 0.8
const MID_CELL := 1.0

var ridge := PackedVector2Array()
var far_pos := PackedVector2Array()
var far_g := PackedStringArray()
var far_c := PackedColorArray()
var mid_pos := PackedVector2Array()
var mid_g := PackedStringArray()
var mid_c := PackedColorArray()

var _rng := RandomNumberGenerator.new()


func generate(b: Dictionary, size: Vector2, seed_v: int) -> void:
	_rng.seed = seed_v
	ridge.clear()
	far_pos.clear()
	far_g.clear()
	far_c.clear()
	mid_pos.clear()
	mid_g.clear()
	mid_c.clear()
	var far_ext := Rect2(-720, -320, size.x * FAR + 1440, size.y * FAR + 640)
	var mid_ext := Rect2(-720, -320, size.x * MID + 1440, size.y * MID + 640)
	match b.look:
		"wood":
			_ridge(b, far_ext, "/\\^", ".:'")
			_spires(b)
			_trees(b, mid_ext)
		"hollow":
			_cavern(b, far_ext)
			_pillars(b, mid_ext, false)
		"crypt":
			_ridge(b, far_ext, "/\\^", "*.:")
			_pillars(b, mid_ext, false)
		_:
			_ridge(b, far_ext, "/\\^", ".,:")
			_lavafalls(b, far_ext)
			_pillars(b, mid_ext, true)


func _far(p: Vector2, g: String, c: Color) -> void:
	far_pos.append(p)
	far_g.append(g)
	far_c.append(c)


func _mid(p: Vector2, g: String, c: Color) -> void:
	mid_pos.append(p)
	mid_g.append(g)
	mid_c.append(c)


static func _h(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0


## Mountain ridge with sparse fill below it.
func _ridge(b: Dictionary, ext: Rect2, edge: String, fill: String) -> void:
	var cw := D.GW * FAR_CELL
	var ch := D.GH * FAR_CELL
	var cols := int(ext.size.x / cw)
	var y := ext.position.y + ext.size.y * 0.35
	var slope := 0.0
	var prev := y
	for i in cols:
		slope = clampf(slope * 0.92 + _rng.randf_range(-0.5, 0.5), -1.6, 1.6)
		y = clampf(y + slope * ch * 0.35, ext.position.y + ext.size.y * 0.2, ext.end.y - 200.0)
		if i % 4 == 0:
			ridge.append(Vector2(ext.position.x + i * cw, y))
		var x := ext.position.x + i * cw
		var g := edge[2] if absf(y - prev) < ch * 0.2 else (edge[0] if y < prev else edge[1])
		_far(Vector2(x, y), g, b.far * 1.6)
		var k := 1
		var yy := y + ch
		while yy < ext.end.y:
			var hv := _h(i, k)
			if hv < 0.3 - minf(k, 40) * 0.005:
				var c: Color = b.far * (1.2 - minf(k, 30) * 0.02)
				_far(Vector2(x, yy), fill[int(hv * 100.0) % fill.length()], c)
			yy += ch
			k += 1
		prev = y


## Ruined chapel spires standing on the far ridge.
func _spires(b: Dictionary) -> void:
	var ch := D.GH * FAR_CELL
	var cw := D.GW * FAR_CELL
	var c: Color = b.far * 2.0
	for i in range(3, ridge.size(), 9):
		var base: Vector2 = ridge[i]
		var h := _rng.randi_range(5, 10)
		for k in h:
			_far(base + Vector2(-cw, -k * ch), "|", c)
			_far(base + Vector2(cw, -k * ch), "|", c)
			if k % 3 == 1:
				_far(base + Vector2(0, -k * ch), "n" if k < h - 2 else "o", c * 0.8)
		_far(base + Vector2(0, -h * ch), "^", c)
		_far(base + Vector2(0, -(h + 1) * ch), "+", c * 1.2)


func _trees(b: Dictionary, ext: Rect2) -> void:
	var cw := D.GW * MID_CELL
	var ch := D.GH * MID_CELL
	var x := ext.position.x
	while x < ext.end.x:
		var trunk_w := _rng.randi_range(2, 4)
		var top := ext.position.y + _rng.randf_range(40.0, ext.size.y * 0.4)
		var bark: Color = b.mid * _rng.randf_range(0.9, 1.3)
		var y := top
		while y < ext.end.y:
			for k in trunk_w:
				var hv := _h(int(x) + k, int(y))
				var bg := "|"
				if k == 0:
					bg = "(" if hv < 0.3 else "|"
				elif k == trunk_w - 1:
					bg = ")" if hv < 0.3 else "|"
				elif hv < 0.5:
					bg = [":", "'", "!", "."][int(hv * 40.0) % 4]
				_mid(Vector2(x + k * cw, y), bg, bark * (0.85 + hv * 0.3))
			y += ch
		# bare, twisted branches
		var twig: Color = bark * 1.1
		for br in _rng.randi_range(3, 5):
			var dir := -1.0 if br % 2 == 0 else 1.0
			var px := x + trunk_w * cw * 0.5
			var py := top + br * ch * 2.0
			for st in _rng.randi_range(4, 9):
				px += dir * cw
				py -= ch * _rng.randf_range(0.4, 1.0)
				_mid(Vector2(px, py), "/" if dir > 0.0 else "\\", twig * (1.0 - st * 0.06))
				if _rng.randf() < 0.3:
					_mid(Vector2(px + dir * cw, py), "_" if _rng.randf() < 0.5 else "v", twig * 0.8)
		x += _rng.randf_range(60.0, 150.0)


func _cavern(b: Dictionary, ext: Rect2) -> void:
	var cw := D.GW * FAR_CELL
	var ch := D.GH * FAR_CELL
	var x := ext.position.x
	while x < ext.end.x:
		var wdt := _rng.randi_range(3, 9)
		var length := _rng.randf_range(40.0, 160.0)
		for side in [0, 1]:
			var y0 := ext.position.y if side == 0 else ext.end.y
			var dir := 1.0 if side == 0 else -1.0
			var yy := 0.0
			while yy < length:
				var t := yy / length
				var half := int(wdt * (1.0 - t) * 0.5)
				for k in range(-half, half + 1):
					var g := "|" if absf(k) < half else ("\\" if (k < 0) == (side == 0) else "/")
					_far(Vector2(x + k * cw, y0 + yy * dir), g, b.far * (1.4 - t * 0.5))
				yy += ch
		x += _rng.randf_range(30.0, 90.0)
	for i in 160:
		var p := Vector2(_rng.randf_range(ext.position.x, ext.end.x), _rng.randf_range(ext.position.y, ext.end.y))
		_far(p, ["·", ".", "'"][i % 3], b.far * 1.5)


func _lavafalls(_b: Dictionary, ext: Rect2) -> void:
	var ch := D.GH * FAR_CELL
	var x := ext.position.x + _rng.randf_range(50.0, 200.0)
	while x < ext.end.x:
		var top := ext.position.y + _rng.randf_range(0.0, 200.0)
		var y := top
		while y < ext.end.y:
			var hv := _h(int(x), int(y))
			_far(Vector2(x, y), "|" if hv < 0.6 else ":", Color(0.45, 0.13, 0.04) * (0.8 + hv * 0.4))
			y += ch
		x += _rng.randf_range(160.0, 420.0)


## Ruined pillars with masonry, arches and hanging chains (or burning braziers).
func _pillars(b: Dictionary, ext: Rect2, ember: bool) -> void:
	var cw := D.GW * MID_CELL
	var ch := D.GH * MID_CELL
	var x := ext.position.x
	var stone: Color = b.mid * 1.3
	while x < ext.end.x:
		var pw := _rng.randi_range(3, 6)
		var top := ext.position.y + _rng.randf_range(0.0, ext.size.y * 0.5)
		var row := 0
		var y := top
		while y < ext.end.y:
			for k in pw:
				var g := "|" if k == 0 or k == pw - 1 else ("_" if row % 3 == 2 else ("[" if (k + row / 3) % 2 == 0 else "]"))
				_mid(Vector2(x + k * cw, y), g, stone * (0.8 + _h(k, row) * 0.3))
			y += ch
			row += 1
		for k in pw + 2:
			_mid(Vector2(x + (k - 1) * cw, top - ch), "=" if k > 0 and k < pw + 1 else "_", stone * 1.2)
		if _rng.randf() < 0.6:
			var cx := x + pw * cw + _rng.randf_range(20.0, 50.0)
			var clen := _rng.randi_range(8, 30)
			for k in clen:
				_mid(Vector2(cx, ext.position.y + k * ch), "o" if k % 2 == 0 else "|", stone * 0.9)
			if ember:
				_mid(Vector2(cx, ext.position.y + clen * ch), "U", Color(0.5, 0.25, 0.12))
				_mid(Vector2(cx, ext.position.y + (clen - 1) * ch), "*", Color(0.7, 0.3, 0.08))
		x += _rng.randf_range(90.0, 200.0)
