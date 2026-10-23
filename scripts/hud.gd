## In-game interface: health and experience bars, ink, shards, equipment,
## minimap (a small picture of the explored terrain), current goal, combo
## counter, level banner, tutorial hints with key caps, boss health bar, toasts
## and the mouse crosshair. Menus are drawn by menu.gd on top of this.
extends Node2D

const D := preload("res://scripts/data.gd")
const Level := preload("res://scripts/level.gd")
const Items := preload("res://scripts/items.gd")
const Skills := preload("res://scripts/skills.gd")
const Hero := preload("res://scripts/hero.gd")
const Physics := preload("res://scripts/physics.gd")

## Size of the crosshair relative to the interface size.
const CROSSHAIR := 0.62

var game
var font: Font
var bold: Font
var t := 0.0
var u := 1.0
var _banner_level := -1
var _banner_t := 0.0
var _hint_shown := ""
var _hint_a := 0.0
var _boss_name_t := 0.0
var _had_boss := false
var _hp_trail := 0.0
var _combo_pop := 0.0
var _combo_seen := 0
var _map_img: Image
var _map_tex: ImageTexture
var _map_lv = null
var _map_painted := {}
## The canvas item the drawing helpers draw on (self, or the status layer).
var _ci: CanvasItem
var _status_ci: Node2D
var _status_key_last: Array = []
## Clipped health blade shapes by rect and fill (health changes rarely).
var _blade_cache := {}
var _map_rect := Rect2()
var _map_ci: Node2D


## Paints one room's tiles into the map image, one pixel per tile.
static func paint_room(img: Image, lv, b: Dictionary, r: Dictionary) -> void:
	var air: Color = b.top
	air = Color(air.r, air.g, air.b, 0.16)
	var edge: Color = b.top
	for y in range(r.y0, r.y0 + D.ROOM_H):
		for x in range(r.x0, r.x0 + D.ROOM_W):
			var tt: int = lv.tiles[y * lv.w + x]
			var c := Color(0, 0, 0, 0)
			match tt:
				Level.AIR:
					c = air
				Level.WATER:
					c = Color(0.3, 0.45, 0.9, 0.8)
				Level.LAVA:
					c = Color(1.0, 0.45, 0.15, 0.95)
				Level.SPIKES:
					c = Color(0.95, 0.3, 0.25, 0.9)
				Level.ONEWAY:
					c = Color(edge.r, edge.g, edge.b, 0.55)
				Level.GATE:
					c = Color(0.9, 0.88, 0.8, 0.9)
				_:
					if not lv.solid(x, y - 1) or not lv.solid(x, y + 1) or not lv.solid(x - 1, y) or not lv.solid(x + 1, y):
						c = Color(edge.r, edge.g, edge.b, 0.85)
					else:
						c = Color(0.0, 0.0, 0.0, 0.35)
			img.set_pixel(x, y, c)


## The explored terrain as a texture. Rooms are painted once when first seen
## and again only when their tiles change (a wall breaks, a gate closes).
func map_texture() -> ImageTexture:
	var lv = game.lv
	if lv == null:
		return null
	if _map_lv != lv or _map_img == null:
		_map_lv = lv
		_map_img = Image.create(lv.w, lv.h, false, Image.FORMAT_RGBA8)
		_map_img.fill(Color(0, 0, 0, 0))
		_map_tex = null
		_map_painted = {}
	var dirty := false
	for r in lv.rooms:
		if r != null and r.seen and not _map_painted.has(r):
			_map_painted[r] = true
			paint_room(_map_img, lv, game.biome, r)
			dirty = true
	if _map_tex == null:
		_map_tex = ImageTexture.create_from_image(_map_img)
	elif dirty:
		_map_tex.update(_map_img)
	return _map_tex


## Rooms holding these tiles are painted again on the next frame.
func map_tiles_changed(list: Array) -> void:
	var lv = game.lv
	for tp in list:
		var r = lv.room_at_tile(tp.x, tp.y)
		if r != null:
			_map_painted.erase(r)


func setup(g, f: Font, b: Font) -> void:
	_ci = self
	game = g
	font = f
	bold = b
	_map_ci = Node2D.new()
	_map_ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_ci.draw.connect(_draw_map_content)
	add_child(_map_ci)
	_status_ci = Node2D.new()
	_status_ci.show_behind_parent = true
	_status_ci.draw.connect(_draw_status_static)
	add_child(_status_ci)


func _process(delta: float) -> void:
	t += delta
	_banner_t += delta
	_combo_pop = maxf(0.0, _combo_pop - delta * 4.0)
	queue_redraw()
	_map_ci.queue_redraw()
	var p: Dictionary = game.player
	if game.is_title() or p.is_empty():
		if _status_key_last != []:
			_status_key_last = []
			_status_ci.queue_redraw()
		return
	# the pale trail behind the health blade catches up after a hit
	_hp_trail = maxf(_hp_trail - delta * p.max_hp * 0.6, float(p.hp)) if _hp_trail > p.hp else float(p.hp)
	var key := _status_key(p)
	if key != _status_key_last:
		_status_key_last = key
		_status_ci.queue_redraw()


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_hud()
	game.prof_add("hud", t0)


func _draw_hud() -> void:
	_ci = self
	var vp := get_viewport_rect().size
	u = vp.y / 900.0 * float(game.cfg.get_v("ui_scale"))
	if game.hurt_flash > 0.0:
		_ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.85, 0.05, 0.05, game.hurt_flash * 0.16))
	if not game.is_title() and not game.player.is_empty():
		_draw_play(vp)
	if game.fade > 0.0:
		_ci.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, game.fade))
	if game.cfg.get_v("show_fps"):
		var fps := "%d FPS" % Engine.get_frames_per_second()
		_text(Vector2(vp.x - 90 * u, vp.y - 12 * u), fps, int(13 * u), Color(0.6, 0.7, 0.65))


func _text(pos: Vector2, text: String, size: int, color: Color, f: Font = null) -> float:
	var fnt := f if f != null else font
	size = maxi(size, 4)
	_ci.draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if game.ui_check and color.a > 0.05 and not get_viewport_rect().encloses(Rect2(pos.x, pos.y - size * 0.75, w, size * 0.95)):
		game.ui_issue("hud", text)
	return w


func _width(text: String, size: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 4)).x


func _center(y: float, text: String, size: int, color: Color, f: Font = null) -> void:
	var w := _width(text, size, f)
	_text(Vector2((get_viewport_rect().size.x - w) * 0.5, y), text, size, color, f)


## Draws text where [segments] become key caps. Returns the width.
func rich(pos: Vector2, text: String, size: int, color: Color, measure_only: bool = false) -> float:
	var x := pos.x
	var i := 0
	while i < text.length():
		var open := text.find("[", i)
		if open < 0:
			open = text.length()
		var plain := text.substr(i, open - i)
		if plain != "":
			if not measure_only:
				_text(Vector2(x, pos.y), plain, size, color)
			x += _width(plain, size)
		if open >= text.length():
			break
		var close := text.find("]", open)
		if close < 0:
			close = text.length()
		var cap := text.substr(open + 1, close - open - 1)
		var cw := _width(cap, size, bold)
		if not measure_only:
			var r := Rect2(x, pos.y - size * 0.95, cw + size * 0.8, size * 1.3)
			_ci.draw_rect(r, Color(0.95, 0.9, 0.75, 0.14 * color.a))
			_ci.draw_rect(r, Color(0.95, 0.9, 0.75, 0.55 * color.a), false, maxf(1.0, u))
			_text(Vector2(x + size * 0.4, pos.y), cap, size, Color(1.0, 0.92, 0.65, color.a), bold)
		x += cw + size * 0.8
		i = close + 1
	return x - pos.x


func hint_text(id: String) -> String:
	var s: String = game.L("hint_" + id)
	for a in game.ctl.ACTIONS:
		var tag: String = "{" + a + "}"
		if s.contains(tag):
			s = s.replace(tag, game.key(a))
	return s


# ---------------------------------------------------------------- play

func _draw_play(vp: Vector2) -> void:
	var p: Dictionary = game.player
	_draw_status_live(p)
	_draw_minimap(vp)
	_draw_combo(vp)
	_draw_level_up(vp)
	if not game.menu.active():
		_draw_banner(vp)
	_draw_hint(vp)
	_draw_boss(vp)
	_draw_toasts(vp)
	if game.aiming_with_mouse() and game.is_playing() and not game.menu.active() and not game.ui_check:
		_draw_crosshair(game.mouse_point())


## A gothic reticle: four thorns nailed toward the point, a broken ring of
## blood turning slowly around them and a bone diamond in the middle. The ring
## tightens and reddens while a combo is running.
func _draw_crosshair(m: Vector2) -> void:
	var k := u * CROSSHAIR
	var bone := Color(0.9, 0.84, 0.72, 0.95)
	var ink := Color(0.03, 0.0, 0.01, 0.85)
	var heat := clampf(game.hit_combo / 8.0, 0.0, 1.0)
	var blood := Color(0.55, 0.05, 0.07, 0.85).lerp(Color(0.95, 0.15, 0.1, 0.95), heat)
	var rr := (13.0 - 2.0 * heat) * k
	var spin := t * (0.5 + heat * 2.0)
	for q in 4:
		var a0 := spin + q * TAU / 4.0 + 0.32
		_ci.draw_arc(m, rr, a0, a0 + TAU / 4.0 - 0.64, 6, ink, maxf(1.5, 3.2 * k), true)
		_ci.draw_arc(m, rr, a0, a0 + TAU / 4.0 - 0.64, 6, blood, maxf(1.0, 1.5 * k), true)
	for q in 4:
		var d := Vector2.from_angle(q * TAU / 4.0)
		var n := d.orthogonal()
		var root := m + d * 23.0 * k
		var thorn := PackedVector2Array([m + d * 4.5 * k, root + n * 3.0 * k, root - d * 3.0 * k, root - n * 3.0 * k])
		var edge := thorn.duplicate()
		edge.append(thorn[0])
		_ci.draw_polyline(edge, ink, maxf(1.0, 1.6 * k), true)
		_ci.draw_colored_polygon(thorn, bone)
		# small bone studs on the ring between the thorns
		var sd := Vector2.from_angle(q * TAU / 4.0 + TAU / 8.0) * rr
		var stud := PackedVector2Array([m + sd * 1.2, m + sd + sd.orthogonal().normalized() * 1.8 * k, m + sd * 0.8,
			m + sd - sd.orthogonal().normalized() * 1.8 * k])
		_ci.draw_colored_polygon(stud, bone.darkened(0.15))
	var dia := PackedVector2Array([m + Vector2(0, -2.6) * k, m + Vector2(1.9, 0) * k, m + Vector2(0, 2.6) * k, m + Vector2(-1.9, 0) * k])
	var dedge := dia.duplicate()
	dedge.append(dia[0])
	_ci.draw_polyline(dedge, ink, maxf(1.0, 2.0 * k), true)
	_ci.draw_colored_polygon(dia, blood.lerp(bone, 0.4))


func _bar(r: Rect2, f: float, col: Color, back: Color) -> void:
	_ci.draw_rect(r, back)
	_ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), col)
	_ci.draw_rect(r, Color(0.42, 0.36, 0.33, 0.8), false, maxf(1.0, u))


## A bar shaped like a blade (pointed at both ends), [f] full, lighter on top.
func _blade(r: Rect2, f: float, top: Color, bottom: Color) -> void:
	if f <= 0.0:
		return
	var key := "%s|%.4f" % [r, f]
	var polys: Array = _blade_cache.get(key, [])
	if not _blade_cache.has(key):
		var shape := _blade_shape(r)
		var cut := PackedVector2Array([r.position - Vector2(1, 1), Vector2(r.position.x + r.size.x * minf(f, 1.0), r.position.y - 1),
			Vector2(r.position.x + r.size.x * minf(f, 1.0), r.end.y + 1), Vector2(r.position.x - 1, r.end.y + 1)])
		polys = Geometry2D.intersect_polygons(shape, cut)
		if _blade_cache.size() > 64:
			_blade_cache.clear()
		_blade_cache[key] = polys
	for poly in polys:
		var cols := PackedColorArray()
		for q in poly:
			cols.append(top.lerp(bottom, clampf((q.y - r.position.y) / r.size.y, 0.0, 1.0)))
		_ci.draw_polygon(poly, cols)


func _blade_shape(r: Rect2) -> PackedVector2Array:
	var k := r.size.y * 0.7
	var cy := r.get_center().y
	return PackedVector2Array([Vector2(r.position.x, cy), Vector2(r.position.x + k, r.position.y), Vector2(r.end.x - k, r.position.y),
		Vector2(r.end.x, cy), Vector2(r.end.x - k, r.end.y), Vector2(r.position.x + k, r.end.y)])


## A dark heart pierced by a dagger; it beats faster as health runs out and bleeds when low.
func _draw_heart(c: Vector2, frac: float) -> void:
	var rate := 1.2 + (1.0 - frac) * 3.5
	var beat := pow(maxf(0.0, sin(t * rate * TAU)), 8.0)
	var fs := int(29 * u * (1.0 + 0.12 * beat))
	var hw := _width("♥", fs, bold)
	var blood := Color(0.42, 0.02, 0.04).lerp(Color(0.75, 0.05, 0.07), beat * 0.6 + (0.3 if frac <= 0.25 else 0.0))
	_text(c + Vector2(-hw * 0.5 + u, fs * 0.36 + u), "♥", fs, Color(0, 0, 0, 0.8), bold)
	_text(c + Vector2(-hw * 0.5, fs * 0.36), "♥", fs, blood, bold)
	var fi := int(fs * 0.55)
	_text(c + Vector2(-_width("♥", fi, bold) * 0.5 - 2 * u, fi * 0.2), "♥", fi, Color(0.2, 0.0, 0.02, 0.8), bold)
	# the dagger, slanted through the heart
	_ci.draw_set_transform(c, -0.6, Vector2.ONE)
	var dfs := int(19 * u)
	_ci.draw_string(bold, Vector2(-_width("†", dfs, bold) * 0.5, dfs * 0.32), "†", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(0.7, 0.66, 0.6))
	_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if frac <= 0.35:
		for k in 2:
			var ph := fposmod(t * 0.9 + k * 0.5, 1.0)
			_ci.draw_circle(c + Vector2((k - 0.5) * 6.0 * u, 9.0 * u + ph * 16.0 * u), 1.4 * u * (1.0 - ph * 0.5),
				Color(0.6, 0.03, 0.05, 1.0 - ph))


## Where the health blade sits.
func _hp_rect() -> Rect2:
	return Rect2(26.0 * u + 26 * u, 30.0 * u - 1 * u, 250.0 * u, 17 * u)


## What the status panel shows; it is painted again only when this changes.
func _status_key(p: Dictionary) -> Array:
	var low: bool = float(p.hp) / p.max_hp <= 0.25
	var flash: bool = game.ink_flash > 0.0 and int(t * 16.0) % 2 == 0
	return [get_viewport_rect().size, u, p.hp, p.max_hp, int(_hp_trail), int(p.ink * 18.0 / Hero.MAX_INK), flash, p.xp, p.xp_level,
		p.shards, p.weapon, p.charms.duplicate(), Items.charm_slots(p), game.lang, game.key("throw"), int(t * 10.0) if low else -1,
		p.throw, Skills.free_points(p), game.key("skills")]


## The parts of the status panel that move every frame: the beating heart,
## blood dripping from the blade below half health, the regeneration mark.
func _draw_status_live(p: Dictionary) -> void:
	var frac: float = clampf(float(p.hp) / p.max_hp, 0.0, 1.0)
	_draw_heart(Vector2(26.0 * u + 7 * u, 30.0 * u + 7 * u), frac)
	var hr := _hp_rect()
	if frac < 0.5:
		for k in 3:
			var ph := fposmod(t * (0.7 + k * 0.13) + k * 0.37, 1.0)
			var dx := hr.position.x + hr.size.x * frac * (0.2 + 0.3 * k)
			var top := hr.end.y - 2 * u
			_ci.draw_line(Vector2(dx, top), Vector2(dx, top + 4 * u * minf(ph * 3.0, 1.0)), Color(0.45, 0.02, 0.04, 0.9), maxf(1.0, 1.4 * u))
			if ph > 0.33:
				var f := (ph - 0.33) * 1.5
				_ci.draw_circle(Vector2(dx, top + 4 * u + f * f * 22 * u), 1.4 * u, Color(0.55, 0.03, 0.05, 1.0 - f))
	if p.calm > Hero.REGEN_DELAY and p.hp < p.max_hp:
		_text(Vector2(hr.end.x + 6 * u, 30.0 * u + 12 * u), "+", int(15 * u), Color(0.62, 0.78, 0.55, 0.45 + 0.35 * sin(t * 5.0)), bold)


## The still parts of the status panel, cached in their own canvas item.
func _draw_status_static() -> void:
	if game == null or game.is_title() or game.player.is_empty():
		return
	var p: Dictionary = game.player
	var vp := get_viewport_rect().size
	_ci = _status_ci
	for i in 10:
		_ci.draw_rect(Rect2(0, i * 10.0 * u, vp.x, 10.0 * u), Color(0, 0, 0, 0.5 * (1.0 - i / 10.0)))
	var x := 26.0 * u
	var y := 30.0 * u
	var fs := int(15 * u)
	var bw := 250.0 * u
	var frac: float = clampf(float(p.hp) / p.max_hp, 0.0, 1.0)
	# health: a blade of dark blood with a pale trail that catches up after a hit
	var low: bool = frac <= 0.25
	var hr := _hp_rect()
	var shape := _blade_shape(hr)
	_ci.draw_colored_polygon(shape, Color(0.05, 0.01, 0.015, 0.92))
	_blade(hr, _hp_trail / p.max_hp, Color(0.72, 0.62, 0.52, 0.55), Color(0.45, 0.36, 0.3, 0.55))
	var pulse := 0.8 + 0.2 * sin(t * 9.0) if low else 1.0
	_blade(hr, frac, Color(0.66, 0.05, 0.07) * pulse, Color(0.24, 0.0, 0.03))
	# notches every tenth, crowned by the iron spikes of a cemetery fence
	var iron := Color(0.5, 0.44, 0.41)
	for k in range(1, 10):
		var rx := hr.position.x + hr.size.x * k / 10.0
		_ci.draw_line(Vector2(rx, hr.position.y + 2 * u), Vector2(rx, hr.end.y - 2 * u), Color(0, 0, 0, 0.5), maxf(1.0, u))
		var sh := (9.0 if k % 5 == 0 else 6.0) * u
		var sy := hr.position.y
		var spike := PackedVector2Array([Vector2(rx - 2.4 * u, sy + u), Vector2(rx, sy - sh), Vector2(rx + 2.4 * u, sy + u)])
		_ci.draw_colored_polygon(spike, iron)
		_ci.draw_polyline(spike, Color(0, 0, 0, 0.7), maxf(1.0, 0.8 * u), true)
	var rim := Color(0.75, 0.15, 0.12) if low and int(t * 4.0) % 2 == 0 else Color(0.42, 0.36, 0.33)
	var outline := shape.duplicate()
	outline.append(shape[0])
	_ci.draw_polyline(outline, rim, maxf(1.0, 1.3 * u))
	var ht := "%d / %d" % [p.hp, p.max_hp]
	var hs := int(12 * u)
	var tx := hr.get_center().x - _width(ht, hs, bold) * 0.5
	_text(Vector2(tx + u, hr.position.y + 13 * u), ht, hs, Color(0, 0, 0, 0.8), bold)
	_text(Vector2(tx, hr.position.y + 12 * u), ht, hs, Color(0.88, 0.82, 0.72), bold)
	# level and experience: a thin line of tarnished gold
	y += 26 * u
	var need := Hero.xp_need(p.xp_level)
	var lvl: String = game.L("lv") % p.xp_level
	var lw := _text(Vector2(x, y + 9 * u), lvl, int(13 * u), Color(0.82, 0.72, 0.5), bold)
	var xr := Rect2(x + lw + 8 * u, y + 3 * u, bw + 26 * u - lw - 8 * u, 5 * u)
	_bar(xr, float(p.xp) / need, Color(0.7, 0.55, 0.25), Color(0.06, 0.04, 0.03, 0.9))
	for ex in [xr.position.x, xr.end.x]:
		var dc := Vector2(ex, xr.get_center().y)
		_ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -4) * u, dc + Vector2(3, 0) * u, dc + Vector2(0, 4) * u,
			dc + Vector2(-3, 0) * u]), Color(0.62, 0.5, 0.3))
	var xt := "%d/%d %s" % [p.xp, need, game.L("xp")]
	var xw := _text(Vector2(xr.end.x + 8 * u, y + 9 * u), xt, int(11 * u), Color(0.6, 0.54, 0.42))
	var pts := Skills.free_points(p)
	if pts > 0:
		# unspent skill points: a small gold mark with the key that opens the tree
		_text(Vector2(xr.end.x + 18 * u + xw, y + 9 * u), "✦ %d %s" % [pts, game.key("skills")], int(11 * u), Color(1.0, 0.82, 0.4), bold)
	# ink (for knives), labelled with its key: one slanted blade per sixth of a knife
	y += 24 * u
	var ink_col := Color(0.5, 0.42, 0.78)
	if game.ink_flash > 0.0 and int(t * 16.0) % 2 == 0:
		ink_col = Color(0.85, 0.2, 0.2)
	x += _text(Vector2(x, y), game.L("ink").to_upper() + " ", int(12 * u), Color(0.62, 0.56, 0.72), bold)
	x += _text(Vector2(x, y), game.key("throw") + " ", int(12 * u), Color(0.6, 0.58, 0.62), bold)
	var bars := 18
	for i in bars:
		var filled: bool = (i + 1) * Hero.MAX_INK / bars <= p.ink + 0.01
		_dagger(Vector2(x + 3 * u, y), ink_col if filled else Color(0.12, 0.1, 0.17), filled)
		x += 6.5 * u + (7.0 * u if (i + 1) % 6 == 0 else 0.0)
	x += 8.0 * u
	x += _text(Vector2(x, y), "◆ ", fs, Color(0.85, 0.68, 0.32), bold)
	_text(Vector2(x, y), str(p.shards), fs, Color(0.88, 0.82, 0.72), bold)
	# equipment, under lancet arches that need room for their points
	y += 38.0 * u
	x = 26.0 * u
	var wd: Dictionary = Items.def(p.weapon)
	x += _icon(Vector2(x, y), wd.glyph, wd.color, fs) + 4.0 * u
	var td: Dictionary = Items.def(p.throw)
	x += _icon(Vector2(x, y), td.glyph, td.color, fs) + 10.0 * u
	for i in Items.charm_slots(p):
		if i < p.charms.size():
			var cd: Dictionary = Items.def(p.charms[i])
			x += _icon(Vector2(x, y), cd.glyph, cd.color, fs) + 4.0 * u
		else:
			x += _icon(Vector2(x, y), "·", Color(0.3, 0.32, 0.3), fs) + 4.0 * u
	_ci = self


## One ink charge: a small dagger hanging point down, its tip at [base].
func _dagger(base: Vector2, c: Color, lit: bool) -> void:
	var blade := PackedVector2Array([base + Vector2(-1.6, -7) * u, base + Vector2(1.6, -7) * u, base + Vector2(0, 1) * u])
	if lit:
		_ci.draw_circle(base + Vector2(0, -4) * u, 4.5 * u, Color(c.r, c.g, c.b, 0.12))
	_ci.draw_colored_polygon(blade, c)
	_ci.draw_line(base + Vector2(-2.3, -7.5) * u, base + Vector2(2.3, -7.5) * u, c.darkened(0.25), maxf(1.0, 1.3 * u))
	_ci.draw_line(base + Vector2(0, -8) * u, base + Vector2(0, -11) * u, c.darkened(0.45), maxf(1.0, 1.3 * u))
	_ci.draw_circle(base + Vector2(0, -11.5) * u, 1.1 * u, c.darkened(0.3))


## An equipment slot framed like a lancet window, with a small cross on its point.
func _icon(pos: Vector2, g: String, c: Color, fs: int) -> float:
	var w := fs * 1.6
	var r := Rect2(pos.x, pos.y - fs * 1.05, w, fs * 1.45)
	var arch := _arch(r)
	_ci.draw_colored_polygon(arch, Color(0.02, 0.01, 0.015, 0.75))
	_ci.draw_colored_polygon(_arch(Rect2(r.position + Vector2(2, 2) * u, r.size - Vector2(4, 4) * u)), Color(c.r, c.g, c.b, 0.07))
	var edge := arch.duplicate()
	edge.append(arch[0])
	_ci.draw_polyline(edge, Color(0.42, 0.36, 0.33).lerp(c, 0.3), maxf(1.0, 1.3 * u), true)
	var apex := Vector2(r.get_center().x, r.position.y - r.size.x * 0.42 * 0.866)
	_ci.draw_line(apex - Vector2(0, 5 * u), apex + Vector2(0, u), Color(0.42, 0.36, 0.33), maxf(1.0, u))
	_ci.draw_line(apex - Vector2(2.2 * u, 3.2 * u), apex + Vector2(2.2 * u, -3.2 * u), Color(0.42, 0.36, 0.33), maxf(1.0, u))
	var gw := _width(g, fs, bold)
	_text(Vector2(pos.x + (w - gw) * 0.5, pos.y), g, fs, c, bold)
	return w


## A pointed (lancet) arch over [r]: straight sides and two arcs, each centred
## on the opposite side, meeting in a point above the top.
func _arch(r: Rect2) -> PackedVector2Array:
	var w := r.size.x
	var k := 0.42
	var pts := PackedVector2Array([Vector2(r.position.x, r.end.y)])
	for i in 7:
		var a := lerpf(PI, PI * 2.0 / 3.0, i / 6.0)
		pts.append(Vector2(r.end.x + cos(a) * w, r.position.y - sin(a) * w * k))
	for i in range(1, 7):
		var a := lerpf(PI / 3.0, 0.0, i / 6.0)
		pts.append(Vector2(r.position.x + cos(a) * w, r.position.y - sin(a) * w * k))
	pts.append(r.end)
	return pts


func _draw_minimap(vp: Vector2) -> void:
	var lv = game.lv
	var px := minf(1.25 * u, 300.0 * u / lv.w)
	var size := Vector2(lv.w, lv.h) * px
	var x0: float = vp.x - 26.0 * u - size.x
	var y0 := 24.0 * u
	_map_rect = Rect2(x0, y0, size.x, size.y)
	var frame := _map_rect.grow(6 * u)
	_ci.draw_rect(frame, Color(0, 0, 0, 0.55))
	var ac: Color = game.biome.top
	_ci.draw_rect(frame, Color(ac.r, ac.g, ac.b, 0.35), false, maxf(1.0, u))
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), Vector2(frame.position.x, frame.end.y), frame.end]:
		_text(corner + Vector2(-_width("+", int(12 * u), bold) * 0.5, 4 * u), "+", int(12 * u), Color(ac.r, ac.g, ac.b, 0.7), bold)
	var label := "%s · %s" % [game.biome_name(), game.L("level") % game.level_num]
	var fs2 := int(14 * u)
	var ly := frame.end.y + 20 * u
	_text(Vector2(frame.end.x - _width(label, fs2), ly), label, fs2, game.biome.top * 0.95)
	var goal := _goal_text()
	if goal != "":
		var fs3 := int(13 * u)
		_text(Vector2(frame.end.x - _width(goal, fs3, bold), ly + 20 * u), goal, fs3, Color(1.0, 0.85, 0.45, 0.85 + 0.15 * sin(t * 3.0)), bold)


func _goal_text() -> String:
	if not game.boss.is_empty():
		return "› " + game.L("goal_boss") % game.L("boss_" + game.boss.kind)
	if game.lv.boss_level and not game.lv.door_open:
		return "› " + game.L("goal_find_boss")
	return "› " + game.L("goal_exit")


## Drawn by the nearest-filtered child, so map pixels stay crisp.
func _draw_map_content() -> void:
	if game == null or game.is_title() or game.player.is_empty() or game.menu.active() or game.fade > 0.3:
		return
	var tex := map_texture()
	if tex == null:
		return
	var ci := _map_ci
	var r := _map_rect
	ci.draw_texture_rect(tex, r, false)
	draw_map_marks(ci, r, u, t, bold, game)


## Markers on top of the terrain picture: lanterns, merchant, chests, exit, hero.
static func draw_map_marks(ci: CanvasItem, r: Rect2, uu: float, tt: float, bf: Font, g) -> void:
	var lv = g.lv
	var k: float = r.size.x / (lv.w * D.TILE)
	var fs := maxi(6, int(11 * uu * clampf(k * D.TILE / 1.25, 1.0, 2.2)))
	var mark := func(wp: Vector2, gl: String, c: Color) -> void:
		var p: Vector2 = r.position + wp * k
		var w := bf.get_string_size(gl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(bf, p + Vector2(-w * 0.5, fs * 0.35), gl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	for pr in g.props:
		var room = lv.room_at_tile(int(pr.pos.x / D.TILE), int(pr.pos.y / D.TILE - 0.5))
		if room == null or not room.seen:
			continue
		match pr.kind:
			"lantern":
				mark.call(pr.pos, "i", Color(1.0, 0.75, 0.35) if pr.lit else Color(0.5, 0.48, 0.45))
			"shop":
				mark.call(pr.pos, "$", Color(0.85, 0.7, 1.0))
			"chest":
				if not pr.open:
					mark.call(pr.pos, "■", Color(1.0, 0.85, 0.35))
	var last: Dictionary = lv.path[-1]
	var exit_p: Vector2 = lv.door.get_center() if lv.door.size != Vector2.ZERO else Vector2((last.x0 + D.ROOM_W * 0.5) * D.TILE,
		(last.y0 + D.EDGE_FLOOR) * D.TILE)
	var ec := Color(1.0, 0.4, 0.3) if lv.boss_level and not lv.door_open else Color(0.6, 1.0, 0.7)
	ec.a = 1.0 if last.seen else 0.45
	mark.call(exit_p, "X" if lv.boss_level and not lv.door_open else ">", ec)
	if int(tt * 4.0) % 4 != 0:
		var pc := Physics.center(g.player)
		ci.draw_circle(r.position + pc * k, maxf(2.0, 2.4 * uu), Color(1, 1, 1))


func _draw_combo(vp: Vector2) -> void:
	var n: int = game.hit_combo
	if n != _combo_seen:
		if n > _combo_seen:
			_combo_pop = 1.0
		_combo_seen = n
	if n < 2:
		return
	var a := clampf(game.combo_t * 2.0, 0.0, 1.0)
	var heat := clampf(n / 30.0, 0.0, 1.0)
	var c := Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.3, 0.2), heat)
	c.a = a
	# a few fixed sizes: every new font size has to be rasterised once
	var fs := int((34 + snappedf(_combo_pop, 0.34) * 12) * u)
	var txt := str(n)
	var x := vp.x - 60 * u
	var y := vp.y * 0.42
	_text(Vector2(x - _width(txt, fs, bold), y), txt, fs, c, bold)
	var sub: String = game.L("hits")
	_text(Vector2(x - _width(sub, int(13 * u), bold), y + 18 * u), sub, int(13 * u), Color(c.r, c.g, c.b, a * 0.8), bold)
	if n >= 5:
		var bonus := "+%d%% %s" % [mini(n, 30) * 2, game.L("xp")]
		_text(Vector2(x - _width(bonus, int(11 * u)), y + 34 * u), bonus, int(11 * u), Color(0.6, 0.85, 1.0, a * 0.8))


func _draw_level_up(vp: Vector2) -> void:
	var lt: float = game.level_up_t
	if lt <= 0.0:
		return
	var a := clampf(minf((2.6 - lt) * 4.0, lt * 1.5), 0.0, 1.0)
	# below the biome banner when both show at once (a level gained at the door)
	var y := vp.y * (0.48 if _banner_t < 3.2 else 0.26)
	_center(y, game.L("level_up"), int((44 + snappedf((2.6 - lt) * 4.0, 2.0)) * u), Color(0.6, 0.85, 1.0, a), bold)
	_center(y + 30 * u, game.L("lv") % game.player.xp_level, int(18 * u), Color(0.85, 0.92, 1.0, a * 0.9), bold)


const ROOM_MARKS := {"exit": ">", "boss": "B", "shop": "$", "arena": "!", "treasure": "C", "vault": "C"}


func _room_mark(r: Dictionary) -> String:
	return ROOM_MARKS.get(r.kind, "")


func _draw_banner(vp: Vector2) -> void:
	if _banner_level != game.level_num:
		_banner_level = game.level_num
		_banner_t = 0.0
	if _banner_t < 3.2:
		var a := clampf(minf(_banner_t * 2.0, (3.2 - _banner_t) * 1.5), 0.0, 1.0)
		var c: Color = game.biome.top
		c.a = a
		_center(vp.y * 0.3, game.biome_name().to_upper(), int(46 * u), c, bold)
		_center(vp.y * 0.3 + 34 * u, "— " + (game.L("level") % game.level_num) + " —", int(17 * u), Color(0.8, 0.85, 0.82, a * 0.8))
	var has_boss: bool = not game.boss.is_empty()
	if has_boss and not _had_boss:
		_boss_name_t = 0.0
	_had_boss = has_boss
	_boss_name_t += get_process_delta_time()
	if has_boss and _boss_name_t < 3.0:
		var a2 := clampf(minf(_boss_name_t * 2.0, (3.0 - _boss_name_t) * 1.5), 0.0, 1.0)
		_center(vp.y * 0.18, game.L("boss_" + game.boss.kind).to_upper(), int(52 * u), Color(1.0, 0.45, 0.35, a2), bold)


func _draw_hint(vp: Vector2) -> void:
	var id: String = game.hint
	if id != _hint_shown:
		if _hint_a <= 0.0:
			_hint_shown = id
		_hint_a = move_toward(_hint_a, 0.0, get_process_delta_time() * 4.0)
	else:
		_hint_a = move_toward(_hint_a, 1.0, get_process_delta_time() * 3.0)
	if game.ui_check:
		_hint_shown = id
		_hint_a = 1.0
	if _hint_shown == "" or _hint_a <= 0.0 or game.menu.active():
		return
	var text := hint_text(_hint_shown)
	var fs := int(17 * u)
	var w := rich(Vector2.ZERO, text, fs, Color.WHITE, true)
	# stay clear of the minimap; long hints get a smaller font
	var max_w := vp.x - 540.0 * u
	if w > max_w:
		fs = maxi(int(11 * u), int(fs * max_w / w))
		w = rich(Vector2.ZERO, text, fs, Color.WHITE, true)
	var y := 128.0 * u
	var x := (vp.x - w) * 0.5
	var pad := 14.0 * u
	var box := Rect2(x - pad, y - fs * 1.35, w + pad * 2.0, fs * 2.1)
	_ci.draw_rect(box, Color(0.02, 0.03, 0.03, 0.72 * _hint_a))
	_ci.draw_rect(box, Color(0.9, 0.85, 0.6, 0.35 * _hint_a), false, maxf(1.0, u))
	_text(Vector2(box.position.x + 6 * u, box.position.y + 13 * u), "?", int(12 * u), Color(1.0, 0.85, 0.4, _hint_a), bold)
	rich(Vector2(x, y), text, fs, Color(0.92, 0.94, 0.9, _hint_a))


func _draw_boss(vp: Vector2) -> void:
	var b: Dictionary = game.boss
	if b.is_empty() or b.hp <= 0:
		return
	var w := minf(vp.x * 0.6, 760.0 * u)
	var x := (vp.x - w) * 0.5
	var y := vp.y - 54.0 * u
	var fs := int(16 * u)
	var name: String = game.L("boss_" + b.kind)
	_text(Vector2(x, y - 10 * u), name.to_upper(), fs, Color(1.0, 0.6, 0.5), bold)
	var r := Rect2(x, y, w, 12.0 * u)
	_ci.draw_rect(r, Color(0.15, 0.04, 0.04, 0.85))
	var f := clampf(float(b.hp) / b.max_hp, 0.0, 1.0)
	_ci.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Color(0.85, 0.22, 0.2))
	_ci.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y * 0.35)), Color(1.0, 0.5, 0.4, 0.6))
	_ci.draw_rect(r, Color(1.0, 0.75, 0.6, 0.7), false, maxf(1.0, u))
	var mid := r.position.x + r.size.x * 0.5
	_ci.draw_line(Vector2(mid, r.position.y), Vector2(mid, r.end.y), Color(1.0, 0.85, 0.6, 0.6), maxf(1.0, u))


func _draw_toasts(vp: Vector2) -> void:
	var y := vp.y - 90.0 * u
	var fs := int(16 * u)
	for i in range(game.toasts.size() - 1, -1, -1):
		var tt: Dictionary = game.toasts[i]
		var a := clampf(tt.t * 1.5, 0.0, 1.0)
		var c: Color = tt.color
		c.a = a
		var w := rich(Vector2.ZERO, tt.text, fs, c, true)
		_ci.draw_rect(Rect2(20 * u, y - fs * 1.2, w + 24 * u, fs * 1.8), Color(0, 0, 0, 0.55 * a))
		rich(Vector2(32 * u, y), tt.text, fs, c)
		y -= fs * 2.1
