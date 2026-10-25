## Draws the world with glyphs on a fine text grid (4 x 3 glyphs per tile).
## Static terrain is painted once into cached chunks; the parallax layers are
## cached too, split into buckets so only the ones on screen are drawn. Everything that moves (grass, water, entities, effects) is drawn
## every frame. Also collects light sources for the post-process shader.
extends Node2D

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const G := preload("res://scripts/gear_sprites.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Combat := preload("res://scripts/combat.gd")
const Backdrop := preload("res://scripts/backdrop.gd")
const Items := preload("res://scripts/items.gd")
const WeaponArt := preload("res://scripts/weapon_art.gd")
const Moon := preload("res://scripts/moon.gd")
const DecorArt := preload("res://scripts/decor_art.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")
const PixelTerrain := preload("res://scripts/pixel_terrain.gd")
const PixelArt := preload("res://scripts/pixel_art.gd")
## The glass of an unlit lantern.
## Particles that stay a single pixel; the rest are two.
const SMALL := ["·", ".", "'", ",", "`", "-", ":"]
const UNLIT := {"o": Color(0.18, 0.17, 0.2), "O": Color(0.26, 0.25, 0.28), "Y": Color(0.3, 0.29, 0.32)}

## Tiles visible vertically at each zoom level.
const ZOOMS := [30.0, 24.0, 19.0]
## Terrain is painted in square chunks of CHUNK tiles; small chunks keep each
## paint short. AHEAD rings around the view are painted early, one per frame.
const CHUNK := 8
const AHEAD := 2
## Size of a parallax bucket, in layer units.
const BG_CELL := 320.0
const MAX_LIGHTS := 32


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
## Pixels of the picture per world unit, a whole number set by the game
## (main._fit_pixels); 0 fits the zoom to the viewport instead.
var art_scale := 0.0
var s := 1.0
var vp := Vector2.ZERO
var off := Vector2.ZERO
var base := Vector2.ZERO
var t := 0.0
var fs := 12
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
var _last_key := ""
var lights: Array = []
var _low := false
var _moon := Moon.new()
## Sprite frames turned into flat glyph lists once (sprite_cache.gd), keyed by the
## hash of the frame and its colour map.


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b
	_adv_ratio = font.get_char_size("M".unicode_at(0), 100).x / 100.0
	_adv_ratio_b = bold.get_char_size("M".unicode_at(0), 100).x / 100.0
	_moon.setup(self)
	add_child(_moon)
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


## The size of the view in world units.
func view_size() -> Vector2:
	return vp / s if s > 0.0 else Vector2(1280, 800)


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
	s = art_scale if art_scale > 0.0 else vp.y / (ZOOMS[zoom_idx] * D.TILE)
	fs = maxi(5, int(round(D.GW * s / _adv_ratio)))
	adv = D.GW * s
	var key := "%d/%d/%d/%d" % [vp.x, vp.y, zoom_idx, s]
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
	_moon.place()
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


## A rectangle of the dynamic layer at world position [w], [size] world units.
func _box(w: Vector2, size: Vector2, col: Color) -> void:
	_dyn.draw_rect(Rect2(sp(w), size * s), col)


## A square of [n] world units centred on [w], on the pixel grid.
func _dot(w: Vector2, n: float, col: Color) -> void:
	var q := (sp(w) - Vector2(n, n) * s * 0.5).snapped(Vector2(s, s))
	_dyn.draw_rect(Rect2(q, Vector2(n, n) * s), col)


## A warning mark over [w]: a bar and a dot, [k] times the usual size.
func _bang(w: Vector2, col: Color, k: float = 1.0) -> void:
	var u := roundf(k * 1.5)
	_box(w + Vector2(-u * 0.5, -u * 5.0), Vector2(u, u * 3.0), col)
	_box(w + Vector2(-u * 0.5, -u), Vector2(u, u), col)


## A line between world points [a] and [b], [wd] world units wide.
func _seg(a: Vector2, b: Vector2, col: Color, wd: float = 1.0) -> void:
	_dyn.draw_line(sp(a), sp(b), col, wd * s)


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
	var w: int = lv.w
	var h: int = lv.h
	if _depth.size() != w * h:
		_depth.resize(w * h)
	var tiles: PackedByteArray = lv.tiles
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i: int = y * w + x
			var tt: int = tiles[i]
			_depth[i] = 9 if (tt == Level.SOLID or tt == Level.CRACKED) else 0
	# distance to the nearest open tile (capped at 9) in two sweeps: from the
	# top left, then from the bottom right; outside the level counts as rock
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i: int = y * w + x
			var d: int = _depth[i]
			if d == 0:
				continue
			var l: int = _depth[i - 1] if x > 0 else 9
			var u: int = _depth[i - w] if y > 0 else 9
			_depth[i] = mini(d, mini(l, u) + 1)
	for y in range(r.end.y - 1, r.position.y - 1, -1):
		for x in range(r.end.x - 1, r.position.x - 1, -1):
			var i: int = y * w + x
			var d: int = _depth[i]
			if d == 0:
				continue
			var rr: int = _depth[i + 1] if x < w - 1 else 9
			var dn: int = _depth[i + w] if y < h - 1 else 9
			_depth[i] = mini(d, mini(rr, dn) + 1)


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
		# stars drift very slowly (the moon is drawn by its own layers)
		for i in 70:
			var sx := fposmod(_hash01(i, 3) * vp.x * 1.5 - game.cam.x * s * 0.05, vp.x)
			var sy := _hash01(i, 9) * vp.y * 0.6
			var tw := 0.35 + 0.35 * sin(t * (1.0 + _hash01(i, 5) * 2.0) + i)
			var sc := Color(0.75, 0.7, 0.8, tw)
			var sq := Vector2(sx, sy).snapped(Vector2(s, s))
			draw_rect(Rect2(sq, Vector2(s, s)), sc)
			if i % 3 == 0:
				sc.a *= 0.5
				draw_rect(Rect2(sq - Vector2(s, 0), Vector2(s * 3, s)), sc)
				draw_rect(Rect2(sq - Vector2(0, s), Vector2(s, s * 3)), sc)


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
		ci.draw_colored_polygon(poly, _mul(game.biome.far, 0.8))


func _paint_mid(_ci: CanvasItem, _arg: Variant) -> void:
	pass


## Splits both parallax layers into buckets, so only the parts of a layer
## on screen are submitted each frame.
func _build_bg_buckets() -> void:
	for bk in _bg_buckets:
		bk[0].visible = false
		bk[0].fn = Callable()
		bk[0].queue_free()
	_bg_buckets.clear()
	_bucket_layer(_far, _bd.far)
	_bucket_layer(_mid, _bd.mid)


func _bucket_layer(layer: Node2D, shapes: Array) -> void:
	var cells := {}
	for sh in shapes:
		var a := Backdrop.anchor(sh)
		var k := Vector2i(floori(a.x / BG_CELL), floori(a.y / BG_CELL))
		if not cells.has(k):
			cells[k] = [[], Rect2(a, Vector2.ZERO)]
		cells[k][0].append(sh)
		var box: Rect2 = sh.r if sh.has("r") else Rect2(sh.p[0], Vector2.ZERO).expand(sh.p[1]).expand(sh.p[2])
		cells[k][1] = cells[k][1].merge(box)
	for k in cells:
		var p := Painter.new()
		p.fn = _paint_bucket
		p.arg = cells[k][0]
		layer.add_child(p)
		_bg_buckets.append([p, layer, cells[k][1].grow(2.0)])


func _paint_bucket(ci: CanvasItem, arg: Array) -> void:
	if game == null or game.lv == null:
		return
	var t0 := Time.get_ticks_usec()
	for sh in arg:
		if sh.has("r"):
			var r: Rect2 = sh.r
			ci.draw_rect(Rect2(r.position * s, r.size * s), sh.c)
		else:
			var pts: PackedVector2Array = sh.p
			ci.draw_colored_polygon(PackedVector2Array([pts[0] * s, pts[1] * s, pts[2] * s]), sh.c)
	game.prof_add("bg_bucket", t0)


func _paint_chunk(ci: CanvasItem, k: Vector2i) -> void:
	var t0 := Time.get_ticks_usec()
	_paint_chunk_inner(ci, k)
	game.prof_add("chunk", t0)


func _paint_chunk_inner(ci: CanvasItem, k: Vector2i) -> void:
	var lv = game.lv
	var b: Dictionary = game.biome
	var T := D.TILE
	var origin := Vector2(k) * CHUNK * T
	var tile_px := T * s
	var fill: Color = _mul(b.fill, 1.15)
	for ty in range(k.y * CHUNK, mini(lv.h, (k.y + 1) * CHUNK)):
		for tx in range(k.x * CHUNK, mini(lv.w, (k.x + 1) * CHUNK)):
			var tt: int = lv.tiles[ty * lv.w + tx]
			var o := (Vector2(tx, ty) * T - origin) * s
			if tt == Level.SOLID or tt == Level.CRACKED:
				var depth := _dget(tx, ty)
				# rock gets darker away from open air
				ci.draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), _mul(fill, 1.3 - minf(depth, 6) * 0.07))
				PixelTerrain.solid(ci, lv, tx, ty, o, s, depth, b, tt == Level.CRACKED)
			elif tt == Level.AIR or tt == Level.WATER or tt == Level.GATE:
				_paint_backwall(ci, tx, ty, o, b)
			elif tt == Level.ONEWAY:
				_paint_backwall(ci, tx, ty, o, b)
				PixelTerrain.ledge(ci, lv, tx, ty, o, s, b, Level.ONEWAY)
			elif tt == Level.SPIKES:
				PixelTerrain.spikes(ci, tx, o, s)
	for d in lv.decor:
		if d.x >= k.x * CHUNK and d.x < (k.x + 1) * CHUNK and d.y >= k.y * CHUNK and d.y < (k.y + 1) * CHUNK:
			DecorArt.paint_floor(ci, d, (Vector2(d.x, d.y) * T - origin) * s, s, b)


## Dim masonry or earth behind the playable space, except under open sky.
func _paint_backwall(ci: CanvasItem, tx: int, ty: int, o: Vector2, b: Dictionary) -> void:
	var room = game.lv.room_at_tile(tx, ty)
	if room == null or (b.sky and room.gy == 0):
		return
	var tile_px := D.TILE * s
	var wall: Color = b.fill.lerp(b.sky_bot, 0.5)
	wall.a = 0.7
	ci.draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), wall)
	PixelTerrain.backwall(ci, tx, ty, o, s, b)


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
	_draw_door(b, view)
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
			_sprite(gh.frame, gh.foot, gh.facing, S.HERO_PAL, Color(0.75, 0.12, 0.16, a), true)
		_draw_hero()
		_draw_slashes()
		_draw_guide()
	for pt in game.particles:
		var c: Color = pt.c
		c.a = clampf(pt.life / pt.max, 0.0, 1.0)
		_dot(pt.p, maxf(1.0, roundf(pt.s * (1.0 if pt.g in SMALL else 2.0))), c)
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
		_dot(p, 1.0, c)


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
	var o := Vector2(x * T, y * T)
	match tt:
		Level.WATER, Level.LAVA:
			var lava := tt == Level.LAVA
			var surf: bool = lv.at(x, y - 1) == Level.AIR
			var col := Color(1.0, 0.45, 0.12) if lava else wc
			_dyn.draw_rect(Rect2(sp(o), Vector2(T * s + 1, T * s + 1)),
				Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.55 if not lava else 0.8))
			if surf:
				# a rippling bright edge, two pixels a step
				for i in 8:
					var wx := o.x + i * 2.0
					var ph := sin(wx * 0.15 + t * (2.0 if lava else 2.6))
					var wy := o.y + roundf(ph)
					_box(Vector2(wx, wy), Vector2(2, 1), _mul(col, 1.0 if ph > -0.3 else 0.75))
					_box(Vector2(wx, wy + 1.0), Vector2(2, 1), _mul(col, 0.5))
			# bubbles (or embers) rising through the tile
			for j in 2:
				var hv := _hash01(x * 3 + j, y)
				if hv > 0.45:
					continue
				var by := o.y + T - fmod(t * (6.0 if lava else 9.0) + hv * 40.0, T - 2.0)
				_box(Vector2(o.x + 2.0 + hv * 26.0, by), Vector2(1, 1), _mul(col, 0.9 if not lava else 1.3))
			if lava and surf and _hash01(x, int(t * 3.0)) < 0.02:
				game.particles.append({"p": Vector2((x + 0.5) * T, y * T), "v": Vector2(randf_range(-20, 20), -60),
					"g": "·", "c": Color(1.0, 0.6, 0.2), "life": 0.8, "max": 0.8, "grav": -20.0, "drag": 0.5, "s": 0.9})
		Level.GATE:
			# a portcullis: iron bars, a cross rail, spikes at the foot
			_box(o + Vector2(0, 7), Vector2(T, 2), Color(0.24, 0.23, 0.25))
			for bx in [1.0, 6.0, 11.0]:
				_box(o + Vector2(bx, 0), Vector2(3, T), Color(0.3, 0.29, 0.31))
				_box(o + Vector2(bx, 0), Vector2(1, T), Color(0.5, 0.48, 0.5))
				if lv.at(x, y + 1) != Level.GATE:
					_box(o + Vector2(bx + 1.0, T), Vector2(1, 2), Color(0.5, 0.48, 0.5))
			if lv.at(x, y - 1) != Level.GATE:
				_box(o, Vector2(T, 2), Color(0.42, 0.4, 0.42))


func _draw_grass(b: Dictionary, x: int, y: int, pc: Vector2) -> void:
	var T := D.TILE
	var h := _hash01(x, y)
	if h < 0.25 or b.look == "hollow" and h < 0.6 or (_low and h < 0.6):
		return
	var base := (y + 1) * T - 1.0
	for k in 8:
		var hk := _hash01(x * 8 + k, y + 77)
		if hk < 0.45:
			continue
		var wx := x * T + k * 2.0 + 0.5
		var lean := sin(wx * 0.045 - t * 1.8 + h * 2.0) + 0.5 * sin(wx * 0.13 + t * 0.7)
		var dx := wx - pc.x
		# the hero's feet push the blades aside
		if absf(dx) < 10.0 and absf(pc.y - (y + 1) * T) < 24.0:
			lean = 2.0 * signf(dx)
		var bh := 2.0 + floorf(hk * 4.0)
		var c: Color = _mul(b.grass, 0.55 + 0.4 * hk + maxf(0.0, lean - 0.6) * 0.25)
		var tip := roundf(clampf(lean, -1.5, 1.5))
		_box(Vector2(wx, base - bh * 0.5 + 1.0), Vector2(1, bh * 0.5), c)
		_box(Vector2(wx + tip, base - bh + 1.0), Vector2(1, bh * 0.5), _mul(c, 1.1))


func _draw_ceiling_decor(b: Dictionary, view: Rect2, vc: Array) -> void:
	for d in _in_view(_ceil_idx, vc):
		var top := Vector2((d.x + 0.5) * D.TILE, d.y * D.TILE)
		if not view.has_point(top):
			continue
		var n: int = d.v
		var length: float = n * D.GH
		var still: bool = d.kind in ["stalactite", "icicle", "web"]
		var sway := 0.0 if still else sin(t * 1.3 + d.x * 0.7)
		match d.kind:
			"chain":
				var y := 0.0
				var k := 0
				while y < length:
					var p := top + Vector2(roundf(sway * y * 0.07), y)
					var c := Color(0.55, 0.55, 0.6) if k % 2 == 0 else Color(0.36, 0.36, 0.4)
					_box(p + Vector2(-1, 0), Vector2(2, 2) if k % 2 == 0 else Vector2(1, 2), c)
					y += 2.0
					k += 1
				var end := top + Vector2(roundf(sway * length * 0.07), length)
				_box(end + Vector2(-1, 0), Vector2(1, 3), Color(0.6, 0.6, 0.66))
				_box(end + Vector2(-1, 2), Vector2(3, 1), Color(0.6, 0.6, 0.66))
			"vine", "root", "noose":
				var c: Color = _mul(b.grass, 0.7) if d.kind == "vine" else (Color(0.42, 0.31, 0.21) if d.kind == "root" else Color(0.62, 0.55, 0.4))
				var y := 0.0
				while y < length:
					var zig: float = 0.0 if d.kind != "root" else [0.0, 1.0, 0.0, -1.0][int(y / 3.0) % 4]
					var p := top + Vector2(roundf(sway * y * 0.07) + zig, y)
					var w := 2.0 if d.kind == "root" and y < length * 0.4 else 1.0
					_box(p, Vector2(w, 3), _mul(c, 1.0 - y / length * 0.3))
					if d.kind == "vine" and int(y / 3.0) % 2 == 1:
						_box(p + Vector2(-2.0 if int(y / 6.0) % 2 == 0 else 1.0, 1), Vector2(2, 1), _mul(c, 1.2))
					y += 3.0
				var end := top + Vector2(roundf(sway * length * 0.07), length)
				if d.kind == "noose":
					for q in [Vector2(-1, 0), Vector2(-2, 1), Vector2(1, 1), Vector2(-2, 2), Vector2(1, 2), Vector2(-1, 3)]:
						_box(end + q, Vector2(2 if q.x == -1 else 1, 1), c)
				elif d.kind == "vine" and d.x % 3 == 0:
					_box(end + Vector2(-1, 0), Vector2(2, 2), Color(0.6, 0.08, 0.1))
			"stalactite", "icicle":
				var c: Color = Color(0.75, 0.9, 1.0, 0.9) if d.kind == "icicle" else _mul(b.edge, 0.7)
				var len2 := (n / 2 + 1) * D.GH
				var w := 3.0 + n * 0.5
				_dyn.draw_colored_polygon(PackedVector2Array([sp(top + Vector2(-w, 0)), sp(top + Vector2(w, 0)), sp(top + Vector2(0, len2))]), c)
				_box(top + Vector2(-1, 0), Vector2(1, len2 * 0.6), _mul(c, 1.3))
			"banner":
				var cloth := Color(0.5, 0.08, 0.12)
				var x0 := top.x - 3.0 + roundf(sway * 0.6)
				var pts := PackedVector2Array([sp(Vector2(x0, top.y + 1)), sp(Vector2(x0 + 6, top.y + 1)), sp(Vector2(x0 + 6, top.y + length)),
					sp(Vector2(x0 + 3, top.y + length - 3)), sp(Vector2(x0, top.y + length))])
				_dyn.draw_colored_polygon(pts, cloth)
				_box(Vector2(x0, top.y + 4), Vector2(6, 1), Color(0.75, 0.6, 0.3))
				_box(top + Vector2(-4, 0), Vector2(8, 1), Color(0.6, 0.5, 0.3))
			"web":
				var c := Color(0.8, 0.8, 0.85, 0.35)
				var o := sp(top)
				for a in [0.15, 0.5, 0.85]:
					_dyn.draw_line(o, o + Vector2.from_angle(PI * a) * 12.0 * s, c, maxf(1.0, s * 0.6))
				for rr in [5.0, 9.0]:
					_dyn.draw_arc(o, rr * s, PI * 0.15, PI * 0.85, 6, c, maxf(1.0, s * 0.6))


func _draw_torches(b: Dictionary, view: Rect2, vc: Array) -> void:
	for tp in _in_view(_torch_idx, vc):
		if not view.has_point(tp):
			continue
		var fl := sin(t * 13.0 + tp.x) * 0.5 + sin(t * 7.3 + tp.y) * 0.5
		var fc: Color = b.torch
		if b.sky:
			# a lamp on a post
			var floor_y: float = tp.y + D.TILE * 2.5
			_box(Vector2(tp.x - 1.0, tp.y + 3.0), Vector2(2, floor_y - tp.y - 3.0), Color(0.3, 0.23, 0.17))
			PixelArt.draw(_dyn, "post_lamp", sp(tp + Vector2(0, 4)), s, {}, false, Color(1, 1, 1) * (1.0 + fl * 0.1))
		else:
			# a sconce on the wall with a living flame
			_box(tp + Vector2(-0.5, 2), Vector2(1, 4), Color(0.3, 0.24, 0.2))
			_box(tp + Vector2(-1.5, 5), Vector2(3, 1), Color(0.36, 0.34, 0.38))
			_box(tp + Vector2(-2.5, 0), Vector2(5, 2), Color(0.42, 0.38, 0.36))
			var sx := roundf(fl)
			_box(tp + Vector2(-1.5, -3), Vector2(3, 3), _mul(fc, 1.0))
			_box(tp + Vector2(-0.5 + sx * 0.5, -5), Vector2(1 + absf(sx), 2), _mul(fc, 1.15))
			_box(tp + Vector2(-0.5, -2), Vector2(1, 2), Color(1.0, 0.9, 0.6))
			if fl > 0.3:
				_box(tp + Vector2(sx - 0.5, -7), Vector2(1, 1), _mul(fc, 0.8))


func _draw_door(b: Dictionary, view: Rect2) -> void:
	var lv = game.lv
	var r: Rect2 = lv.door
	if r.size == Vector2.ZERO or not lv.door_open or not view.grow(D.TILE * 2.0).intersects(r):
		return
	var glow: Color = b.top.lerp(b.torch, 0.5)
	var pulse := 0.85 + 0.15 * sin(t * 3.0)
	var tex := PixelArt.door_tex(int(r.size.x), int(r.size.y), b.edge, glow)
	_dyn.draw_texture_rect(tex, Rect2(sp(r.position), r.size * s), false, Color(pulse, pulse, pulse))
	var c: Color = b.top
	for i in 7:
		var ph := fmod(t * 0.5 + i * 0.143, 1.0)
		c.a = 1.0 - ph
		_box(Vector2(r.position.x + 4.0 + fmod(i * 7.3, r.size.x - 8.0), r.end.y - 4.0 - ph * (r.size.y - 8.0)), Vector2(1, 1), c)
	# a chevron pointing on, through the arch
	var ac := _mul(b.top, 0.8 + 0.2 * sin(t * 3.0))
	var mid := r.get_center() + Vector2(-1, 2)
	for k in 3:
		_box(mid + Vector2(k - 1, -3 + k), Vector2(1, 1), ac)
		_box(mid + Vector2(k - 1, 3 - k), Vector2(1, 1), ac)


func _draw_props(view: Rect2) -> void:
	for pr in game.props:
		if not view.grow(48.0).has_point(pr.pos):
			continue
		var foot: Vector2 = pr.pos
		match pr.kind:
			"chest":
				PixelArt.draw(_dyn, "chest_open" if pr.open else "chest", sp(foot), s)
			"lantern":
				PixelArt.draw(_dyn, "lantern", sp(foot), s, {} if pr.lit else UNLIT)
			"shop":
				PixelArt.draw(_dyn, "shop", sp(foot), s)
			_:
				PixelArt.draw(_dyn, "sign", sp(foot), s)
		if pr.kind == "lantern":
			var top := foot + Vector2(0, -24)
			if pr.lit:
				for i in 2:
					var ph := fmod(t * 0.6 + i * 0.5, 1.0)
					_box(top + Vector2(roundf(sin(t * 2.0 + i * 3.0) * 3.0), -6.0 - ph * 20.0), Vector2(1, 1), Color(1.0, 0.7, 0.3, 1.0 - ph))
			if game.checkpoint_prop == pr:
				# a small arrow over the lantern you come back to
				var ac := Color(1.0, 0.85, 0.45, 0.5 + 0.3 * sin(t * 3.0))
				var at := foot + Vector2(-2, -36)
				_box(at, Vector2(5, 1), ac)
				_box(at + Vector2(1, 1), Vector2(3, 1), ac)
				_box(at + Vector2(2, 2), Vector2(1, 1), ac)


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
		var p: Vector2 = pk.pos + Vector2(0, roundf(sin(t * 3.0 + pk.pos.x) * 2.0))
		if pk.kind == "heart":
			PixelArt.draw(_dyn, "heart", sp(p + Vector2(0, 3)), s)
		elif pk.kind == "orb":
			var pulse := 0.8 + 0.2 * sin(t * 8.0 + pk.pos.x)
			PixelArt.draw(_dyn, "orb", sp(p + Vector2(0, 2.5)), s, {}, false, Color(pulse, pulse, pulse))
		else:
			for i in 3:
				var a := t * 2.0 + i * TAU / 3.0
				_box(p + Vector2(cos(a), sin(a)) * 5.0 - Vector2(0.5, 0.5), Vector2(1, 1), Color(1.0, 0.85, 0.35))
			PixelArt.draw(_dyn, "gem", sp(p + Vector2(0, 2.5)), s)
	for sh in game.shards:
		if not view.has_point(sh.pos):
			continue
		var c := _mul(Color(1.0, 0.85, 0.35), 0.8 + 0.2 * sin(t * 10.0 + sh.pos.x))
		var q: Vector2 = sh.pos + sh.size * 0.5
		_box(q - Vector2(1, 1), Vector2(2, 2), c)
		_box(q - Vector2(1, 1), Vector2(1, 1), Color(1.0, 0.97, 0.8))


func _draw_hazard(hz: Dictionary) -> void:
	if hz.t < hz.warn:
		if int(hz.t * 12.0) % 2 == 0:
			_bang(Vector2(hz.x, hz.y - 6.0), Color(1.0, 0.35, 0.2), 1.3)
		_box(Vector2(hz.x - 3.0, hz.y - 2.0), Vector2(6, 1), Color(1.0, 0.55, 0.2, 0.6))
		return
	var light: bool = hz.get("kind", "fire") == "light"
	var core := Color(1.0, 0.85, 0.45) if not light else Color(0.9, 0.95, 1.0)
	var side := Color(1.0, 0.45, 0.15, 0.7) if not light else Color(0.6, 0.75, 1.0, 0.6)
	var y: float = hz.y
	var k := 0
	# a pillar of flame (or light): a bright core flickering inside a wider sheath
	while y > hz.y - 110.0:
		var wob := roundf(sin(t * 30.0 + k * 1.7) * 1.2)
		var c := core.darkened(k * 0.025)
		_box(Vector2(hz.x - 4.0 + wob, y - 4.0), Vector2(8, 4), side)
		_box(Vector2(hz.x - 2.0 - wob * 0.5, y - 4.0), Vector2(4, 4), c)
		if (k + int(t * 20.0)) % 3 == 0:
			_box(Vector2(hz.x - 6.0 + wob * 2.0, y - 3.0), Vector2(1, 2), side)
			_box(Vector2(hz.x + 5.0 - wob, y - 2.0), Vector2(1, 2), side)
		y -= 4.0
		k += 1


func _draw_projectile(pr: Dictionary) -> void:
	if pr.delay > 0.0:
		if pr.kind in ["ember", "rock", "frost", "noose"]:
			var tx := int(pr.pos.x / D.TILE)
			var ty := int(pr.pos.y / D.TILE)
			while ty < game.lv.h and not game.lv.solid(tx, ty + 1):
				ty += 1
			if pr.delay < 0.6 and int(pr.delay * 12.0) % 2 == 0:
				_bang(Vector2(pr.pos.x, (ty + 1) * D.TILE - 2.0), Color(1.0, 0.4, 0.2), 1.0)
		return
	var look: Array = Combat.SHOT_LOOK.get(pr.kind, Combat.SHOT_LOOK.shot)
	var col: Color = look[1]
	var dim := Color(col.r, col.g, col.b, col.a * 0.5)
	var p: Vector2 = pr.pos
	var dirv: Vector2 = pr.vel.normalized() if pr.vel.length() > 1.0 else Vector2.RIGHT
	match pr.kind:
		"boomerang", "chakram":
			# a spinning blade: two crossed bars turning
			var a: float = pr.t * (20.0 if pr.kind == "boomerang" else 28.0)
			var r := 4.0 if pr.kind == "boomerang" else 3.5
			for i in (2 if pr.kind == "boomerang" else 3):
				var q := Vector2.from_angle(a + i * PI / (2 if pr.kind == "boomerang" else 3)) * r
				_seg(p - q, p + q, col, 1.5)
			_dot(p, 1.0, Color(1, 1, 1, col.a))
		"hook":
			_seg(p - dirv * 8.0, p, Color(0.6, 0.6, 0.65, 0.7), 1.0)
			_box(p + Vector2(-1, -2), Vector2(2, 4), col)
			_box(p + Vector2(signf(dirv.x) * 1.0 - 1.0, 2), Vector2(3, 1), col)
		"noose":
			_seg(p + Vector2(0, -12), p + Vector2(0, -3), Color(0.62, 0.55, 0.4, 0.8), 1.0)
			_dyn.draw_arc(sp(p), 3.0 * s, 0.0, TAU, 10, col, s)
		"hwave":
			for i in 2:
				var q := p + Vector2(-signf(pr.vel.x) * 6.0 * i, 2.0 * i)
				var c := col if i == 0 else dim
				_dyn.draw_colored_polygon(PackedVector2Array([sp(q + Vector2(-5, 3)), sp(q + Vector2(0, -5)), sp(q + Vector2(5, 3))]), c)
		"javelin", "arrow", "knife":
			var len := 14.0 if pr.kind == "javelin" else (8.0 if pr.kind == "arrow" else 5.0)
			_seg(p - dirv * len, p, col if pr.kind != "arrow" else Color(0.6, 0.45, 0.3), 1.0)
			var side := dirv.orthogonal() * 2.0
			_dyn.draw_colored_polygon(PackedVector2Array([sp(p + dirv * 3.0), sp(p + side), sp(p - side)]), col)
			if pr.kind == "arrow":
				_seg(p - dirv * len, p - dirv * (len - 2.0) + side, dim, 1.0)
				_seg(p - dirv * len, p - dirv * (len - 2.0) - side, dim, 1.0)
		_:
			# a bolt: a bright core with a short fading tail
			var big := 1.5 if pr.kind == "wave" else 1.0
			for i in 3:
				var c := col
				c.a *= 0.25 + 0.25 * (2 - i) / 2.0
				_dot(p - dirv * (3.0 + i * 3.0) * big, (3.0 - i) * big, c)
			_dot(p, 4.0 * big, col)
			_dot(p, 2.0 * big, Color(1, 1, 1, col.a * 0.9))


func _draw_enemy(e: Dictionary) -> void:
	var def: Dictionary = SpriteCache.foe_def(e.kind)
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
			_dot(Physics.center(e) + Vector2(cos(a) * e.size.x * 0.7, sin(a) * e.size.y * 0.6), 1.0, Color(1.0, 0.85, 0.3, 0.8))
	_sprite(Foes.frame(e), foot, e.dir, def.pal, tint, false, flash)
	if e.elite:
		PixelArt.draw(_dyn, "gem", sp(foot + Vector2(0, -e.size.y - 6.0)), s)
	match e.kind:
		"knight":
			if e.state == "tele" and int(t * 14.0) % 2 == 0:
				_bang(Vector2(Physics.center(e).x, e.pos.y - 4), Color(1.0, 0.3, 0.25), 1.4)
		"spitter":
			if e.state == "charge":
				_dot(Physics.center(e) + Vector2(0, -12), 2.0, Color(1.0, 0.5, 0.4, 0.5 + 0.5 * sin(t * 30.0)))
		"archer":
			if e.state == "aim" and e.t < 0.3 and int(t * 14.0) % 2 == 0:
				_bang(Vector2(Physics.center(e).x, e.pos.y - 4), Color(1.0, 0.3, 0.25), 1.2)
		"hanged":
			if e.state == "hang" and e.has("rope_y"):
				var rx := Physics.center(e).x
				_seg(Vector2(rx, e.rope_y), Vector2(rx, e.pos.y + 2.0), Color(0.62, 0.55, 0.4), 1.0)
		"bomber":
			if e.state == "fuse":
				_dot(Physics.center(e) + Vector2(0, -14), 2.0 + roundf(sin(t * 40.0)), Color(1.0, 1.0, 0.6))
		"warden", "colossus", "wraith", "hangman", "abbess", "frost_king":
			if e.state in ["crouch", "tele", "raise", "ring", "hook"] and int(t * 10.0) % 2 == 0:
				_bang(Vector2(Physics.center(e).x, e.pos.y - 6), Color(1.0, 0.3, 0.25), 1.8)
	if not e.boss and e.hp < e.max_hp and e.hp > 0:
		var w: float = e.size.x
		var y: float = e.pos.y - 8.0
		var bw := 14.0
		var x0: float = roundf(e.pos.x + w * 0.5 - bw * 0.5)
		_box(Vector2(x0 - 1.0, y - 1.0), Vector2(bw + 2.0, 3.0), Color(0.05, 0.02, 0.02, 0.8))
		_box(Vector2(x0, y), Vector2(bw, 1.0), Color(0.3, 0.1, 0.1))
		_box(Vector2(x0, y), Vector2(ceilf(bw * float(e.hp) / e.max_hp), 1.0), Color(1.0, 0.35, 0.3))


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
		_dot(pt, 2.0 if k < 3 else 1.0, c)
		if k < 4:
			_dot(pt + Vector2(-p.facing, 1.0), 1.0, _mul(c, 0.7))
	var tint := Color(1, 1, 1)
	if p.heal_t > 0.0:
		tint = Color(0.6, 1.0, 0.7)
	if game.level_up_t > 2.0:
		tint = Color(0.7, 0.9, 1.0)
	var pal := Hero.palette(p)
	var anchor := _sprite(Hero.frame(p), Physics.foot(p), p.facing, pal, tint)
	WeaponArt.draw_held(_dyn, anchor, s, p, Hero.shoulder(p), p.facing, pal[0], tint)
	if p.guard:
		_draw_guard(p)


## The raised guard: a crimson heater shield with a skull under a gold
## cross, held before the hero; its rim burns gold while a blow would still
## be parried.
func _draw_guard(p: Dictionary) -> void:
	var parry: bool = p.parry_t > 0.0
	var pal: Array = G.SHIELD_PAL.duplicate()
	if parry:
		pal[1] = Color(1.0, 0.82, 0.38)
		_light(Physics.center(p) + Vector2(p.facing * 9.0, -2.0), 40.0, Color(1.0, 0.8, 0.4), 0.8)
	_sprite(G.SHIELD, Physics.foot(p) + Vector2(p.facing * 8.0, -6.0), p.facing, pal)


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
	var dir := Vector2(cos(a), sin(a))
	var at := (c + dir * (24.0 + sin(t * 4.0) * 1.5)).round()
	# a small bone dagger pointing the way, in pixels of the world, over a
	# faint ember glow: blade, guard, grip and pommel along the direction
	var glow := 0.6 + 0.25 * sin(t * 4.0)
	_dyn.draw_circle(sp(at), 3.5 * s, Color(0.9, 0.25, 0.1, 0.18 * glow))
	var side := Vector2(-dir.y, dir.x)
	var px: Array = []
	for k in range(0, 6):
		px.append([at + dir * k, Color(0.92, 0.86, 0.74) if k < 5 else Color(1.0, 0.97, 0.9)])
	for k in [-1, 0, 1]:
		px.append([at - dir + side * k * 1.4, Color(0.6, 0.1, 0.1)])
	px.append([at - dir * 2, Color(0.3, 0.22, 0.2)])
	px.append([at - dir * 3, Color(0.3, 0.22, 0.2)])
	px.append([at - dir * 4, Color(0.75, 0.12, 0.1)])
	for q in px:
		_dyn.draw_rect(Rect2(sp((q[0] as Vector2).round() - Vector2(1, 1)), Vector2(3, 3) * s), Color(0.03, 0.0, 0.01, 0.85))
	for q in px:
		var col: Color = q[1]
		col.a = glow
		_dyn.draw_rect(Rect2(sp((q[0] as Vector2).round()), Vector2(s, s)), col)


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
		# strokes close enough along the arc to join into one crescent
		var n := maxi(12, int(radius * spread))
		var col: Color = Color(1.0, 0.88, 0.5) if big else wcol.lerp(Color(1, 1, 1), 0.4)
		var sweep_down: bool = sl.combo != 1
		# a crescent of short pixel strokes along the arc, as the glyphs of
		# the text picture were: faint and thin at the tail, bright and
		# thick at the head
		var head := Vector2.INF
		var head_tg := Vector2.ZERO
		for k in n:
			var f := float(k) / float(n - 1)
			if f > reveal:
				break
			var u := f if sweep_down else 1.0 - f
			var a: float = base_a + float(sl.facing if sl.kind == "side" else 1) * lerpf(-spread, spread, u)
			var d := Vector2(cos(a), sin(a))
			var tg := d.orthogonal()
			var cc := col
			cc.a = alpha * (0.35 + 0.65 * f)
			_stroke(center + d * radius, tg, 4.0 if big else 3.0, cc)
			# the body of the crescent thickens toward the head
			var body := 1 + int(f * (3.0 if big else 2.0))
			for q in body:
				cc.a *= 0.7
				_stroke(center + d * (radius - 1.0 - q), tg, 3.0, cc)
			head = center + d * radius
			head_tg = tg
		if head != Vector2.INF:
			_stroke(head, head_tg, 2.0, Color(1, 1, 1, alpha))


## A short line of single pixels through [c] along [dir], [n] pixels long.
func _stroke(c: Vector2, dir: Vector2, n: float, col: Color) -> void:
	var steps := maxi(1, int(n))
	for q in steps:
		_dot(c + dir * (q - (steps - 1) * 0.5), 1.0, col)


## The Dash Lunge: a long streak of dashes in front of the hero, ending in a point.
func _draw_lunge(sl: Dictionary, c: Vector2, wcol: Color, alpha: float) -> void:
	var col := wcol.lerp(Color(1, 1, 1), 0.5)
	var n := int(9 * sl.reach)
	var fd := Vector2(sl.facing, 0)
	for k in n:
		var f := float(k) / float(n - 1)
		var cc := col
		cc.a = alpha * (0.3 + 0.7 * f)
		var x: float = c.x + sl.facing * (-14.0 + f * 52.0 * sl.reach)
		if k < n - 1:
			_stroke(Vector2(x, c.y - 2), fd, 4.0, cc)
			_stroke(Vector2(x, c.y), fd, 4.0, cc)
		else:
			# the point, an arrowhead of pixels
			for q in 3:
				_dot(Vector2(x - sl.facing * q, c.y - 1 - q), 1.0, Color(1, 1, 1, alpha))
				_dot(Vector2(x - sl.facing * q, c.y - 1 + q), 1.0, Color(1, 1, 1, alpha))
		if k % 2 == 0:
			cc.a *= 0.5
			_stroke(Vector2(x, c.y - 8), fd, 2.0, cc)
			_stroke(Vector2(x, c.y + 6), fd, 2.0, cc)


## Draws a pixel sprite frame standing on [foot] (world units), one texel per
## world unit, mirrored when [facing] is negative. A [ghost] is a flat
## silhouette in [tint]; a [flash] paints it white. Returns the screen point
## the feet landed on.
func _sprite(fr: Array, foot: Vector2, facing: int, pal: Array, tint: Color = Color(1, 1, 1), ghost: bool = false,
		flash: bool = false) -> Vector2:
	var tex := SpriteCache.tex(fr, pal, ghost or flash)
	var size := Vector2(tex.get_size()) * s
	var org := (sp(foot) - Vector2(size.x * 0.5, size.y - s)).round()
	var r := Rect2(org, size)
	if facing < 0:
		# a negative width mirrors the texture in place: the rect keeps its left edge
		r = Rect2(org, Vector2(-size.x, size.y))
	var mod := tint if ghost else (Color(1, 1, 1, tint.a) if flash else tint)
	_dyn.draw_texture_rect(tex, r, false, mod)
	# where the feet landed on the screen, for what the creature holds
	return org + Vector2(size.x * 0.5, size.y - s)


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
			var ec: Color = SpriteCache.foe_def(e.kind).pal[1]
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
