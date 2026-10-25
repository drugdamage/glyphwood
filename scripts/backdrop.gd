## Generates the parallax background for a level as flat pixel shapes: a far
## layer (a mountain ridge with chapel spires, cavern teeth, lava falls) and a
## mid layer (bare trees, ruined pillars with hanging chains or braziers).
## Positions are in layer units (one world unit on that layer); the renderer
## scrolls each layer at its own speed and paints the shapes into cached
## buckets. A shape is {"r": Rect2, "c": Color} or {"p": points, "c": Color}.
extends RefCounted

const FAR := 0.25
const MID := 0.55

var ridge := PackedVector2Array()
var far: Array = []
var mid: Array = []

var _rng := RandomNumberGenerator.new()


func generate(b: Dictionary, size: Vector2, seed_v: int) -> void:
	_rng.seed = seed_v
	ridge.clear()
	far = []
	mid = []
	var far_ext := Rect2(-720, -320, size.x * FAR + 1440, size.y * FAR + 640)
	var mid_ext := Rect2(-720, -320, size.x * MID + 1440, size.y * MID + 640)
	match b.look:
		"wood":
			_ridge(b, far_ext)
			_spires(b)
			_trees(b, mid_ext)
		"hollow":
			_cavern(b, far_ext)
			_pillars(b, mid_ext, false)
		"crypt":
			_ridge(b, far_ext)
			_pillars(b, mid_ext, false)
		_:
			_ridge(b, far_ext)
			_lavafalls(far_ext)
			_pillars(b, mid_ext, true)


## Where a shape's bucket is chosen from.
static func anchor(sh: Dictionary) -> Vector2:
	return sh.r.position if sh.has("r") else sh.p[0]


func _far_r(x: float, y: float, w: float, h: float, c: Color) -> void:
	far.append({"r": Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), "c": c})


func _mid_r(x: float, y: float, w: float, h: float, c: Color) -> void:
	mid.append({"r": Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), "c": c})


func _tri(list: Array, a: Vector2, b2: Vector2, c2: Vector2, col: Color) -> void:
	list.append({"p": PackedVector2Array([a, b2, c2]), "c": col})


## A jagged mountain ridge (filled by the renderer) with a lit crest and
## loose stones on its face.
func _ridge(b: Dictionary, ext: Rect2) -> void:
	var y := ext.position.y + ext.size.y * 0.35
	var slope := 0.0
	var x := ext.position.x
	var i := 0
	while x < ext.end.x:
		slope = clampf(slope * 0.92 + _rng.randf_range(-0.5, 0.5), -1.6, 1.6)
		y = clampf(y + slope * 1.5, ext.position.y + ext.size.y * 0.2, ext.end.y - 200.0)
		if i % 4 == 0:
			ridge.append(Vector2(roundf(x), roundf(y)))
		_far_r(x, y, 3, 1, b.far * 1.7)
		if _rng.randf() < 0.18:
			_far_r(x, y + _rng.randf_range(6.0, 120.0), 1 + _rng.randi_range(0, 1), 1, b.far * 1.25)
		x += 3.0
		i += 1


## Ruined chapels standing on the far ridge: a nave, a steep roof, a spire
## with a cross and now and then a window still lit.
func _spires(b: Dictionary) -> void:
	var c: Color = b.far * 2.0
	for i in range(3, ridge.size(), 9):
		var base: Vector2 = ridge[i] + Vector2(0, 4)
		var w := _rng.randi_range(8, 12)
		var h := _rng.randi_range(14, 26)
		_far_r(base.x - w * 0.5, base.y - h, w, h, c)
		_tri(far, Vector2(base.x - w * 0.5 - 1, base.y - h), Vector2(base.x + w * 0.5 + 1, base.y - h), Vector2(base.x, base.y - h - w * 0.8), c)
		var tower := base.x + w * 0.5 - 2
		var th := h + _rng.randi_range(10, 20)
		_far_r(tower - 2, base.y - th, 4, th, c * 0.9)
		_tri(far, Vector2(tower - 3, base.y - th), Vector2(tower + 3, base.y - th), Vector2(tower, base.y - th - 14), c * 0.9)
		_far_r(tower - 0.5, base.y - th - 19, 1, 6, c * 1.2)
		_far_r(tower - 1.5, base.y - th - 17, 3, 1, c * 1.2)
		var lit := _rng.randf() < 0.35
		_far_r(base.x - 2, base.y - h + 5, 2, 4, Color(0.55, 0.35, 0.15) if lit else c * 0.45)


## Bare, crooked trees: a trunk with dark bark lines and branches that climb
## in pixel steps, thinning out to twigs.
func _trees(b: Dictionary, ext: Rect2) -> void:
	var x := ext.position.x
	while x < ext.end.x:
		var tw := _rng.randi_range(6, 11)
		var top := ext.position.y + _rng.randf_range(40.0, ext.size.y * 0.4)
		var bark: Color = b.mid * _rng.randf_range(0.7, 1.0)
		_mid_r(x, top, tw, ext.end.y - top, bark)
		_mid_r(x, top, 1, ext.end.y - top, bark * 1.25)
		for k in _rng.randi_range(3, 6):
			var lx := x + _rng.randi_range(2, tw - 2)
			var ly := top + _rng.randf_range(0.0, 300.0)
			_mid_r(lx, ly, 1, _rng.randf_range(10.0, 60.0), bark * 0.7)
		for br in _rng.randi_range(4, 8):
			var dir := -1.0 if br % 2 == 0 else 1.0
			var px: float = x + (float(tw) if dir > 0.0 else 0.0)
			var py := top + br * 30.0 + _rng.randf_range(0.0, 20.0)
			var thick := 3.0
			for st in _rng.randi_range(6, 12):
				_mid_r(px, py, 2, thick, bark * (1.05 - st * 0.03))
				px += dir * 2.0
				py -= _rng.randf_range(0.5, 2.0)
				thick = maxf(1.0, thick - 0.3)
				if _rng.randf() < 0.25:
					_mid_r(px, py - 3, 1, 3, bark * 0.95)
		x += _rng.randf_range(60.0, 150.0)


## Teeth of rock hanging from the cave roof and rising from its floor, with
## motes of dust between them.
func _cavern(b: Dictionary, ext: Rect2) -> void:
	var x := ext.position.x
	while x < ext.end.x:
		var w := _rng.randf_range(10.0, 30.0)
		var length := _rng.randf_range(40.0, 160.0)
		var c: Color = b.far * _rng.randf_range(1.1, 1.5)
		_tri(far, Vector2(x - w * 0.5, ext.position.y), Vector2(x + w * 0.5, ext.position.y), Vector2(x, ext.position.y + length), c)
		var l2 := length * _rng.randf_range(0.5, 1.0)
		_tri(far, Vector2(x - w * 0.6, ext.end.y), Vector2(x + w * 0.6, ext.end.y), Vector2(x + 3.0, ext.end.y - l2), c * 0.9)
		x += _rng.randf_range(30.0, 90.0)
	for i in 160:
		_far_r(_rng.randf_range(ext.position.x, ext.end.x), _rng.randf_range(ext.position.y, ext.end.y), 1, 1, b.far * 1.6)


## Falls of molten rock far away, a bright thread down the middle.
func _lavafalls(ext: Rect2) -> void:
	var x := ext.position.x + _rng.randf_range(50.0, 200.0)
	while x < ext.end.x:
		var top := ext.position.y + _rng.randf_range(0.0, 200.0)
		var w := _rng.randi_range(3, 6)
		_far_r(x, top, w, ext.end.y - top, Color(0.36, 0.1, 0.03))
		_far_r(x + w * 0.5, top, 1, ext.end.y - top, Color(0.6, 0.2, 0.05))
		x += _rng.randf_range(160.0, 420.0)


## Ruined pillars with courses of masonry and a capital, and beside some of
## them a chain hanging from the dark (with a brazier in the ember biome).
func _pillars(b: Dictionary, ext: Rect2, ember: bool) -> void:
	var x := ext.position.x
	var stone: Color = b.mid * 1.3
	while x < ext.end.x:
		var pw := _rng.randi_range(12, 22)
		var top := ext.position.y + _rng.randf_range(0.0, ext.size.y * 0.5)
		_mid_r(x, top, pw, ext.end.y - top, stone)
		_mid_r(x, top, 1, ext.end.y - top, stone * 1.2)
		_mid_r(x + pw - 1, top, 1, ext.end.y - top, stone * 0.7)
		var y := top + 6.0
		var row := 0
		while y < minf(ext.end.y, top + 900.0):
			_mid_r(x + 1, y, pw - 2, 1, stone * 0.7)
			_mid_r(x + (pw * 0.5 if row % 2 == 0 else pw * 0.25), y - 6, 1, 6, stone * 0.75)
			y += 6.0
			row += 1
		_mid_r(x - 2, top - 3, pw + 4, 3, stone * 1.2)
		_mid_r(x - 1, top - 4, pw + 2, 1, stone * 1.4)
		if _rng.randf() < 0.6:
			var cx := x + pw + _rng.randf_range(20.0, 50.0)
			var clen := _rng.randf_range(40.0, 160.0)
			var k := 0.0
			while k < clen:
				_mid_r(cx, ext.position.y + k, 2, 2, stone * 0.9)
				_mid_r(cx + 0.5, ext.position.y + k + 2, 1, 2, stone * 0.6)
				k += 4.0
			if ember:
				var by := ext.position.y + clen
				_mid_r(cx - 3, by, 8, 3, Color(0.4, 0.22, 0.12))
				_mid_r(cx - 2, by - 3, 6, 3, Color(0.7, 0.3, 0.08))
				_mid_r(cx, by - 5, 2, 2, Color(0.9, 0.5, 0.15))
		x += _rng.randf_range(90.0, 200.0)
