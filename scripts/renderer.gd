## Draws the world with glyphs on a fine text grid (4 x 3 glyphs per tile).
## Static terrain is painted once into cached chunks; the parallax layers are
## cached too. Everything that moves (grass, water, entities, effects) is drawn
## every frame. Also collects light sources for the post-process shader.
extends Node2D

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Combat := preload("res://scripts/combat.gd")
const Backdrop := preload("res://scripts/backdrop.gd")
const Items := preload("res://scripts/items.gd")

## Tiles visible vertically at each zoom level.
const ZOOMS := [30.0, 24.0, 19.0]
const CHUNK := 16
const MAX_LIGHTS := 32
const GRASS := ["'", ",", "\"", "`", "'", ";"]


## A canvas item whose drawing is done by a callback and cached until redrawn.
class Painter:
	extends Node2D
	var fn: Callable
	var arg: Variant

	func _draw() -> void:
		fn.call(self, arg)


var game
var font: Font
var bold: Font
var zoom_idx := 1
var s := 1.0
var vp := Vector2.ZERO
var off := Vector2.ZERO
var base := Vector2.ZERO
var t := 0.0
var fs := 12
var fs_far := 10
var adv := 7.0
var adv_b := 7.0
var _adv_ratio := 0.6
var _adv_ratio_b := 0.6
var _title_t := 0.0
var _neck: Array = []
var _depth := PackedByteArray()
var _chunks := {}
var _far: Painter
var _mid: Painter
var _terrain: Node2D
var _dyn: Painter
var _bd := Backdrop.new()
var _lava_lights: Array = []
var _decor_lights: Array = []
var _motes: Array = []
var _dyn_tiles := {}
var _adv_cache := {}
var _deferred: Array = []
var _defer_ci: CanvasItem = null
var _last_key := ""
var lights: Array = []


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b
	_adv_ratio = font.get_char_size("M".unicode_at(0), 100).x / 100.0
	_adv_ratio_b = bold.get_char_size("M".unicode_at(0), 100).x / 100.0
	_far = _painter(_paint_far)
	_mid = _painter(_paint_mid)
	_terrain = Node2D.new()
	add_child(_terrain)
	_dyn = _painter(_paint_dynamic)


func _painter(fn: Callable, arg: Variant = null) -> Painter:
	var p := Painter.new()
	p.fn = fn
	p.arg = arg
	add_child(p)
	return p


func title_cam_reset() -> void:
	_title_t = 0.0


func redraw_all() -> void:
	_far.queue_redraw()
	_mid.queue_redraw()
	for k in _chunks:
		_chunks[k].queue_redraw()


func on_level_built() -> void:
	for k in _chunks:
		_chunks[k].queue_free()
	_chunks.clear()
	_compute_depth()
	_index_dynamic_tiles()
	var lv = game.lv
	_bd.generate(game.biome, lv.pixel_size(), game.level_num * 7919 + game.run_seed % 1000)
	_lava_lights.clear()
	for y in lv.h:
		var run := 0
		for x in lv.w + 1:
			if x < lv.w and lv.at(x, y) == Level.LAVA:
				run += 1
			elif run > 0:
				_lava_lights.append(Vector3((x - run * 0.5) * D.TILE, (y + 0.5) * D.TILE, maxf(70.0, run * D.TILE * 0.9)))
				run = 0
	_decor_lights.clear()
	for d in lv.decor:
		if d.kind in ["crystal", "mushroom", "vent", "candle"]:
			_decor_lights.append(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = game.level_num
	_motes.clear()
	var size: Vector2 = lv.pixel_size()
	for i in 90:
		_motes.append({"p": Vector2(rng.randf_range(0, size.x), rng.randf_range(0, size.y)), "ph": rng.randf() * TAU})
	_neck.clear()
	redraw_all()


func tiles_changed(_list: Array) -> void:
	_compute_depth()
	_index_dynamic_tiles()
	for k in _chunks:
		_chunks[k].queue_redraw()


func clamp_cam(c: Vector2) -> Vector2:
	if s <= 0.0 or vp == Vector2.ZERO:
		return c
	var half := vp / s * 0.5
	var size: Vector2 = game.lv.pixel_size()
	c.x = size.x * 0.5 if size.x < half.x * 2.0 else clampf(c.x, half.x, size.x - half.x)
	c.y = size.y * 0.5 if size.y < half.y * 2.0 else clampf(c.y, half.y, size.y - half.y)
	return c


func screen_to_world(p: Vector2) -> Vector2:
	return (p - base) / s


func sp(w: Vector2) -> Vector2:
	return w * s + base


func _process(delta: float) -> void:
	t += delta
	vp = get_viewport_rect().size
	s = vp.y / (ZOOMS[zoom_idx] * D.TILE)
	fs = maxi(5, int(round(D.GW * s / _adv_ratio)))
	fs_far = maxi(4, int(round(D.GW * Backdrop.FAR_CELL * s / _adv_ratio)))
	adv = D.GW * s
	var key := "%d/%d/%d" % [vp.x, vp.y, zoom_idx]
	if key != _last_key:
		_last_key = key
		redraw_all()
	if game.is_title():
		_title_t += delta
		# drift slowly around the starting room, which always has open sky above it
		var st: Vector2 = game.lv.start
		game.cam = clamp_cam(st + Vector2(sin(_title_t * 0.05) * 160.0, -90.0))
	off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * game.shake * s * 0.5
	base = (vp * 0.5 - game.cam * s + off).round()
	if not game.player.is_empty() and not game.is_title():
		_neck.push_front(_neck_pos())
		if _neck.size() > 16:
			_neck.pop_back()
	_place_layers()
	queue_redraw()
	_dyn.queue_redraw()
	_collect_lights()


func _place_layers() -> void:
	var cam: Vector2 = game.cam
	_far.position = (vp * 0.5 - cam * Backdrop.FAR * s + off * 0.3).round()
	_mid.position = (vp * 0.5 - cam * Backdrop.MID * s + off * 0.5).round()
	var lv = game.lv
	var tl := screen_to_world(Vector2.ZERO)
	var br := screen_to_world(vp)
	var cx0 := maxi(0, int(floor(tl.x / (CHUNK * D.TILE))) - 1)
	var cy0 := maxi(0, int(floor(tl.y / (CHUNK * D.TILE))) - 1)
	var cx1 := mini(int(ceil(float(lv.w) / CHUNK)) - 1, int(floor(br.x / (CHUNK * D.TILE))) + 1)
	var cy1 := mini(int(ceil(float(lv.h) / CHUNK)) - 1, int(floor(br.y / (CHUNK * D.TILE))) + 1)
	# Chunks just around the view are needed now; one more ring is painted
	# ahead of time, at most one chunk per frame, so scrolling never stalls.
	var ahead := 0
	for cy in range(maxi(0, cy0 - 1), mini(cy1 + 1, int(ceil(float(lv.h) / CHUNK)) - 1) + 1):
		for cx in range(maxi(0, cx0 - 1), mini(cx1 + 1, int(ceil(float(lv.w) / CHUNK)) - 1) + 1):
			var k := Vector2i(cx, cy)
			if _chunks.has(k):
				continue
			var needed := cx >= cx0 and cx <= cx1 and cy >= cy0 and cy <= cy1
			if not needed:
				if ahead > 0:
					continue
				ahead += 1
			var p := Painter.new()
			p.fn = _paint_chunk
			p.arg = k
			_terrain.add_child(p)
			_chunks[k] = p
	for k in _chunks:
		var p: Painter = _chunks[k]
		p.position = (Vector2(k) * CHUNK * D.TILE * s + base).round()
		p.visible = k.x >= cx0 and k.x <= cx1 and k.y >= cy0 and k.y <= cy1


# ---------------------------------------------------------------- helpers

static func _hash01(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0


static func _mul(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


## Draws one glyph centred on a point in the canvas item's own pixel space.
func _gc(ci: CanvasItem, p: Vector2, g: String, col: Color, size: int, f: Font) -> void:
	var key := size * 2 + (1 if f == bold else 0)
	var w: float = _adv_cache.get(key, -1.0)
	if w < 0.0:
		w = f.get_char_size("M".unicode_at(0), size).x
		_adv_cache[key] = w
	if ci == _defer_ci:
		_deferred.append([Vector2(p.x - w * 0.5, p.y + size * 0.36), g, col, size, f])
		return
	ci.draw_char(f, Vector2(p.x - w * 0.5, p.y + size * 0.36), g, size, col)


## Draws one glyph centred on a world position (dynamic layer).
func _glyph(w: Vector2, g: String, col: Color, size_mul: float = 1.0, f: Font = null, px_off: Vector2 = Vector2.ZERO) -> void:
	var fnt := f if f != null else bold
	_gc(_dyn, sp(w) + px_off, g, col, maxi(4, int(fs * size_mul)), fnt)


## Buckets, per chunk, the tiles that are redrawn every frame: grass spots,
## water, lava and gates.
func _index_dynamic_tiles() -> void:
	var lv = game.lv
	_dyn_tiles.clear()
	for y in lv.h:
		for x in lv.w:
			var tt: int = lv.tiles[y * lv.w + x]
			var keep := tt == Level.WATER or tt == Level.LAVA or tt == Level.GATE
			if tt == Level.AIR and lv.solid(x, y + 1):
				keep = _hash01(x, y) >= (0.6 if game.biome.id == "hollow" else 0.25)
			for ar in lv.arenas:
				if ar.gates.has(Vector2i(x, y)):
					keep = true
			if keep:
				var k := Vector2i(x / CHUNK, y / CHUNK)
				if not _dyn_tiles.has(k):
					_dyn_tiles[k] = []
				_dyn_tiles[k].append(Vector2i(x, y))


func _compute_depth() -> void:
	var lv = game.lv
	_depth.resize(lv.w * lv.h)
	for i in lv.w * lv.h:
		var tt: int = lv.tiles[i]
		_depth[i] = 9 if (tt == Level.SOLID or tt == Level.CRACKED) else 0
	for pass_i in 4:
		for y in lv.h:
			for x in lv.w:
				var i: int = y * lv.w + x
				if _depth[i] == 0:
					continue
				var m := mini(mini(_dget(x - 1, y), _dget(x + 1, y)), mini(_dget(x, y - 1), _dget(x, y + 1)))
				_depth[i] = mini(9, m + 1)


func _dget(x: int, y: int) -> int:
	var lv = game.lv
	if x < 0 or y < 0 or x >= lv.w or y >= lv.h:
		return 9
	return _depth[y * lv.w + x]


func _draw() -> void:
	if game == null or game.lv == null:
		return
	var b: Dictionary = game.biome
	var top: Color = b.sky_top
	var bot: Color = b.sky_bot
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([top, top, bot, bot]))
	if b.sky:
		# moon and stars drift very slowly
		var mp := Vector2(vp.x * 0.78 - game.cam.x * s * 0.02, vp.y * 0.16 - game.cam.y * s * 0.02)
		draw_circle(mp, 34.0 * s, Color(0.6, 0.08, 0.08, 0.08))
		draw_circle(mp, 18.0 * s, Color(0.8, 0.15, 0.12, 0.2))
		draw_circle(mp, 9.0 * s, Color(0.78, 0.2, 0.16))
		draw_circle(mp + Vector2(2.5, -1.5) * s, 2.2 * s, Color(0.62, 0.14, 0.12))
		draw_circle(mp + Vector2(-3.0, 2.5) * s, 1.6 * s, Color(0.62, 0.14, 0.12))
		for i in 70:
			var sx := fposmod(_hash01(i, 3) * vp.x * 1.5 - game.cam.x * s * 0.05, vp.x)
			var sy := _hash01(i, 9) * vp.y * 0.6
			var tw := 0.35 + 0.35 * sin(t * (1.0 + _hash01(i, 5) * 2.0) + i)
			_gc(self, Vector2(sx, sy), "." if i % 3 else "+", Color(0.75, 0.7, 0.8, tw), fs, font)


# ---------------------------------------------------------------- cached layers

func _paint_far(ci: CanvasItem, _arg: Variant) -> void:
	var ridge := _bd.ridge
	if ridge.size() > 1:
		var poly := PackedVector2Array()
		for q in ridge:
			poly.append(q * s)
		poly.append(Vector2(ridge[-1].x, 4000.0) * s)
		poly.append(Vector2(ridge[0].x, 4000.0) * s)
		var c: Color = _mul(game.biome.far, 0.55)
		ci.draw_colored_polygon(poly, c)
	_paint_list(ci, _bd.far_pos, _bd.far_g, _bd.far_c, fs_far)


func _paint_mid(ci: CanvasItem, _arg: Variant) -> void:
	_paint_list(ci, _bd.mid_pos, _bd.mid_g, _bd.mid_c, fs)


func _paint_list(ci: CanvasItem, pos: PackedVector2Array, gl: PackedStringArray, cols: PackedColorArray, size: int) -> void:
	if game == null or game.lv == null:
		return
	for i in pos.size():
		var c := cols[i]
		c.a = 1.0
		_gc(ci, pos[i] * s, gl[i], c, size, font)


func _paint_chunk(ci: CanvasItem, k: Vector2i) -> void:
	_defer_ci = ci
	_deferred.clear()
	_paint_chunk_inner(ci, k)
	_defer_ci = null
	_flush(ci)


## Glyphs are drawn after all rectangles and grouped by font, so the renderer
## can batch a whole chunk into a few draw calls.
func _flush(ci: CanvasItem) -> void:
	for f in [font, bold]:
		for d in _deferred:
			if d[4] == f:
				ci.draw_char(f, d[0], d[1], d[3], d[2])
	_deferred.clear()


func _paint_chunk_inner(ci: CanvasItem, k: Vector2i) -> void:
	var lv = game.lv
	var b: Dictionary = game.biome
	var T := D.TILE
	var origin := Vector2(k) * CHUNK * T
	var tile_px := T * s
	var cell := Vector2(D.GW, D.GH) * s
	var top_g: String = b.glyphs_top
	var edge_g: String = b.glyphs_edge
	var deep_g: String = b.glyphs_deep
	var brick: bool = b.brick
	var fill: Color = _mul(b.fill, 1.15)
	var inner: Color = b.deep.lerp(b.edge, 0.3)
	for ty in range(k.y * CHUNK, mini(lv.h, (k.y + 1) * CHUNK)):
		for tx in range(k.x * CHUNK, mini(lv.w, (k.x + 1) * CHUNK)):
			var tt: int = lv.tiles[ty * lv.w + tx]
			var o := (Vector2(tx, ty) * T - origin) * s
			if tt == Level.SOLID or tt == Level.CRACKED:
				ci.draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), fill)
				var up_air: bool = not lv.solid(tx, ty - 1)
				var dn_air: bool = not lv.solid(tx, ty + 1)
				var l_air: bool = not lv.solid(tx - 1, ty)
				var r_air: bool = not lv.solid(tx + 1, ty)
				var depth := _dget(tx, ty)
				for j in 3:
					for i in 4:
						var gx := tx * 4 + i
						var gy := ty * 3 + j
						var hv := _hash01(gx, gy)
						var p := o + Vector2((i + 0.5) * cell.x, (j + 0.5) * cell.y)
						var g := ""
						var col: Color
						if tt == Level.CRACKED and hv < 0.55:
							g = ["%", "/", ";", "\\"][int(hv * 40.0) % 4]
							col = _mul(b.edge, 1.15)
						elif up_air and j == 0:
							g = top_g[int(hv * 60.0) % top_g.length()]
							col = _mul(b.top, 0.8 + hv * 0.3)
						elif up_air and j == 1:
							g = edge_g[int(hv * 60.0) % edge_g.length()]
							col = _mul(b.edge, 0.8 + hv * 0.3)
						elif (l_air and i == 0) or (r_air and i == 3):
							g = "|" if hv < 0.5 else ("[" if i == 0 else "]")
							col = _mul(b.edge, 0.7 + hv * 0.2)
						elif dn_air and j == 2:
							g = ["'", "`", "v", "'", ",", "\""][int(hv * 60.0) % 6]
							col = _mul(b.edge, 0.55 + hv * 0.2)
						elif brick:
							if gy % 3 == 2:
								g = "_" if hv < 0.9 else "."
							elif (gx + (gy / 3) % 2 * 4) % 8 == 0:
								g = "|"
							elif hv < 0.12:
								g = ":"
							col = _mul(inner, 1.25 - minf(depth, 6) * 0.1)
						else:
							var chance := 0.9 if depth <= 1 else (0.7 if depth == 2 else (0.5 if depth == 3 else 0.32))
							if hv < chance:
								var set_g := edge_g if depth <= 1 else deep_g
								g = set_g[int(hv * 97.0) % set_g.length()]
								col = _mul(b.edge if depth <= 1 else inner, (0.8 if depth <= 1 else 1.2) - minf(depth, 6) * 0.08)
						if g != "":
							_gc(ci, p, g, col, fs, font)
			elif tt == Level.AIR or tt == Level.WATER or tt == Level.GATE:
				_paint_backwall(ci, tx, ty, o, cell, b)
			elif tt == Level.ONEWAY:
				_paint_backwall(ci, tx, ty, o, cell, b)
				for i in 4:
					var hv2 := _hash01(tx * 4 + i, ty * 7)
					var p2 := o + Vector2((i + 0.5) * cell.x, 0.5 * cell.y)
					_gc(ci, p2, "=" if hv2 < 0.6 else "-", _mul(b.top, 0.75 + hv2 * 0.2), fs, font)
					if (lv.at(tx - 1, ty) != Level.ONEWAY and i == 0) or (lv.at(tx + 1, ty) != Level.ONEWAY and i == 3):
						_gc(ci, p2 + Vector2(0, cell.y), "'", _mul(b.edge, 0.6), fs, font)
			elif tt == Level.SPIKES:
				for i in 4:
					var hv3 := _hash01(tx * 4 + i, ty)
					_gc(ci, o + Vector2((i + 0.5) * cell.x, 2.5 * cell.y), "^", Color(0.95, 0.35 + hv3 * 0.1, 0.3), fs, bold)
					if i % 2 == 1:
						_gc(ci, o + Vector2((i + 0.5) * cell.x, 1.6 * cell.y), "^", Color(0.75, 0.3, 0.26), fs, bold)
	for d in lv.decor:
		if d.x >= k.x * CHUNK and d.x < (k.x + 1) * CHUNK and d.y >= k.y * CHUNK and d.y < (k.y + 1) * CHUNK:
			_paint_floor_decor(ci, d, (Vector2(d.x, d.y) * T - origin) * s, cell, b)


## Dim masonry / rock / roots behind the playable space, except under open sky.
func _paint_backwall(ci: CanvasItem, tx: int, ty: int, o: Vector2, cell: Vector2, b: Dictionary) -> void:
	var lv = game.lv
	var room = lv.room_at_tile(tx, ty)
	if room == null or (b.sky and room.gy == 0):
		return
	var tile_px := D.TILE * s
	var wall: Color = b.fill.lerp(b.sky_bot, 0.5)
	wall.a = 0.7
	ci.draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), wall)
	for j in 3:
		for i in 4:
			var gx := tx * 4 + i
			var gy := ty * 3 + j
			var hv := _hash01(gx + 911, gy + 37)
			var g := ""
			var col: Color = _mul(b.deep, 1.1)
			match b.id:
				"hollow":
					if gy % 3 == 2:
						g = "_" if hv < 0.8 else ""
					elif (gx + (gy / 3) % 2 * 4) % 8 == 0:
						g = "|"
					elif hv < 0.04:
						g = "."
					col = _mul(b.edge, 0.26 + hv * 0.08)
				"ember":
					if hv < 0.16:
						g = [":", ".", "'", ",", ";"][int(hv * 100.0) % 5]
					elif hv > 0.995:
						g = "~"
						col = Color(0.55, 0.18, 0.06)
				_:
					if hv < 0.2:
						g = [".", ",", "'", "`", ":"][int(hv * 100.0) % 5]
					elif hv > 0.993:
						g = ["(", ")", "~"][int(hv * 1000.0) % 3]
						col = Color(0.16, 0.12, 0.14)
			if g != "":
				_gc(ci, o + Vector2((i + 0.5) * cell.x, (j + 0.5) * cell.y), g, col, fs, font)


func _paint_floor_decor(ci: CanvasItem, d: Dictionary, o: Vector2, cell: Vector2, b: Dictionary) -> void:
	var v: int = d.v
	var c := func(i: float, j: float) -> Vector2: return o + Vector2((i + 0.5) * cell.x, (j + 0.5) * cell.y)
	match d.kind:
		"flower":
			var fc: Color = [Color(1.0, 0.55, 0.7), Color(1.0, 0.9, 0.45), Color(0.9, 0.9, 1.0), Color(0.75, 0.6, 1.0)][v]
			_gc(ci, c.call(1 + v % 2, 2), "|", _mul(b.grass, 0.8), fs, font)
			_gc(ci, c.call(1 + v % 2, 1), "*", fc, fs, bold)
		"mushroom":
			var mc := Color(0.55, 0.75, 1.0) if b.id == "hollow" else Color(1.0, 0.45, 0.35)
			_gc(ci, c.call(1, 2), "|", Color(0.85, 0.8, 0.7), fs, font)
			_gc(ci, c.call(1, 1.3), "n", mc, fs, bold)
			if v > 1:
				_gc(ci, c.call(2.5, 2), "n", mc * 0.8, int(fs * 0.8), bold)
		"fern":
			_gc(ci, c.call(1, 2), "\\", _mul(b.grass, 0.75), fs, font)
			_gc(ci, c.call(2, 1.6), "|", _mul(b.grass, 0.85), fs, font)
			_gc(ci, c.call(3, 2), "/", _mul(b.grass, 0.75), fs, font)
		"rock":
			_gc(ci, c.call(1, 2), "(", _mul(b.edge, 0.8), fs, font)
			_gc(ci, c.call(2, 2), "_" if v < 2 else "o", _mul(b.edge, 0.9), fs, font)
			_gc(ci, c.call(3, 2), ")", _mul(b.edge, 0.8), fs, font)
		"bones":
			_gc(ci, c.call(1, 2), "=", Color(0.8, 0.78, 0.7), fs, font)
			_gc(ci, c.call(2, 2), "o" if v % 2 == 0 else "°", Color(0.85, 0.83, 0.75), fs, font)
		"crystal":
			var cc := Color(0.5, 0.85, 1.0) if b.id != "ember" else Color(1.0, 0.45, 0.3)
			_gc(ci, c.call(2, 0.4), "^", cc, fs, bold)
			_gc(ci, c.call(1.5, 1.2), "/", cc * 0.9, fs, bold)
			_gc(ci, c.call(2.5, 1.2), "\\", cc * 0.9, fs, bold)
			_gc(ci, c.call(2, 2), "V" if v % 2 == 0 else "W", cc * 0.75, fs, bold)
		"grave":
			var gc := _mul(b.edge, 1.15)
			_gc(ci, c.call(2, 0.2), "_", gc, fs, font)
			_gc(ci, c.call(1, 1), "/" if v < 2 else "|", gc, fs, font)
			_gc(ci, c.call(2, 1), "+" if v % 2 == 0 else "-", _mul(gc, 0.8), fs, bold)
			_gc(ci, c.call(3, 1), "\\" if v < 2 else "|", gc, fs, font)
			_gc(ci, c.call(1, 2), "|", gc, fs, font)
			_gc(ci, c.call(2, 2), "_", gc, fs, font)
			_gc(ci, c.call(3, 2), "|", gc, fs, font)
		"cross":
			var cc2 := _mul(b.edge, 1.1)
			_gc(ci, c.call(2, 0), "|", cc2, fs, bold)
			_gc(ci, c.call(1, 0.9), "-", cc2, fs, bold)
			_gc(ci, c.call(2, 0.9), "+", cc2, fs, bold)
			_gc(ci, c.call(3, 0.9), "-", cc2, fs, bold)
			_gc(ci, c.call(2, 2), "|", _mul(cc2, 0.85), fs, bold)
		"skull":
			var sc := Color(0.85, 0.82, 0.74)
			_gc(ci, c.call(1.5 + v % 2, 1.4), "_", sc, fs, font)
			_gc(ci, c.call(1 + v % 2, 2), "(", sc, fs, font)
			_gc(ci, c.call(1.5 + v % 2, 2), "°" if v < 2 else "x", Color(0.15, 0.1, 0.1), fs, bold)
			_gc(ci, c.call(2 + v % 2, 2), ")", sc, fs, font)
		"candle":
			var fl := 0.8 + 0.2 * sin(t * 11.0 + d.x)
			_gc(ci, c.call(1, 0.9), "'", Color(1.0, 0.75, 0.35) * fl, fs, bold)
			_gc(ci, c.call(1, 1.6), "|", Color(0.88, 0.85, 0.76), fs, font)
			_gc(ci, c.call(1, 2), "_", Color(0.88, 0.85, 0.76), fs, font)
			if v > 1:
				_gc(ci, c.call(2.6, 1.5), "'", Color(1.0, 0.75, 0.35) * fl, fs, bold)
				_gc(ci, c.call(2.6, 2), "|", Color(0.88, 0.85, 0.76), fs, font)
		"vent":
			_gc(ci, c.call(1, 2), "/", Color(0.5, 0.25, 0.15), fs, font)
			_gc(ci, c.call(2, 2), "w", Color(1.0, 0.5, 0.15), fs, bold)
			_gc(ci, c.call(3, 2), "\\", Color(0.5, 0.25, 0.15), fs, font)


# ---------------------------------------------------------------- dynamic layer

func _paint_dynamic(_ci: CanvasItem, _arg: Variant) -> void:
	if game == null or game.lv == null:
		return
	var b: Dictionary = game.biome
	var tl := screen_to_world(Vector2.ZERO) - Vector2(D.TILE, D.TILE)
	var br := screen_to_world(vp) + Vector2(D.TILE, D.TILE)
	var view := Rect2(tl, br - tl)
	_draw_motes(b, view)
	_draw_ceiling_decor(b, view)
	_draw_torches(b, view)
	_draw_door(b)
	_draw_props()
	_draw_tiles_dynamic(b, tl, br)
	_draw_items()
	for hz in game.hazards:
		_draw_hazard(hz)
	for e in game.enemies:
		if view.has_point(Physics.center(e)) or e.boss:
			_draw_enemy(e)
	for pr in game.projectiles:
		_draw_projectile(pr)
	if not game.is_title():
		for gh in game.ghosts:
			var a: float = gh.life / 0.22 * 0.5
			_sprite(gh.frame, gh.foot, gh.facing, S.HERO_PAL, {}, 2.0, Color(0.75, 0.12, 0.16, a), true)
		_draw_hero()
		_draw_slashes()
	for pt in game.particles:
		var c: Color = pt.c
		c.a = clampf(pt.life / pt.max, 0.0, 1.0)
		_glyph(pt.p, pt.g, c, pt.s)
	for pu in game.popups:
		var pc: Color = pu.color
		pc.a = clampf(pu.life * 2.0, 0.0, 1.0)
		var sp_p := sp(pu.pos)
		var fsz := int(fs * 1.05)
		var w := bold.get_string_size(pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		_dyn.draw_string(bold, sp_p - Vector2(w * 0.5, 0), pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, pc)
	if not game.near.is_empty() and game.is_playing():
		_draw_prompt(game.near)


func _draw_motes(b: Dictionary, view: Rect2) -> void:
	for m in _motes:
		var p: Vector2 = m.p + Vector2(sin(t * 0.4 + m.ph) * 30.0, cos(t * 0.3 + m.ph) * 20.0)
		if not view.has_point(p):
			continue
		var c: Color = b.mote
		c.a = 0.2 + 0.4 * (0.5 + 0.5 * sin(t * 2.0 + m.ph))
		_glyph(p, "·", c, 1.0, font)


func _draw_tiles_dynamic(b: Dictionary, tl: Vector2, br: Vector2) -> void:
	var lv = game.lv
	var T := D.TILE
	var x0 := maxi(0, int(floor(tl.x / T)))
	var x1 := mini(lv.w - 1, int(ceil(br.x / T)))
	var y0 := maxi(0, int(floor(tl.y / T)))
	var y1 := mini(lv.h - 1, int(ceil(br.y / T)))
	var pc := Vector2(-9999, -9999)
	if not game.player.is_empty() and not game.is_title():
		pc = Physics.center(game.player)
	var wc: Color = b.water
	var cx0 := int(x0 / CHUNK)
	var cx1 := int(x1 / CHUNK)
	var cy0 := int(y0 / CHUNK)
	var cy1 := int(y1 / CHUNK)
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			for q in _dyn_tiles.get(Vector2i(cx, cy), []):
				var x: int = q.x
				var y: int = q.y
				if x < x0 or x > x1 or y < y0 or y > y1:
					continue
				_draw_dyn_tile(b, lv, x, y, pc, wc)


func _draw_dyn_tile(b: Dictionary, lv, x: int, y: int, pc: Vector2, wc: Color) -> void:
	var T := D.TILE
	var tt: int = lv.tiles[y * lv.w + x]
	if tt == Level.AIR:
		if lv.solid(x, y + 1) and lv.at(x, y + 1) != Level.GATE:
			_draw_grass(b, x, y, pc)
		return
	match tt:
		Level.WATER, Level.LAVA:
			var lava := tt == Level.LAVA
			var surf: bool = lv.at(x, y - 1) == Level.AIR
			var col := Color(1.0, 0.45, 0.12) if lava else wc
			_dyn.draw_rect(Rect2(sp(Vector2(x * T, y * T)), Vector2(T * s + 1, T * s + 1)),
				Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.55 if not lava else 0.8))
			for j in 3:
				for i in 4:
					var wx := x * T + (i + 0.5) * D.GW
					var wy := y * T + (j + 0.5) * D.GH
					var ph := sin(wx * 0.15 + t * (2.0 if lava else 2.6) + j)
					if surf and j == 0:
						_glyph(Vector2(wx, wy + ph * 1.2), "~" if ph > -0.3 else "-", _mul(col, 1.0), 1.0, bold)
					elif _hash01(x * 4 + i, y * 3 + j + int(t * 2.0)) < 0.22:
						_glyph(Vector2(wx, wy), "~" if not lava else ("*" if ph > 0.6 else "~"), _mul(col, 0.55 + 0.2 * ph), 0.9, font)
			if lava and surf and _hash01(x, int(t * 3.0)) < 0.02:
				game.particles.append({"p": Vector2((x + 0.5) * T, y * T), "v": Vector2(randf_range(-20, 20), -60),
					"g": "·", "c": Color(1.0, 0.6, 0.2), "life": 0.8, "max": 0.8, "grav": -20.0, "drag": 0.5, "s": 0.9})
		Level.GATE:
			for i in 4:
				var gp := Vector2(x * T + (i + 0.5) * D.GW, y * T)
				if i % 2 == 0:
					for j in 3:
						_glyph(gp + Vector2(0, (j + 0.5) * D.GH), "|", Color(0.85, 0.82, 0.75), 1.0, bold)
			if not lv.at(x, y - 1) == Level.GATE:
				_glyph(Vector2(x * T + T * 0.5, y * T), "=", Color(0.9, 0.85, 0.7), 1.0, bold)


func _draw_grass(b: Dictionary, x: int, y: int, pc: Vector2) -> void:
	var T := D.TILE
	var h := _hash01(x, y)
	if h < 0.25 or b.id == "hollow" and h < 0.6:
		return
	for k in 4:
		var hk := _hash01(x * 4 + k, y + 77)
		if hk < 0.35:
			continue
		var wx := x * T + (k + 0.5) * D.GW
		var lean := sin(wx * 0.045 - t * 1.8 + h * 2.0) + 0.5 * sin(wx * 0.13 + t * 0.7)
		var g: String = GRASS[int(hk * 60.0) % GRASS.size()]
		var dx := wx - pc.x
		if absf(dx) < 10.0 and absf(pc.y - (y + 1) * T) < 24.0:
			g = "/" if dx > 0.0 else "\\"
		elif lean > 1.0:
			g = "/"
		elif lean < -1.0:
			g = "\\"
		var c: Color = _mul(b.grass, 0.55 + 0.4 * hk + maxf(0.0, lean - 0.6) * 0.25)
		_glyph(Vector2(wx, (y + 1) * T - D.GH * 0.5), g, c, 1.0, font)
		if hk > 0.85:
			_glyph(Vector2(wx, (y + 1) * T - D.GH * 1.5), "'" if lean > 0.0 else "`", _mul(b.grass, 0.6), 1.0, font)


func _draw_ceiling_decor(b: Dictionary, view: Rect2) -> void:
	for d in game.lv.decor:
		if not d.kind in ["vine", "root", "stalactite", "chain", "web"]:
			continue
		var top := Vector2((d.x + 0.5) * D.TILE, d.y * D.TILE)
		if not view.has_point(top):
			continue
		var n: int = d.v
		for k in n:
			var sway: float = sin(t * 1.3 + d.x * 0.7 + k * 0.5) * k * 0.35 if d.kind != "stalactite" else 0.0
			var p := top + Vector2(sway, (k + 0.5) * D.GH)
			var g := ":"
			var c: Color = _mul(b.edge, 0.7 - k * 0.05)
			match d.kind:
				"vine":
					g = "j" if k == n - 1 else (":" if k % 2 == 0 else "!")
					c = _mul(b.grass, 0.7 - k * 0.05)
					if k == n - 1 and d.x % 3 == 0:
						g = "'"
						c = Color(0.6, 0.08, 0.1)
				"root":
					g = ["\\", "|", "/", "|"][k % 4]
					c = Color(0.45, 0.33, 0.22)
				"stalactite":
					if k > n / 2:
						break
					g = "V" if k == 0 else ("v" if k < n / 2 else "'")
				"chain":
					g = "o" if k % 2 == 0 else "|"
					c = Color(0.55, 0.55, 0.6)
					if k == n - 1:
						g = "J"
				"web":
					if k > 1:
						break
					g = "/\\" if k == 0 else "\\/"
					c = Color(0.8, 0.8, 0.85, 0.5)
					_glyph(p + Vector2(-D.GW * 0.5, 0), g[0], c, 1.0, font)
					_glyph(p + Vector2(D.GW * 0.5, 0), g[1], c, 1.0, font)
					continue
			_glyph(p, g, c, 1.0, font)


func _draw_torches(b: Dictionary, view: Rect2) -> void:
	for tp in game.lv.torches:
		if not view.has_point(tp):
			continue
		var fl := sin(t * 13.0 + tp.x) * 0.5 + sin(t * 7.3 + tp.y) * 0.5
		var fc: Color = b.torch
		if b.sky:
			# lantern on a post
			var floor_y: float = tp.y + D.TILE * 2.5
			var y: float = tp.y + D.GH
			while y < floor_y:
				_glyph(Vector2(tp.x, y), "|", Color(0.42, 0.34, 0.26), 1.0, font)
				y += D.GH
			_glyph(tp + Vector2(-D.GW, 0), "[", Color(0.5, 0.42, 0.3), 1.0, bold)
			_glyph(tp + Vector2(D.GW, 0), "]", Color(0.5, 0.42, 0.3), 1.0, bold)
			_glyph(tp, "o", _mul(fc, 1.0 + fl * 0.15), 1.0, bold)
			_glyph(tp + Vector2(0, -D.GH), "^", Color(0.5, 0.42, 0.3), 1.0, bold)
		else:
			_glyph(tp + Vector2(0, D.GH), "|", Color(0.5, 0.4, 0.3), 1.0, bold)
			_glyph(tp + Vector2(0, D.GH * 0.2), "U", Color(0.55, 0.45, 0.35), 1.0, bold)
			_glyph(tp + Vector2(fl * 0.8, -D.GH * 0.6), "*" if fl > 0.0 else "^", _mul(fc, 1.1), 1.0, bold)
			_glyph(tp + Vector2(-fl * 0.8, -D.GH * 1.4), "'" if fl > 0.3 else ".", _mul(fc, 0.8), 1.0, bold)


func _draw_door(b: Dictionary) -> void:
	var lv = game.lv
	var r: Rect2 = lv.door
	if r.size == Vector2.ZERO or not lv.door_open:
		return
	var def: Dictionary = S.PROPS.door
	var foot := Vector2(r.get_center().x, r.end.y)
	var pal: Array = def.pal
	if not lv.door_open:
		pal = [Color(0.35, 0.35, 0.38), pal[1], pal[2]]
	_sprite(def.idle[0], foot, 1, pal, def.cmap, def.a)
	if lv.door_open:
		var c: Color = b.top
		for i in 7:
			var ph := fmod(t * 0.5 + i * 0.143, 1.0)
			var p := Vector2(r.position.x + 3.0 + fmod(i * 7.3, r.size.x - 6.0), r.end.y - 4.0 - ph * (r.size.y + 4.0))
			c.a = 1.0 - ph
			_glyph(p, "·" if i % 2 == 0 else "'", c, 1.0, font)
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		_glyph(r.get_center() + Vector2(0, -2), ">", _mul(b.top, pulse), 1.3, bold)


func _draw_props() -> void:
	for pr in game.props:
		var def: Dictionary = S.PROPS[pr.kind]
		var fr: Array
		match pr.kind:
			"chest":
				fr = def.open[0] if pr.open else def.closed[0]
			"shrine":
				fr = def.used[0] if pr.used else def.lit[0]
			_:
				fr = def.idle[0]
		var foot: Vector2 = pr.pos
		if pr.kind == "chest" and not pr.open:
			foot += Vector2(0, 0)
		_sprite(fr, foot, 1, def.pal, def.cmap, def.a)
		if pr.kind == "shrine" and not pr.used:
			for i in 3:
				var ph := fmod(t * 0.4 + i * 0.33, 1.0)
				var c := Color(0.55, 1.0, 0.75, 1.0 - ph)
				_glyph(foot + Vector2(sin(t + i * 2.0) * 10.0, -30.0 - ph * 30.0), "+", c, 0.9, font)


func _draw_prompt(pr: Dictionary) -> void:
	var label: String = game.key("interact") + " " + game.L("act_" + pr.kind)
	var p := sp(pr.pos + Vector2(0, -42))
	var size := int(fs * 0.95)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var bob := sin(t * 4.0) * 2.0
	_dyn.draw_rect(Rect2(p.x - w * 0.5 - 6, p.y - size + bob - 3, w + 12, size + 8), Color(0, 0, 0, 0.65))
	_dyn.draw_string(font, Vector2(p.x - w * 0.5, p.y + bob), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.92, 0.7))


func _draw_items() -> void:
	for pk in game.pickups:
		var p: Vector2 = pk.pos + Vector2(0, sin(t * 3.0 + pk.pos.x) * 2.0)
		if pk.kind == "heart":
			_glyph(p, "♥", Color(1.0, 0.35, 0.45), 1.3)
		else:
			for i in 3:
				var a := t * 2.0 + i * TAU / 3.0
				_glyph(p + Vector2(cos(a), sin(a)) * 4.0, "*", Color(1.0, 0.85, 0.35), 0.9)
			_glyph(p, "◆", Color(1.0, 0.95, 0.6), 1.1)
	for sh in game.shards:
		var c := _mul(Color(1.0, 0.85, 0.35), 0.8 + 0.2 * sin(t * 10.0 + sh.pos.x))
		_glyph(sh.pos + sh.size * 0.5, "*", c, 0.9)


func _draw_hazard(hz: Dictionary) -> void:
	if hz.t < hz.warn:
		if int(hz.t * 12.0) % 2 == 0:
			_glyph(Vector2(hz.x, hz.y - D.GH * 0.5), "!", Color(1.0, 0.35, 0.2), 1.3)
		_glyph(Vector2(hz.x, hz.y - 2.0), "^", Color(1.0, 0.55, 0.2, 0.6), 1.0)
		return
	var k := 0
	var y: float = hz.y - D.GH * 0.5
	while y > hz.y - 110.0:
		var c := Color(1.0, 0.75 - k * 0.025, 0.3 - k * 0.01)
		var g: String = ["|", "*", "^", "|"][(k + int(t * 20.0)) % 4]
		_glyph(Vector2(hz.x + sin(t * 30.0 + k) * 2.0, y), g, c, 1.1)
		_glyph(Vector2(hz.x - D.GW, y), "(", Color(1.0, 0.45, 0.15, 0.7), 1.0)
		_glyph(Vector2(hz.x + D.GW, y), ")", Color(1.0, 0.45, 0.15, 0.7), 1.0)
		y -= D.GH
		k += 1


func _draw_projectile(pr: Dictionary) -> void:
	if pr.delay > 0.0:
		if pr.kind in ["ember", "rock"]:
			var tx := int(pr.pos.x / D.TILE)
			var ty := int(pr.pos.y / D.TILE)
			while ty < game.lv.h and not game.lv.solid(tx, ty + 1):
				ty += 1
			if pr.delay < 0.6 and int(pr.delay * 12.0) % 2 == 0:
				_glyph(Vector2(pr.pos.x, (ty + 1) * D.TILE - 3.0), "!", Color(1.0, 0.4, 0.2), 1.1)
		return
	var look: Array = Combat.SHOT_LOOK.get(pr.kind, Combat.SHOT_LOOK.shot)
	var g: String = look[0]
	if pr.kind == "arrow" or pr.kind == "knife":
		var a: float = pr.vel.angle()
		g = _tangent_glyph(a + PI * 0.5) if pr.kind == "arrow" else ("»" if pr.vel.x >= 0.0 else "«")
		if pr.kind == "knife" and absf(pr.vel.y) > absf(pr.vel.x):
			g = "^" if pr.vel.y < 0.0 else "v"
	_glyph(pr.pos, g, look[1], 1.3 if pr.kind != "wave" else 1.6)


func _draw_enemy(e: Dictionary) -> void:
	var def: Dictionary = S.FOES[e.kind]
	var tint := Color(1, 1, 1)
	var flash: bool = e.flash > 0.0
	if e.kind == "wisp":
		var ph := fmod(e.anim, 3.0)
		tint.a = 0.15 if ph > 2.3 else 1.0
	if e.burn > 0.0 and int(t * 10.0) % 2 == 0:
		tint = Color(1.0, 0.7, 0.5)
	var foot := Physics.foot(e)
	if e.elite:
		for i in 4:
			var a := t * 3.0 + i * TAU / 4.0
			_glyph(Physics.center(e) + Vector2(cos(a) * e.size.x * 0.7, sin(a) * e.size.y * 0.6), "·", Color(1.0, 0.85, 0.3, 0.8), 1.0)
	_sprite(Foes.frame(e), foot, e.dir, def.pal, def.cmap, def.a, tint, false, flash)
	if e.elite:
		_glyph(foot + Vector2(0, -e.size.y - D.GH * 1.2), "♦", Color(1.0, 0.85, 0.3), 0.9)
	match e.kind:
		"knight":
			if e.state == "tele" and int(t * 14.0) % 2 == 0:
				_glyph(Vector2(Physics.center(e).x, e.pos.y - 10), "!", Color(1.0, 0.3, 0.25), 1.4)
		"spitter":
			if e.state == "charge":
				_glyph(Physics.center(e) + Vector2(0, -12), "·", Color(1.0, 0.5, 0.4, 0.5 + 0.5 * sin(t * 30.0)), 1.6)
		"archer":
			if e.state == "aim" and e.t < 0.3 and int(t * 14.0) % 2 == 0:
				_glyph(Vector2(Physics.center(e).x, e.pos.y - 10), "!", Color(1.0, 0.3, 0.25), 1.2)
		"bomber":
			if e.state == "fuse":
				_glyph(Physics.center(e) + Vector2(0, -14), "*", Color(1.0, 1.0, 0.6), 1.2 + sin(t * 40.0) * 0.3)
		"warden", "colossus", "wraith":
			if e.state in ["crouch", "tele", "raise", "ring"] and int(t * 10.0) % 2 == 0:
				_glyph(Vector2(Physics.center(e).x, e.pos.y - 14), "!", Color(1.0, 0.3, 0.25), 1.8)
	if not e.boss and e.hp < e.max_hp and e.hp > 0:
		var w: float = e.size.x
		var y: float = e.pos.y - 8.0
		var n := 5
		var full := int(ceil(float(e.hp) / e.max_hp * n))
		for i in n:
			_glyph(Vector2(e.pos.x + w * 0.5 + (i - 2) * D.GW * 0.8, y), "-", Color(1.0, 0.35, 0.3) if i < full else Color(0.3, 0.1, 0.1), 0.8, font)


func _draw_hero() -> void:
	var p: Dictionary = game.player
	if p.is_empty() or p.dead or p.respawn_t > 0.0:
		return
	if p.blink > 0.0 and p.inv > 0.0 and int(p.blink * 18.0) % 2 == 0:
		return
	var neck := _neck_pos()
	for k in 5:
		var hist: Vector2 = _neck[mini(k * 3 + 2, _neck.size() - 1)] if not _neck.is_empty() else neck
		var wind := Vector2(-p.facing * (3.0 + k * 3.6), sin(t * 8.0 - k * 1.1) * 1.6 + k * 0.7)
		var pt := neck + wind + ((hist - neck) * 0.3).limit_length(8.0)
		var c := _mul(S.HERO_PAL[3], 1.0 - k * 0.12)
		_glyph(pt, "~" if k % 2 == 0 else "^", c, 1.05 - k * 0.06)
	var tint := Color(1, 1, 1)
	if p.heal_t > 0.0:
		tint = Color(0.6, 1.0, 0.7)
	_sprite(Hero.frame(p), Physics.foot(p), p.facing, S.HERO_PAL, {}, 2.0, tint)
	if p.atk_t > p.atk_len - 0.16 and p.atk_kind == "side":
		var wid: String = game.player.weapon
		var wc: Color = Items.def(wid).get("color", Color(0.85, 0.9, 1.0))
		var reach: float = p.st.reach
		for i in int(2 + reach * 2.0):
			_glyph(Physics.foot(p) + Vector2(p.facing * (D.GW * (3.5 + i)), -D.GH * 2.5), "=" if i < 2 else "-", wc, 1.0)


func _neck_pos() -> Vector2:
	var p: Dictionary = game.player
	return Physics.foot(p) + Vector2(-p.facing * 4.0, -D.GH * 3.2)


func _draw_slashes() -> void:
	var p: Dictionary = game.player
	var c := Physics.center(p)
	var wid: String = p.weapon
	var wcol: Color = Items.def(wid).get("color", Color(0.85, 0.97, 1.0))
	for sl in game.slashes:
		var reveal := clampf(sl.t / 0.07, 0.0, 1.0)
		var alpha := 1.0 - clampf((sl.t - 0.07) / 0.15, 0.0, 1.0)
		var base_a := 0.0 if sl.facing > 0 else PI
		var center := c + Vector2(sl.facing * 4.0, -2.0)
		match sl.kind:
			"up":
				base_a = -PI * 0.5
				center = c + Vector2(0, -8)
			"down":
				base_a = PI * 0.5
				center = c + Vector2(0, 10)
		var big: bool = sl.combo == 2
		var radius: float = (24.0 if big else 20.0) * sl.reach
		var spread := deg_to_rad(80.0)
		var n := 12
		var col: Color = Color(1.0, 0.88, 0.5) if big else wcol.lerp(Color(1, 1, 1), 0.4)
		var sweep_down: bool = sl.combo != 1
		for k in n:
			var f := float(k) / float(n - 1)
			if f > reveal:
				break
			var u := f if sweep_down else 1.0 - f
			var a: float = base_a + float(sl.facing if sl.kind == "side" else 1) * lerpf(-spread, spread, u)
			var pt := center + Vector2(cos(a), sin(a)) * radius
			var cc := col
			cc.a = alpha * (0.5 + 0.5 * f)
			_glyph(pt, _tangent_glyph(a), cc, 1.25 if big else 1.1)
			var inner := center + Vector2(cos(a), sin(a)) * radius * 0.7
			cc.a *= 0.45
			_glyph(inner, _tangent_glyph(a) if k % 2 == 0 else "·", cc, 0.9)


static func _tangent_glyph(a: float) -> String:
	var d := fposmod(a + PI * 0.5, PI)
	if d < PI / 8.0 or d > PI * 7.0 / 8.0:
		return "-"
	if d < PI * 3.0 / 8.0:
		return "\\"
	if d < PI * 5.0 / 8.0:
		return "|"
	return "/"


## Draws a multi-row sprite with its bottom row standing on foot (world units).
## fr is either an Array of rows or {"g": rows, "m": palette masks}.
func _sprite(fr: Variant, foot: Vector2, facing: int, pal: Array, cmap: Dictionary, anchor: float,
		tint: Color = Color(1, 1, 1), ghost: bool = false, flash: bool = false) -> void:
	var rows: Array = fr.g if fr is Dictionary else fr
	var masks: Array = fr.m if fr is Dictionary else []
	var n := rows.size()
	var dir := 1.0 if facing >= 0 else -1.0
	for i in n:
		var line: String = rows[i]
		var mask: String = masks[i] if i < masks.size() else ""
		var y := foot.y - (n - 1 - i) * D.GH - D.GH * 0.5
		for j in line.length():
			var ch := line[j]
			if ch == " ":
				continue
			if dir < 0.0:
				ch = S.MIRROR.get(ch, ch)
			var col: Color
			if ghost:
				col = tint
			elif flash:
				col = Color(1, 1, 1)
			else:
				var pidx := 0
				if mask != "" and j < mask.length() and mask[j] != " ":
					pidx = int(mask[j])
				elif cmap.has(line[j]):
					pidx = cmap[line[j]]
				col = pal[mini(pidx, pal.size() - 1)] * tint
				col.a = tint.a
			var wp := Vector2(foot.x + (j - anchor) * D.GW * dir, y)
			if not ghost:
				_glyph(wp, ch, Color(0, 0, 0, 0.75 * col.a), 1.12, null, Vector2(1.5, 1.5))
			_glyph(wp, ch, col, 1.12)


# ---------------------------------------------------------------- lights

func _collect_lights() -> void:
	lights.clear()
	var b: Dictionary = game.biome
	var view := Rect2(screen_to_world(Vector2.ZERO) - Vector2(200, 200), vp / s + Vector2(400, 400))
	var p: Dictionary = game.player
	if not p.is_empty() and not game.is_title() and not p.dead:
		_light(Physics.center(p), 190.0, b.light, 0.9)
	for tp in game.lv.torches:
		if view.has_point(tp):
			_light(tp, 110.0 + sin(t * 9.0 + tp.x) * 6.0, b.torch, 1.0)
	for ll in _lava_lights:
		if view.has_point(Vector2(ll.x, ll.y)):
			_light(Vector2(ll.x, ll.y), ll.z, Color(1.0, 0.45, 0.15), 0.9)
	for d in _decor_lights:
		var dp := Vector2((d.x + 0.5) * D.TILE, (d.y + 0.5) * D.TILE)
		if view.has_point(dp):
			var c := Color(0.5, 0.85, 1.0) if b.id != "ember" else Color(1.0, 0.45, 0.25)
			if d.kind == "mushroom":
				c = Color(0.55, 0.75, 1.0) if b.id == "hollow" else Color(1.0, 0.5, 0.4)
			elif d.kind == "candle":
				c = Color(1.0, 0.7, 0.35)
			_light(dp, 70.0 if d.kind == "candle" else 55.0, c, 0.7)
	for pr in game.props:
		if not view.has_point(pr.pos):
			continue
		match pr.kind:
			"shrine":
				if not pr.used:
					_light(pr.pos - Vector2(0, 20), 120.0, Color(0.55, 1.0, 0.75), 0.9)
			"chest":
				if not pr.open:
					_light(pr.pos - Vector2(0, 6), 60.0, Color(1.0, 0.8, 0.4), 0.6)
			"shop":
				_light(pr.pos - Vector2(-12, 30), 120.0, Color(1.0, 0.8, 0.5), 0.9)
	if game.lv.door_open and game.lv.door.size != Vector2.ZERO:
		_light(game.lv.door.get_center(), 100.0, b.top, 0.8)
	for pr in game.projectiles:
		if pr.delay <= 0.0 and lights.size() < MAX_LIGHTS - 4:
			_light(pr.pos, 40.0, Combat.SHOT_LOOK.get(pr.kind, Combat.SHOT_LOOK.shot)[1], 0.6)
	for hz in game.hazards:
		if hz.t >= hz.warn:
			_light(Vector2(hz.x, hz.y - 50.0), 110.0, Color(1.0, 0.55, 0.2), 1.0)
	if game.post != null:
		var mat := game.post.material as ShaderMaterial
		var pos := PackedVector4Array()
		var cols := PackedVector4Array()
		lights.sort_custom(func(a, c2): return a[3] > c2[3])
		for i in mini(lights.size(), MAX_LIGHTS):
			var l: Array = lights[i]
			pos.append(Vector4(l[0].x, l[0].y, l[1], 0.0))
			cols.append(Vector4(l[2].r, l[2].g, l[2].b, 0.0))
		while pos.size() < MAX_LIGHTS:
			pos.append(Vector4(-9999, -9999, 1, 0))
			cols.append(Vector4(0, 0, 0, 0))
		mat.set_shader_parameter("light_pos", pos)
		mat.set_shader_parameter("light_col", cols)
		mat.set_shader_parameter("light_count", mini(lights.size(), MAX_LIGHTS))
		mat.set_shader_parameter("ambient", b.ambient if not game.is_title() else b.ambient + 0.15)


func _light(w: Vector2, radius: float, c: Color, intensity: float) -> void:
	var p := sp(w)
	var r := radius * s
	if p.x < -r or p.y < -r or p.x > vp.x + r or p.y > vp.y + r:
		return
	var prio := intensity * 1000.0 - p.distance_to(vp * 0.5) * 0.1
	lights.append([p, r, Color(c.r * intensity, c.g * intensity, c.b * intensity), prio])
