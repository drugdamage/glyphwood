## In-game interface: health and experience bars, ink, shards, equipment,
## minimap (a small picture of the explored terrain), current goal, combo
## counter, level banner, tutorial hints with key caps, boss health bar, toasts
## and the mouse crosshair. Menus are drawn by menu.gd on top of this.
extends Node2D

const D := preload("res://scripts/data.gd")
const Level := preload("res://scripts/level.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Physics := preload("res://scripts/physics.gd")

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
var _map_seen := -1
var _map_rect := Rect2()
var _map_ci: Node2D


## Paints the tiles of explored rooms into a small image, one pixel per tile.
## Rebuilt only when a new room is seen or a wall breaks.
static func paint_map(img: Image, lv, b: Dictionary) -> void:
	img.fill(Color(0, 0, 0, 0))
	var air: Color = b.top
	air = Color(air.r, air.g, air.b, 0.16)
	var edge: Color = b.top
	for r in lv.rooms:
		if r == null or not r.seen:
			continue
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


func map_texture() -> ImageTexture:
	var lv = game.lv
	if lv == null:
		return null
	if _map_lv != lv or _map_img == null:
		_map_lv = lv
		_map_img = Image.create(lv.w, lv.h, false, Image.FORMAT_RGBA8)
		_map_tex = null
		_map_seen = -1
	var key: int = game.rooms_seen * 1000 + game.lv_changes
	if key != _map_seen:
		_map_seen = key
		paint_map(_map_img, lv, game.biome)
		if _map_tex == null:
			_map_tex = ImageTexture.create_from_image(_map_img)
		else:
			_map_tex.update(_map_img)
	return _map_tex


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b
	_map_ci = Node2D.new()
	_map_ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_ci.draw.connect(_draw_map_content)
	add_child(_map_ci)


func _process(delta: float) -> void:
	t += delta
	_banner_t += delta
	_combo_pop = maxf(0.0, _combo_pop - delta * 4.0)
	queue_redraw()
	_map_ci.queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	u = vp.y / 900.0 * float(game.cfg.get_v("ui_scale"))
	if game.hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.85, 0.05, 0.05, game.hurt_flash * 0.16))
	if not game.is_title() and not game.player.is_empty():
		_draw_play(vp)
	if game.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, game.fade))
	if game.cfg.get_v("show_fps"):
		var fps := "%d FPS" % Engine.get_frames_per_second()
		_text(Vector2(vp.x - 90 * u, vp.y - 12 * u), fps, int(13 * u), Color(0.6, 0.7, 0.65))


func _text(pos: Vector2, text: String, size: int, color: Color, f: Font = null) -> float:
	var fnt := f if f != null else font
	size = maxi(size, 4)
	draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
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
			draw_rect(r, Color(0.95, 0.9, 0.75, 0.14 * color.a))
			draw_rect(r, Color(0.95, 0.9, 0.75, 0.55 * color.a), false, maxf(1.0, u))
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
	for i in 10:
		draw_rect(Rect2(0, i * 10.0 * u, vp.x, 10.0 * u), Color(0, 0, 0, 0.5 * (1.0 - i / 10.0)))
	_draw_status(p)
	_draw_minimap(vp)
	_draw_combo(vp)
	_draw_level_up(vp)
	if not game.menu.active():
		_draw_banner(vp)
	_draw_hint(vp)
	_draw_boss(vp)
	_draw_toasts(vp)
	if game.aiming_with_mouse() and game.is_playing() and not game.menu.active():
		var m := get_viewport().get_mouse_position()
		var c := Color(1.0, 0.92, 0.7, 0.9)
		var fs := int(18 * u)
		for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			var g := "-" if d.y == 0.0 else "|"
			var w := _width(g, fs, bold)
			_text(m + d * 9.0 * u - Vector2(w * 0.5, -fs * 0.35), g, fs, c, bold)
		draw_circle(m, 1.5 * u, c)


func _bar(r: Rect2, f: float, col: Color, back: Color) -> void:
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, Color(0.42, 0.36, 0.33, 0.8), false, maxf(1.0, u))


## A bar shaped like a blade (pointed at both ends), [f] full, lighter on top.
func _blade(r: Rect2, f: float, top: Color, bottom: Color) -> void:
	if f <= 0.0:
		return
	var shape := _blade_shape(r)
	var cut := PackedVector2Array([r.position - Vector2(1, 1), Vector2(r.position.x + r.size.x * minf(f, 1.0), r.position.y - 1),
		Vector2(r.position.x + r.size.x * minf(f, 1.0), r.end.y + 1), Vector2(r.position.x - 1, r.end.y + 1)])
	for poly in Geometry2D.intersect_polygons(shape, cut):
		var cols := PackedColorArray()
		for q in poly:
			cols.append(top.lerp(bottom, clampf((q.y - r.position.y) / r.size.y, 0.0, 1.0)))
		draw_polygon(poly, cols)


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
	draw_set_transform(c, -0.6, Vector2.ONE)
	var dfs := int(19 * u)
	draw_string(bold, Vector2(-_width("†", dfs, bold) * 0.5, dfs * 0.32), "†", HORIZONTAL_ALIGNMENT_LEFT, -1, dfs, Color(0.7, 0.66, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if frac <= 0.35:
		for k in 2:
			var ph := fposmod(t * 0.9 + k * 0.5, 1.0)
			draw_circle(c + Vector2((k - 0.5) * 6.0 * u, 9.0 * u + ph * 16.0 * u), 1.4 * u * (1.0 - ph * 0.5),
				Color(0.6, 0.03, 0.05, 1.0 - ph))


func _draw_status(p: Dictionary) -> void:
	var x := 26.0 * u
	var y := 30.0 * u
	var fs := int(15 * u)
	var bw := 250.0 * u
	var frac: float = clampf(float(p.hp) / p.max_hp, 0.0, 1.0)
	# health: a blade of dark blood with a pale trail that catches up after a hit
	_hp_trail = maxf(_hp_trail - get_process_delta_time() * p.max_hp * 0.6, float(p.hp)) if _hp_trail > p.hp else float(p.hp)
	var low: bool = frac <= 0.25
	_draw_heart(Vector2(x + 7 * u, y + 7 * u), frac)
	var hr := Rect2(x + 26 * u, y - 1 * u, bw, 17 * u)
	var shape := _blade_shape(hr)
	draw_colored_polygon(shape, Color(0.05, 0.01, 0.015, 0.92))
	_blade(hr, _hp_trail / p.max_hp, Color(0.72, 0.62, 0.52, 0.55), Color(0.45, 0.36, 0.3, 0.55))
	var pulse := 0.8 + 0.2 * sin(t * 9.0) if low else 1.0
	_blade(hr, frac, Color(0.66, 0.05, 0.07) * pulse, Color(0.24, 0.0, 0.03))
	# rivets every tenth, and a tarnished iron rim
	for k in range(1, 10):
		var rx := hr.position.x + hr.size.x * k / 10.0
		draw_line(Vector2(rx, hr.position.y + 2 * u), Vector2(rx, hr.end.y - 2 * u), Color(0, 0, 0, 0.45), maxf(1.0, u))
	var rim := Color(0.75, 0.15, 0.12) if low and int(t * 4.0) % 2 == 0 else Color(0.42, 0.36, 0.33)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, rim, maxf(1.0, 1.3 * u))
	var ht := "%d / %d" % [p.hp, p.max_hp]
	var hs := int(12 * u)
	var tx := hr.get_center().x - _width(ht, hs, bold) * 0.5
	_text(Vector2(tx + u, hr.position.y + 13 * u), ht, hs, Color(0, 0, 0, 0.8), bold)
	_text(Vector2(tx, hr.position.y + 12 * u), ht, hs, Color(0.88, 0.82, 0.72), bold)
	if p.calm > Hero.REGEN_DELAY and p.hp < p.max_hp and game.boss.is_empty():
		_text(Vector2(hr.end.x + 6 * u, y + 12 * u), "+", fs, Color(0.62, 0.78, 0.55, 0.45 + 0.35 * sin(t * 5.0)), bold)
	# level and experience: a thin line of tarnished gold
	y += 26 * u
	var need := Hero.xp_need(p.xp_level)
	var lvl: String = game.L("lv") % p.xp_level
	var lw := _text(Vector2(x, y + 9 * u), lvl, int(13 * u), Color(0.82, 0.72, 0.5), bold)
	var xr := Rect2(x + lw + 8 * u, y + 3 * u, bw + 26 * u - lw - 8 * u, 5 * u)
	_bar(xr, float(p.xp) / need, Color(0.7, 0.55, 0.25), Color(0.06, 0.04, 0.03, 0.9))
	var xt := "%d/%d %s" % [p.xp, need, game.L("xp")]
	_text(Vector2(xr.end.x + 8 * u, y + 9 * u), xt, int(11 * u), Color(0.6, 0.54, 0.42))
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
		var bx := x + 2 * u
		var poly := PackedVector2Array([Vector2(bx + 3 * u, y - 11 * u), Vector2(bx + 6 * u, y - 11 * u), Vector2(bx + 3 * u, y + 1 * u),
			Vector2(bx, y + 1 * u)])
		draw_colored_polygon(poly, ink_col if filled else Color(0.12, 0.1, 0.17))
		x += 6.5 * u + (7.0 * u if (i + 1) % 6 == 0 else 0.0)
	x += 8.0 * u
	x += _text(Vector2(x, y), "◆ ", fs, Color(0.85, 0.68, 0.32), bold)
	_text(Vector2(x, y), str(p.shards), fs, Color(0.88, 0.82, 0.72), bold)
	# equipment
	y += 26.0 * u
	x = 26.0 * u
	var wd: Dictionary = Items.def(p.weapon)
	x += _icon(Vector2(x, y), wd.glyph, wd.color, fs) + 10.0 * u
	for i in Items.charm_slots(p):
		if i < p.charms.size():
			var cd: Dictionary = Items.def(p.charms[i])
			x += _icon(Vector2(x, y), cd.glyph, cd.color, fs) + 4.0 * u
		else:
			x += _icon(Vector2(x, y), "·", Color(0.3, 0.32, 0.3), fs) + 4.0 * u


func _icon(pos: Vector2, g: String, c: Color, fs: int) -> float:
	var w := fs * 1.6
	var r := Rect2(pos.x, pos.y - fs * 1.05, w, fs * 1.45)
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.4)), Color(c.r, c.g, c.b, 0.08))
	draw_rect(r, Color(c.r, c.g, c.b, 0.5), false, maxf(1.0, u))
	var gw := _width(g, fs, bold)
	_text(Vector2(pos.x + (w - gw) * 0.5, pos.y), g, fs, c, bold)
	return w


func _draw_minimap(vp: Vector2) -> void:
	var lv = game.lv
	var px := minf(1.25 * u, 300.0 * u / lv.w)
	var size := Vector2(lv.w, lv.h) * px
	var x0: float = vp.x - 26.0 * u - size.x
	var y0 := 24.0 * u
	_map_rect = Rect2(x0, y0, size.x, size.y)
	var frame := _map_rect.grow(6 * u)
	draw_rect(frame, Color(0, 0, 0, 0.55))
	var ac: Color = game.biome.top
	draw_rect(frame, Color(ac.r, ac.g, ac.b, 0.35), false, maxf(1.0, u))
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
	var fs := int((34 + _combo_pop * 12) * u)
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
	_center(vp.y * 0.26, game.L("level_up"), int((44 + (2.6 - lt) * 4.0) * u), Color(0.6, 0.85, 1.0, a), bold)
	_center(vp.y * 0.26 + 30 * u, game.L("lv") % game.player.xp_level, int(18 * u), Color(0.85, 0.92, 1.0, a * 0.9), bold)


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
	draw_rect(box, Color(0.02, 0.03, 0.03, 0.72 * _hint_a))
	draw_rect(box, Color(0.9, 0.85, 0.6, 0.35 * _hint_a), false, maxf(1.0, u))
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
	draw_rect(r, Color(0.15, 0.04, 0.04, 0.85))
	var f := clampf(float(b.hp) / b.max_hp, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Color(0.85, 0.22, 0.2))
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y * 0.35)), Color(1.0, 0.5, 0.4, 0.6))
	draw_rect(r, Color(1.0, 0.75, 0.6, 0.7), false, maxf(1.0, u))
	var mid := r.position.x + r.size.x * 0.5
	draw_line(Vector2(mid, r.position.y), Vector2(mid, r.end.y), Color(1.0, 0.85, 0.6, 0.6), maxf(1.0, u))


func _draw_toasts(vp: Vector2) -> void:
	var y := vp.y - 90.0 * u
	var fs := int(16 * u)
	for i in range(game.toasts.size() - 1, -1, -1):
		var tt: Dictionary = game.toasts[i]
		var a := clampf(tt.t * 1.5, 0.0, 1.0)
		var c: Color = tt.color
		c.a = a
		var w := rich(Vector2.ZERO, tt.text, fs, c, true)
		draw_rect(Rect2(20 * u, y - fs * 1.2, w + 24 * u, fs * 1.8), Color(0, 0, 0, 0.55 * a))
		rich(Vector2(32 * u, y), tt.text, fs, c)
		y -= fs * 2.1
