## Draws the world with glyphs on a fine text grid (4 x 3 glyphs per tile).
## Static terrain is painted once into cached chunks; the parallax layers are
## cached too, split into buckets so only the ones on screen are drawn. Everything that moves (grass, water, entities, effects) is drawn
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
const WeaponArt := preload("res://scripts/weapon_art.gd")
const DecorArt := preload("res://scripts/decor_art.gd")

## Tiles visible vertically at each zoom level.
const ZOOMS := [30.0, 24.0, 19.0]
## Terrain is painted in square chunks of CHUNK tiles; small chunks keep each
## paint short. AHEAD rings around the view are painted early, one per frame.
const CHUNK := 8
const AHEAD := 2
## Size of a parallax bucket, in layer units.
const BG_CELL := 320.0
const MAX_LIGHTS := 32
const GRASS := ["'", ",", "\"", "`", "'", ";"]


## A canvas item whose drawing is done by a callback and cached until redrawn.
class Painter:
	extends Node2D
	var fn: Callable
	var arg: Variant

	func _draw() -> void:
		if fn.is_valid():
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
var _bg_buckets: Array = []
var _far: Painter
var _mid: Painter
var _terrain: Node2D
var _dyn: Painter
var _bd := Backdrop.new()
var _lava_lights: Array = []
var _decor_lights: Array = []
var _motes: Array = []
var _dyn_tiles := {}
## Ceiling decor and torches bucketed per chunk, so only those in view are visited.
var _ceil_idx := {}
var _torch_idx := {}
var _gate_set := {}
var _adv_cache := {}
var _deferred: Array = []
var _defer_ci: CanvasItem = null
var _last_key := ""
var lights: Array = []
var _low := false
var _shadow_key := ""
var _shadow_polys: Array = []


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
	for bk in _bg_buckets:
		bk[0].queue_redraw()
	for k in _chunks:
		_chunks[k].queue_redraw()


func on_level_built() -> void:
	for k in _chunks:
		_chunks[k].queue_free()
	_chunks.clear()
	var lv = game.lv
	_gate_set.clear()
	for ar in lv.arenas:
		for gt in ar.gates:
			_gate_set[gt] = true
	_compute_depth(Rect2i(0, 0, lv.w, lv.h))
	_index_dynamic_tiles()
	_ceil_idx.clear()
	for d in lv.decor:
		if d.kind in ["vine", "root", "stalactite", "chain", "web"]:
			_bucket(_ceil_idx, Vector2i(d.x, d.y), d)
	_torch_idx.clear()
	for tp in lv.torches:
		_bucket(_torch_idx, Vector2i(int(tp.x / D.TILE), int(tp.y / D.TILE)), tp)
	_bd.generate(game.biome, lv.pixel_size(), game.level_num * 7919 + game.run_seed % 1000)
	_build_bg_buckets()
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


## A few tiles changed (a wall broke): depth and the dynamic index are updated
## around them, and only the chunks they touch are painted again.
func tiles_changed(list: Array) -> void:
	if list.is_empty():
		return
	var lv = game.lv
	var lo: Vector2i = list[0]
	var hi: Vector2i = list[0]
	for tp in list:
		lo = Vector2i(mini(lo.x, tp.x), mini(lo.y, tp.y))
		hi = Vector2i(maxi(hi.x, tp.x), maxi(hi.y, tp.y))
	var m := 5
	var r := Rect2i(lo - Vector2i(m, m), hi - lo + Vector2i(m * 2 + 1, m * 2 + 1)).intersection(Rect2i(0, 0, lv.w, lv.h))
	_compute_depth(r)
	for cy in range(r.position.y / CHUNK, (r.end.y - 1) / CHUNK + 1):
		for cx in range(r.position.x / CHUNK, (r.end.x - 1) / CHUNK + 1):
			var k := Vector2i(cx, cy)
			_index_chunk(k)
			if _chunks.has(k):
				_chunks[k].queue_redraw()


static func _bucket(idx: Dictionary, tile: Vector2i, v: Variant) -> void:
	var k := Vector2i(tile.x / CHUNK, tile.y / CHUNK)
	if not idx.has(k):
		idx[k] = []
	idx[k].append(v)


## The chunks under the screen (plus one tile around it), as [from, to].
func _view_chunks() -> Array:
	var lv = game.lv
	var tl := screen_to_world(Vector2.ZERO) - Vector2(D.TILE, D.TILE)
	var br := screen_to_world(vp) + Vector2(D.TILE, D.TILE)
	var csz := CHUNK * D.TILE
	return [Vector2i(maxi(0, int(floor(tl.x / csz))), maxi(0, int(floor(tl.y / csz)))),
		Vector2i(mini(int(ceil(float(lv.w) / CHUNK)) - 1, int(floor(br.x / csz))), mini(int(ceil(float(lv.h) / CHUNK)) - 1,
			int(floor(br.y / csz))))]


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
	var t0 := Time.get_ticks_usec()
	_process_inner(delta)
	game.prof_add("world_proc", t0)


func _process_inner(delta: float) -> void:
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
	_low = game.cfg.get_v("quality") == "low"
	_place_layers()
	queue_redraw()
	_dyn.queue_redraw()
	_collect_lights()


func _place_layers() -> void:
	var cam: Vector2 = game.cam
	_far.position = (vp * 0.5 - cam * Backdrop.FAR * s + off * 0.3).round()
	_mid.position = (vp * 0.5 - cam * Backdrop.MID * s + off * 0.5).round()
	var screen := Rect2(Vector2.ZERO, vp)
	for bk in _bg_buckets:
		var r: Rect2 = bk[2]
		var layer: Node2D = bk[1]
		bk[0].visible = screen.intersects(Rect2(r.position * s + layer.position, r.size * s))
	var lv = game.lv
	var nx := int(ceil(float(lv.w) / CHUNK))
	var ny := int(ceil(float(lv.h) / CHUNK))
	var csz := CHUNK * D.TILE
	var tl := screen_to_world(Vector2.ZERO)
	var br := screen_to_world(vp)
	var cx0 := maxi(0, int(floor(tl.x / csz)) - 1)
	var cy0 := maxi(0, int(floor(tl.y / csz)) - 1)
	var cx1 := mini(nx - 1, int(floor(br.x / csz)) + 1)
	var cy1 := mini(ny - 1, int(floor(br.y / csz)) + 1)
	# Chunks in view are painted now; the rings around it are painted ahead of
	# time, the nearest missing one each frame, so scrolling never has to wait.
	var mid := Vector2i((cx0 + cx1) / 2, (cy0 + cy1) / 2)
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for cy in range(maxi(0, cy0 - AHEAD), mini(cy1 + AHEAD, ny - 1) + 1):
		for cx in range(maxi(0, cx0 - AHEAD), mini(cx1 + AHEAD, nx - 1) + 1):
			var k := Vector2i(cx, cy)
			if _chunks.has(k):
				continue
			if cx >= cx0 and cx <= cx1 and cy >= cy0 and cy <= cy1:
				_new_chunk(k)
				continue
			var d := absi(cx - mid.x) + absi(cy - mid.y)
			if d < best_d:
				best_d = d
				best = k
	if best.x >= 0:
		_new_chunk(best)
	for k in _chunks:
		var p: Painter = _chunks[k]
		var on: bool = k.x >= cx0 and k.x <= cx1 and k.y >= cy0 and k.y <= cy1
		p.visible = on
		if on:
			p.position = (Vector2(k) * csz * s + base).round()


func _new_chunk(k: Vector2i) -> void:
	var p := Painter.new()
	p.fn = _paint_chunk
	p.arg = k
	_terrain.add_child(p)
	_chunks[k] = p


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
	for cy in int(ceil(float(lv.h) / CHUNK)):
		for cx in int(ceil(float(lv.w) / CHUNK)):
			_index_chunk(Vector2i(cx, cy))


func _index_chunk(k: Vector2i) -> void:
	var lv = game.lv
	var grass_cut := 0.6 if game.biome.look == "hollow" else 0.25
	var list: Array = []
	for y in range(k.y * CHUNK, mini(lv.h, (k.y + 1) * CHUNK)):
		for x in range(k.x * CHUNK, mini(lv.w, (k.x + 1) * CHUNK)):
			var tt: int = lv.tiles[y * lv.w + x]
			var keep := tt == Level.WATER or tt == Level.LAVA or tt == Level.GATE or _gate_set.has(Vector2i(x, y))
			if tt == Level.AIR and lv.solid(x, y + 1):
				keep = keep or _hash01(x, y) >= grass_cut
			if keep:
				list.append(Vector2i(x, y))
	if list.is_empty():
		_dyn_tiles.erase(k)
	else:
		_dyn_tiles[k] = list


## How deep each solid tile lies inside rock (0 = air, up to 9), within [r].
## Tiles outside [r] keep their depth and feed the edge of the region.
func _compute_depth(r: Rect2i) -> void:
	var lv = game.lv
	if _depth.size() != lv.w * lv.h:
		_depth.resize(lv.w * lv.h)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i: int = y * lv.w + x
			var tt: int = lv.tiles[i]
			_depth[i] = 9 if (tt == Level.SOLID or tt == Level.CRACKED) else 0
	for pass_i in 4:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
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
	var t0 := Time.get_ticks_usec()
	_draw_sky()
	game.prof_add("sky", t0)


func _draw_sky() -> void:
	var b: Dictionary = game.biome
	var top: Color = b.sky_top
	var bot: Color = b.sky_bot
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([top, top, bot, bot]))
	if b.sky:
		# moon and stars drift very slowly
		var title: bool = game.is_title()
		var mp: Vector2 = Vector2(vp.x * (0.87 if title else 0.78), vp.y * (0.1 if title else 0.15)) - game.cam * s * 0.02
		_draw_moon(mp, minf(24.0 * s, vp.y * 0.075))
		for i in 70:
			var sx := fposmod(_hash01(i, 3) * vp.x * 1.5 - game.cam.x * s * 0.05, vp.x)
			var sy := _hash01(i, 9) * vp.y * 0.6
			var tw := 0.35 + 0.35 * sin(t * (1.0 + _hash01(i, 5) * 2.0) + i)
			_gc(self, Vector2(sx, sy), "." if i % 3 else "+", Color(0.75, 0.7, 0.8, tw), fs, font)


## A blood moon: a halo that throbs like a heartbeat, a shaded disc with an
## eclipse shadow eating into it, craters that read as a skull with one burning
## eye that follows the hero and blinks, cracks, blood dripping from the rim,
## drifting black clouds and now and then a bat crossing it.
func _draw_moon(c: Vector2, r: float) -> void:
	var hb := fposmod(t, 1.5)
	var beat := exp(-hb * 8.0) + (0.7 * exp(-(hb - 0.28) * 8.0) if hb > 0.28 else 0.0)
	var pulse := 0.75 + 0.6 * beat
	for k in 7:
		var f := 1.0 + k * 0.45
		draw_circle(c, r * f, Color(0.6, 0.02, 0.03, 0.07 * pulse * (1.0 - k / 7.0)))
	var disc := _circle_poly(c, r, 40)
	# shading from deep blood at the rim to a sick glow toward the upper left
	for k in 7:
		var f := 1.0 - k / 7.0
		draw_circle(c + Vector2(-0.22, -0.26) * r * (1.0 - f), r * f, Color(0.42, 0.03, 0.03).lerp(Color(0.86, 0.22, 0.12), 1.0 - f))
	# craters: two sockets, a nose and a row of teeth, plus scattered pits
	var pits := [[-0.36, -0.12, 0.2], [0.14, -0.14, 0.19], [-0.1, 0.17, 0.08], [0.52, 0.34, 0.07], [-0.55, 0.3, 0.06],
		[0.1, -0.6, 0.06], [-0.2, -0.55, 0.05]]
	for i in 5:
		pits.append([-0.36 + i * 0.12, 0.43, 0.045])
	for q in pits:
		var pc := c + Vector2(q[0], q[1]) * r
		draw_circle(pc + Vector2(0.03, 0.04) * r, q[2] * r, Color(0.95, 0.38, 0.22, 0.35))
		draw_circle(pc, q[2] * r, Color(0.28, 0.02, 0.03, 0.85))
	# cracks
	var cracks := [[Vector2(-0.9, -0.2), Vector2(-0.55, -0.1), Vector2(-0.4, 0.05)],
		[Vector2(0.3, 0.6), Vector2(0.45, 0.8), Vector2(0.4, 0.95)],
		[Vector2(0.6, -0.7), Vector2(0.4, -0.45), Vector2(0.42, -0.3)]]
	for cr in cracks:
		var line := PackedVector2Array()
		for v in cr:
			line.append(c + v * r)
		draw_polyline(line, Color(0.2, 0.0, 0.02, 0.8), maxf(1.0, r * 0.03))
	# the eclipse shadow, kept inside the disc
	var sk := "%s|%.1f|%.2f" % [c, r, snappedf(sin(t * 0.05), 0.02)]
	if sk != _shadow_key:
		_shadow_key = sk
		var shadow := _circle_poly(c + Vector2(0.9, 0.12) * r * (0.95 + 0.05 * snappedf(sin(t * 0.05), 0.02)), r * 0.98, 40)
		_shadow_polys = Geometry2D.intersect_polygons(disc, shadow)
	for poly in _shadow_polys:
		draw_colored_polygon(poly, Color(0.07, 0.0, 0.01, 0.78))
	# black clouds drifting across
	for k in 3:
		var w := r * (2.6 + k * 0.7)
		var cx := c.x + fposmod(t * (6.0 + k * 3.0) * s + k * 140.0 * s, w + r * 6.0) - w * 0.5 - r * 3.0
		var cy := c.y + (-0.35 + k * 0.42) * r
		var ell := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			ell.append(Vector2(cx + cos(a) * w * 0.5, cy + sin(a) * r * 0.09))
		draw_colored_polygon(ell, Color(0.03, 0.01, 0.02, 0.72))
	_draw_moon_eye(c + Vector2(-0.36, -0.12) * r, r)
	# blood runs down from the lower rim and drips off
	var blood := Color(0.55, 0.02, 0.03)
	for i in 4:
		var x: float = [-0.32, 0.06, 0.3, -0.12][i]
		var top := c + Vector2(x, sqrt(1.0 - x * x) - 0.04) * r
		var ph := fposmod(t * 0.3 + i * 0.29, 1.0)
		var drip := r * 0.22 * minf(ph * 2.0, 1.0)
		draw_line(top, top + Vector2(0, drip), blood, maxf(1.0, r * 0.05))
		if ph > 0.5:
			var f := (ph - 0.5) * 2.0
			draw_circle(top + Vector2(0, drip + f * f * r * 3.0), maxf(1.0, r * 0.045), Color(blood, 1.0 - f))
	# a bat crosses the moon every so often
	var bt := fposmod(t, 23.0)
	if bt < 4.0:
		var bp := c + Vector2(lerpf(-2.2, 2.2, bt / 4.0) * r, sin(bt * 5.0) * r * 0.15 - r * 0.2)
		var bat := "^v^" if int(t * 8.0) % 2 == 0 else "vvv"
		var bw := bold.get_string_size(bat, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(bold, Vector2(bp.x - bw * 0.5, bp.y + fs * 0.36), bat, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.02, 0.0, 0.01))


## A burning slit eye in the moon's left socket that looks toward the hero and
## blinks every few seconds.
func _draw_moon_eye(e: Vector2, r: float) -> void:
	var look := Vector2(vp.x * 0.5, vp.y * 0.6)
	if not game.player.is_empty() and not game.is_title():
		look = sp(Physics.center(game.player))
	var bl := fposmod(t, 6.7)
	var open := 1.0 if bl > 0.24 else absf(bl - 0.12) / 0.12
	var glow := 0.75 + 0.25 * sin(t * 3.1)
	draw_circle(e, r * 0.32, Color(1.0, 0.35, 0.05, 0.14 * open * glow))
	var iris := Color(1.0, 0.72, 0.18).lerp(Color(1.0, 0.95, 0.5), glow - 0.75)
	draw_colored_polygon(_ellipse(e, Vector2(0.16, 0.13 * open + 0.01) * r, 20), iris)
	var pp := e + (look - e).normalized() * r * 0.06
	draw_colored_polygon(_ellipse(pp, Vector2(0.03, 0.11 * open + 0.005) * r, 12), Color(0.05, 0.0, 0.0))
	# a scowling brow slanting down toward the middle of the face
	draw_line(e + Vector2(-0.24, -0.27) * r, e + Vector2(0.22, -0.12) * r, Color(0.12, 0.0, 0.01), maxf(1.5, r * 0.08))


func _ellipse(c: Vector2, rad: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return out


func _circle_poly(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		out.append(c + Vector2.from_angle(TAU * i / n) * r)
	return out


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


func _paint_mid(_ci: CanvasItem, _arg: Variant) -> void:
	pass


## Splits both parallax layers into buckets: a canvas item submits all of its
## glyphs every frame, so one item per layer would draw the whole level.
func _build_bg_buckets() -> void:
	for bk in _bg_buckets:
		# the arrays are shared with the new level, so old buckets must not draw again
		bk[0].visible = false
		bk[0].fn = Callable()
		bk[0].queue_free()
	_bg_buckets.clear()
	_bucket_layer(_far, _bd.far_pos, _bd.far_g, _bd.far_c, true)
	_bucket_layer(_mid, _bd.mid_pos, _bd.mid_g, _bd.mid_c, false)


func _bucket_layer(layer: Node2D, pos: PackedVector2Array, gl: PackedStringArray, cols: PackedColorArray, far: bool) -> void:
	var cells := {}
	for i in pos.size():
		var k := Vector2i(floori(pos[i].x / BG_CELL), floori(pos[i].y / BG_CELL))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(i)
	for k in cells:
		var p := Painter.new()
		p.fn = _paint_bucket
		p.arg = [pos, gl, cols, cells[k], far]
		layer.add_child(p)
		_bg_buckets.append([p, layer, Rect2(Vector2(k) * BG_CELL - Vector2(24, 24), Vector2(BG_CELL + 48, BG_CELL + 48))])


func _paint_bucket(ci: CanvasItem, arg: Array) -> void:
	if game == null or game.lv == null:
		return
	var t0 := Time.get_ticks_usec()
	_paint_bucket_inner(ci, arg)
	game.prof_add("bg_bucket", t0)


func _paint_bucket_inner(ci: CanvasItem, arg: Array) -> void:
	var pos: PackedVector2Array = arg[0]
	var gl: PackedStringArray = arg[1]
	var cols: PackedColorArray = arg[2]
	var size := fs_far if arg[4] else fs
	for i in arg[3]:
		var c := cols[i]
		c.a = 1.0
		_gc(ci, pos[i] * s, gl[i], c, size, font)


func _paint_chunk(ci: CanvasItem, k: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	_defer_ci = ci
	_deferred.clear()
	_paint_chunk_inner(ci, k)
	_defer_ci = null
	_flush(ci)
	game.prof_add("chunk", t0)


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
				var depth := _dget(tx, ty)
				# rock gets darker away from open air
				ci.draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), _mul(fill, 1.3 - minf(depth, 6) * 0.07))
				var up_air: bool = not lv.solid(tx, ty - 1)
				var dn_air: bool = not lv.solid(tx, ty + 1)
				var l_air: bool = not lv.solid(tx - 1, ty)
				var r_air: bool = not lv.solid(tx + 1, ty)
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
							var chance := 0.9 if depth <= 1 else (0.6 if depth == 2 else (0.3 if depth == 3 else 0.13))
							if hv < chance:
								var set_g := edge_g if depth <= 1 else deep_g
								g = set_g[int(hv * 97.0) % set_g.length()]
								col = _mul(b.edge if depth <= 1 else inner, (0.8 if depth <= 1 else 1.2) - minf(depth, 6) * 0.08)
							elif depth >= 3 and hv > 0.988:
								# something buried in the rock
								match b.look:
									"wood":
										g = ["(", ")", "~", "j"][int(hv * 9000.0) % 4]
										col = Color(0.3, 0.2, 0.14)
									"ember":
										g = ["*", "'", "·"][int(hv * 9000.0) % 3]
										col = Color(0.75, 0.25, 0.08)
									_:
										g = ["°", "=", "o"][int(hv * 9000.0) % 3]
										col = Color(0.4, 0.37, 0.32)
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
			match b.look:
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
	DecorArt.paint_floor(self, ci, d, o, cell, b)


# ---------------------------------------------------------------- dynamic layer

func _paint_dynamic(_ci: CanvasItem, _arg: Variant) -> void:
	if game == null or game.lv == null:
		return
	var t0 := Time.get_ticks_usec()
	_paint_dynamic_inner()
	game.prof_add("dynamic", t0)


func _paint_dynamic_inner() -> void:
	var b: Dictionary = game.biome
	var tl := screen_to_world(Vector2.ZERO) - Vector2(D.TILE, D.TILE)
	var br := screen_to_world(vp) + Vector2(D.TILE, D.TILE)
	var view := Rect2(tl, br - tl)
	_draw_motes(b, view)
	var vc := _view_chunks()
	_draw_ceiling_decor(b, view, vc)
	_draw_torches(b, view, vc)
	_draw_door(b)
	_draw_props(view)
	_draw_tiles_dynamic(b, tl, br)
	_draw_items(view)
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
			_sprite(gh.frame, gh.foot, gh.facing, S.HERO_PAL, {}, S.HERO.a, Color(0.75, 0.12, 0.16, a), true, false, S.HERO.scale)
		_draw_hero()
		_draw_slashes()
		_draw_guide()
	for pt in game.particles:
		var c: Color = pt.c
		c.a = clampf(pt.life / pt.max, 0.0, 1.0)
		_glyph(pt.p, pt.g, c, pt.s)
	for pu in game.popups:
		var pc: Color = pu.color
		pc.a = clampf(pu.life * 2.0, 0.0, 1.0)
		var sp_p := sp(pu.pos)
		# grown crits use a few fixed sizes: every new size is rasterised once
		var fsz := int(fs * (1.6 + snappedf(maxf(0.0, pu.life - 0.8) * 2.0, 0.2) if pu.get("big", false) else 1.05))
		var w := bold.get_string_size(pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		_dyn.draw_string(bold, sp_p - Vector2(w * 0.5, 0), pu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, pc)
	if not game.near.is_empty() and game.is_playing():
		_draw_prompt(game.near)


## Everything bucketed in [idx] under the chunks [vc] covers.
func _in_view(idx: Dictionary, vc: Array) -> Array:
	var out: Array = []
	for cy in range(vc[0].y, vc[1].y + 1):
		for cx in range(vc[0].x, vc[1].x + 1):
			var k := Vector2i(cx, cy)
			if idx.has(k):
				out.append_array(idx[k])
	return out


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
	if h < 0.25 or b.look == "hollow" and h < 0.6 or (_low and h < 0.6):
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


func _draw_ceiling_decor(b: Dictionary, view: Rect2, vc: Array) -> void:
	for d in _in_view(_ceil_idx, vc):
		var top := Vector2((d.x + 0.5) * D.TILE, d.y * D.TILE)
		if not view.has_point(top):
			continue
		var n: int = d.v
		for k in n:
			var sway: float = sin(t * 1.3 + d.x * 0.7 + k * 0.5) * k * 0.35 if d.kind not in ["stalactite", "icicle"] else 0.0
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
				"stalactite", "icicle":
					if k > n / 2:
						break
					g = "V" if k == 0 else ("v" if k < n / 2 else "'")
					if d.kind == "icicle":
						c = Color(0.75, 0.9, 1.0, 0.9 - k * 0.15)
				"noose":
					g = "O" if k == n - 1 else "|"
					c = Color(0.62, 0.55, 0.4)
				"banner":
					g = "=" if k == 0 else ("V" if k == n - 1 else "|")
					c = Color(0.5, 0.08, 0.12) if k > 0 else Color(0.6, 0.5, 0.3)
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


func _draw_torches(b: Dictionary, view: Rect2, vc: Array) -> void:
	for tp in _in_view(_torch_idx, vc):
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
	_sprite(def.idle[0], foot, 1, pal, def.cmap, def.a, Color(1, 1, 1), false, false, def.get("scale", 1.0))
	if lv.door_open:
		var c: Color = b.top
		for i in 7:
			var ph := fmod(t * 0.5 + i * 0.143, 1.0)
			var p := Vector2(r.position.x + 3.0 + fmod(i * 7.3, r.size.x - 6.0), r.end.y - 4.0 - ph * (r.size.y + 4.0))
			c.a = 1.0 - ph
			_glyph(p, "·" if i % 2 == 0 else "'", c, 1.0, font)
		var pulse := 0.75 + 0.25 * sin(t * 3.0)
		_glyph(r.get_center() + Vector2(0, -2), ">", _mul(b.top, pulse), 1.3, bold)


func _draw_props(view: Rect2) -> void:
	for pr in game.props:
		if not view.grow(48.0).has_point(pr.pos):
			continue
		var def: Dictionary = S.PROPS[pr.kind]
		var fr: Array
		match pr.kind:
			"chest":
				fr = def.open[0] if pr.open else def.closed[0]
			"lantern":
				fr = def.lit[0] if pr.lit else def.unlit[0]
			_:
				fr = def.idle[0]
		var foot: Vector2 = pr.pos
		if pr.kind == "chest" and not pr.open:
			foot += Vector2(0, 0)
		_sprite(fr, foot, 1, def.pal, def.cmap, def.a, Color(1, 1, 1), false, false, def.get("scale", 1.0))
		if pr.kind == "lantern":
			var top := foot + Vector2(0, -D.GH * 4.5)
			if pr.lit:
				var fl := 0.8 + 0.2 * sin(t * 12.0 + foot.x)
				_glyph(top + Vector2(sin(t * 9.0) * 0.6, -D.GH * 0.2), "'", Color(1.0, 0.95, 0.7) * fl, 0.9)
				for i in 2:
					var ph := fmod(t * 0.6 + i * 0.5, 1.0)
					_glyph(top + Vector2(sin(t * 2.0 + i * 3.0) * 4.0, -8.0 - ph * 22.0), "·", Color(1.0, 0.7, 0.3, 1.0 - ph), 0.9, font)
			if game.checkpoint_prop == pr:
				_glyph(foot + Vector2(0, -D.GH * 7.2), "v", Color(1.0, 0.85, 0.45, 0.5 + 0.3 * sin(t * 3.0)), 0.9)


func _draw_prompt(pr: Dictionary) -> void:
	var label: String = game.key("interact") + " " + game.L("act_" + pr.kind)
	var p := sp(pr.pos + Vector2(0, -42))
	var size := int(fs * 0.95)
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var bob := sin(t * 4.0) * 2.0
	_dyn.draw_rect(Rect2(p.x - w * 0.5 - 6, p.y - size + bob - 3, w + 12, size + 8), Color(0, 0, 0, 0.65))
	_dyn.draw_string(font, Vector2(p.x - w * 0.5, p.y + bob), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.92, 0.7))


func _draw_items(view: Rect2) -> void:
	for pk in game.pickups:
		if not view.has_point(pk.pos):
			continue
		var p: Vector2 = pk.pos + Vector2(0, sin(t * 3.0 + pk.pos.x) * 2.0)
		if pk.kind == "heart":
			_glyph(p, "♥", Color(1.0, 0.35, 0.45), 1.3)
		elif pk.kind == "orb":
			var pulse := 0.8 + 0.2 * sin(t * 8.0 + pk.pos.x)
			_glyph(p, "o", Color(1.0, 0.3, 0.35) * pulse, 1.0)
			_glyph(p, "·", Color(1.0, 0.85, 0.85), 0.8)
		else:
			for i in 3:
				var a := t * 2.0 + i * TAU / 3.0
				_glyph(p + Vector2(cos(a), sin(a)) * 4.0, "*", Color(1.0, 0.85, 0.35), 0.9)
			_glyph(p, "◆", Color(1.0, 0.95, 0.6), 1.1)
	for sh in game.shards:
		if not view.has_point(sh.pos):
			continue
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
	var light: bool = hz.get("kind", "fire") == "light"
	while y > hz.y - 110.0:
		var c := Color(1.0, 0.75 - k * 0.025, 0.3 - k * 0.01)
		var side := Color(1.0, 0.45, 0.15, 0.7)
		if light:
			c = Color(0.85 - k * 0.01, 0.92, 1.0)
			side = Color(0.6, 0.75, 1.0, 0.6)
		var g: String = ["|", "*", "^", "|"][(k + int(t * 20.0)) % 4] if not light else ["|", "+", "|", "'"][(k + int(t * 14.0)) % 4]
		_glyph(Vector2(hz.x + sin(t * 30.0 + k) * 2.0, y), g, c, 1.1)
		_glyph(Vector2(hz.x - D.GW, y), "(", side, 1.0)
		_glyph(Vector2(hz.x + D.GW, y), ")", side, 1.0)
		y -= D.GH
		k += 1


func _draw_projectile(pr: Dictionary) -> void:
	if pr.delay > 0.0:
		if pr.kind in ["ember", "rock", "frost", "noose"]:
			var tx := int(pr.pos.x / D.TILE)
			var ty := int(pr.pos.y / D.TILE)
			while ty < game.lv.h and not game.lv.solid(tx, ty + 1):
				ty += 1
			if pr.delay < 0.6 and int(pr.delay * 12.0) % 2 == 0:
				_glyph(Vector2(pr.pos.x, (ty + 1) * D.TILE - 3.0), "!", Color(1.0, 0.4, 0.2), 1.1)
		return
	var look: Array = Combat.SHOT_LOOK.get(pr.kind, Combat.SHOT_LOOK.shot)
	var g: String = look[0]
	match pr.kind:
		"boomerang":
			_glyph(pr.pos, ["<", "^", ">", "v"][int(pr.t * 20.0) % 4], look[1], 1.4)
			return
		"chakram":
			_glyph(pr.pos, "✶" if int(pr.t * 16.0) % 2 == 0 else "*", look[1], 1.35)
			return
		"hook":
			_glyph(pr.pos, "J" if pr.vel.x >= 0.0 else "L", look[1], 1.4)
			_glyph(pr.pos - pr.vel.normalized() * 6.0, "·", Color(0.6, 0.6, 0.65, 0.7), 1.0)
			return
		"noose":
			_glyph(pr.pos + Vector2(0, -8), "|", Color(0.62, 0.55, 0.4, 0.8), 1.2)
			_glyph(pr.pos, "O", look[1], 1.5)
			return
		"hwave":
			_glyph(pr.pos, "^", look[1], 1.7)
			_glyph(pr.pos + Vector2(-signf(pr.vel.x) * 6.0, 2.0), "^", Color(look[1].r, look[1].g, look[1].b, 0.5), 1.2)
			return
	if pr.kind == "javelin":
		# a shaft of two dashes behind the point
		var dirv: Vector2 = pr.vel.normalized()
		_glyph(pr.pos - dirv * 7.0, "-", look[1], 1.4)
		_glyph(pr.pos - dirv * 14.0, "-", Color(look[1].r, look[1].g, look[1].b, 0.7), 1.3)
		g = ">" if pr.vel.x >= 0.0 else "<"
	elif pr.kind == "arrow" or pr.kind == "knife":
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
	elif e.chill > 0.0:
		tint = Color(0.6, 0.85, 1.0, tint.a)
	var foot := Physics.foot(e)
	if e.elite:
		for i in 4:
			var a := t * 3.0 + i * TAU / 4.0
			_glyph(Physics.center(e) + Vector2(cos(a) * e.size.x * 0.7, sin(a) * e.size.y * 0.6), "·", Color(1.0, 0.85, 0.3, 0.8), 1.0)
	_sprite(Foes.frame(e), foot, e.dir, def.pal, def.cmap, def.a, tint, false, flash, def.get("scale", 1.0))
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
		"hanged":
			if e.state == "hang" and e.has("rope_y"):
				var y0: float = e.rope_y
				while y0 < e.pos.y + 2.0:
					_glyph(Vector2(Physics.center(e).x, y0), "|", Color(0.62, 0.55, 0.4), 1.0)
					y0 += D.GH
		"bomber":
			if e.state == "fuse":
				_glyph(Physics.center(e) + Vector2(0, -14), "*", Color(1.0, 1.0, 0.6), 1.2 + sin(t * 40.0) * 0.3)
		"warden", "colossus", "wraith", "hangman", "abbess", "frost_king":
			if e.state in ["crouch", "tele", "raise", "ring", "hook"] and int(t * 10.0) % 2 == 0:
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
	if game.level_up_t > 2.0:
		tint = Color(0.7, 0.9, 1.0)
	_sprite(Hero.frame(p), Physics.foot(p), p.facing, S.HERO_PAL, {}, S.HERO.a, tint, false, false, S.HERO.scale)
	_draw_weapon(p, tint)


## The equipped weapon in the hero's hand (weapon_art.gd).
func _draw_weapon(p: Dictionary, tint: Color) -> void:
	var d: Dictionary = Items.def(p.weapon)
	var kind: String = d.get("kind", "sword")
	var pose := WeaponArt.pose(p, kind)
	var a: float = pose[0]
	var f: float = p.facing
	var shoulder := Physics.foot(p) + Vector2(f * 4.0, -15.0)
	var hand: Vector2 = shoulder + Vector2(cos(a) * f, sin(a)) * (4.5 + pose[1])
	var col: Color = d.get("color", Color(0.85, 0.9, 1.0)) * tint
	col.a = 1.0
	WeaponArt.draw(_dyn, kind, sp(hand), a, f, s, col, p.st.reach)
	if kind == "dagger":
		# the off hand holds a second fang, reversed
		WeaponArt.draw(_dyn, kind, sp(Physics.foot(p) + Vector2(-f * 3.0, -13.0)), a + 2.4, f, s, col * 0.8, p.st.reach)


## A small arrow circling the hero that points the way to the exit.
func _draw_guide() -> void:
	var p: Dictionary = game.player
	if not game.cfg.get_v("guide") or p.is_empty() or p.dead or not game.is_playing():
		return
	var target: Vector2 = game.guide_target()
	if target == Vector2.ZERO:
		return
	var c := Physics.center(p)
	var d := target - c
	if d.length() < 50.0:
		return
	var a := d.angle()
	var pos := sp(c + Vector2(cos(a), sin(a)) * (26.0 + sin(t * 4.0) * 2.0))
	# a small bone dagger pointing the way, over a faint ember glow
	var glow := 0.6 + 0.25 * sin(t * 4.0)
	_dyn.draw_circle(pos, 5.0 * s, Color(0.9, 0.25, 0.1, 0.18 * glow))
	_dyn.draw_set_transform(pos, a, Vector2(s, s))
	var blade := PackedVector2Array([Vector2(8, 0), Vector2(-1.5, 1.6), Vector2(-1.5, -1.6)])
	var edge := blade.duplicate()
	edge.append(blade[0])
	_dyn.draw_polyline(edge, Color(0.04, 0.0, 0.01, 0.8), 1.2, true)
	_dyn.draw_colored_polygon(blade, Color(0.92, 0.86, 0.74, glow))
	_dyn.draw_line(Vector2(-1.8, -3.6), Vector2(-1.8, 3.6), Color(0.55, 0.12, 0.1, glow), 1.3)
	_dyn.draw_line(Vector2(-2.2, 0), Vector2(-5.5, 0), Color(0.3, 0.22, 0.2, glow), 1.4)
	_dyn.draw_circle(Vector2(-6.3, 0), 1.1, Color(0.7, 0.12, 0.1, glow))
	_dyn.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _neck_pos() -> Vector2:
	var p: Dictionary = game.player
	return Physics.foot(p) + Vector2(-p.facing * 6.0, -D.GH * 2.9)


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
			"lunge":
				_draw_lunge(sl, c, wcol, alpha)
				continue
			"rise":
				base_a = -PI * 0.5 + sl.facing * 0.5
				center = c + Vector2(sl.facing * 6.0, -6)
		var big: bool = sl.combo == 2 or sl.kind == "rise"
		var radius: float = (27.0 if big else 20.0) * sl.reach
		var spread := deg_to_rad(95.0 if big else 80.0)
		var n := 16 if big else 12
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
			if big and k % 2 == 0:
				var outer := center + Vector2(cos(a), sin(a)) * radius * 1.22
				cc.a *= 0.6
				_glyph(outer, "·", cc, 0.8)


## The Dash Lunge: a long streak of glyphs in front of the hero.
func _draw_lunge(sl: Dictionary, c: Vector2, wcol: Color, alpha: float) -> void:
	var col := wcol.lerp(Color(1, 1, 1), 0.5)
	var n := int(9 * sl.reach)
	for k in n:
		var f := float(k) / float(n - 1)
		var cc := col
		cc.a = alpha * (0.3 + 0.7 * f)
		var x: float = c.x + sl.facing * (-14.0 + f * 52.0 * sl.reach)
		_glyph(Vector2(x, c.y - 1), "=" if k < n - 1 else (">" if sl.facing > 0 else "<"), cc, 1.15)
		if k % 2 == 0:
			cc.a *= 0.5
			_glyph(Vector2(x, c.y - 7), "-", cc, 0.8)
			_glyph(Vector2(x, c.y + 5), "-", cc, 0.8)


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
		tint: Color = Color(1, 1, 1), ghost: bool = false, flash: bool = false, sc: float = 1.0) -> void:
	var rows: Array = fr.g if fr is Dictionary else fr
	var masks: Array = fr.m if fr is Dictionary else []
	var n := rows.size()
	var dir := 1.0 if facing >= 0 else -1.0
	for i in n:
		var line: String = rows[i]
		var mask: String = masks[i] if i < masks.size() else ""
		var y := foot.y - ((n - 1 - i) * D.GH + D.GH * 0.5) * sc
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
			var wp := Vector2(foot.x + (j - anchor) * D.GW * sc * dir, y)
			if not ghost:
				_glyph(wp, ch, Color(0, 0, 0, 0.75 * col.a), 1.12 * sc, null, Vector2(1.5, 1.5) * sc)
			_glyph(wp, ch, col, 1.12 * sc)


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
			var c := Color(0.5, 0.85, 1.0) if b.look != "ember" else Color(1.0, 0.45, 0.25)
			if d.kind == "mushroom":
				c = Color(0.55, 0.75, 1.0) if b.look == "hollow" else Color(1.0, 0.5, 0.4)
			elif d.kind == "candle":
				c = Color(1.0, 0.7, 0.35)
			_light(dp, 70.0 if d.kind == "candle" else 55.0, c, 0.7)
	for pr in game.props:
		if not view.has_point(pr.pos):
			continue
		match pr.kind:
			"lantern":
				if pr.lit:
					_light(pr.pos - Vector2(0, 26), 130.0 + sin(t * 8.0 + pr.pos.x) * 5.0, Color(1.0, 0.72, 0.35), 1.0)
				else:
					_light(pr.pos - Vector2(0, 26), 40.0, Color(0.5, 0.45, 0.4), 0.4)
			"chest":
				if not pr.open:
					_light(pr.pos - Vector2(0, 6), 60.0, Color(1.0, 0.8, 0.4), 0.6)
			"shop":
				_light(pr.pos - Vector2(-12, 30), 120.0, Color(1.0, 0.8, 0.5), 0.9)
	if game.lv.door_open and game.lv.door.size != Vector2.ZERO:
		_light(game.lv.door.get_center(), 100.0, b.top, 0.8)
	# a faint glow around nearby enemies' eyes
	var eyes := 0
	for e in game.enemies:
		if eyes >= 8:
			break
		if view.has_point(Physics.center(e)) and e.kind != "wisp":
			eyes += 1
			var ec: Color = S.FOES[e.kind].pal[1]
			_light(Physics.center(e) + Vector2(e.dir * e.size.x * 0.25, -e.size.y * 0.2), 46.0 if not e.boss else 120.0, ec, 0.45)
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
		var cap: int = {"low": 12, "medium": 20}.get(game.cfg.get_v("quality"), MAX_LIGHTS)
		lights.resize(mini(lights.size(), cap))
		for i in lights.size():
			var l: Array = lights[i]
			pos.append(Vector4(l[0].x, l[0].y, l[1], 0.0))
			cols.append(Vector4(l[2].r, l[2].g, l[2].b, 0.0))
		while pos.size() < MAX_LIGHTS:
			pos.append(Vector4(-9999, -9999, 1, 0))
			cols.append(Vector4(0, 0, 0, 0))
		mat.set_shader_parameter("light_pos", pos)
		mat.set_shader_parameter("light_col", cols)
		mat.set_shader_parameter("light_count", lights.size())
		mat.set_shader_parameter("ambient", b.ambient if not game.is_title() else b.ambient + 0.15)
		mat.set_shader_parameter("flash", game.crit_flash)


func _light(w: Vector2, radius: float, c: Color, intensity: float) -> void:
	var p := sp(w)
	var r := radius * s
	if p.x < -r or p.y < -r or p.x > vp.x + r or p.y > vp.y + r:
		return
	var prio := intensity * 1000.0 - p.distance_to(vp * 0.5) * 0.1
	lights.append([p, r, Color(c.r * intensity, c.g * intensity, c.b * intensity), prio])
