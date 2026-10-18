## Draws the world with glyphs: parallax background, terrain outlines,
## swaying grass, the hero with a trailing scarf, enemies, slashes and particles.
extends Node2D

const D := preload("res://scripts/data.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")

const ZOOMS := [1.0, 1.2, 1.45]
const EDGE_GLYPHS := ["%", "&", "8", "B", "W", "M", "0", "X"]
const GRASS_GLYPHS := ["'", "\"", ",", "`", "'", "|"]
const LH := 10.0   # line height of entity sprites, world units

var game
var font: Font
var bold: Font
var zoom_idx := 1
var s := 1.0          # world -> screen scale
var vp := Vector2.ZERO
var off := Vector2.ZERO
var t := 0.0
var fs_t := 12
var fs_e := 10
var adv_e := 6.0      # sprite glyph advance in world units
var _far: Array = []
var _vines: Array = []
var _motes: Array = []
var _neck: Array = []
var _mirror_cache := {}
var _title_t := 0.0


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b


func zoom(step: int) -> void:
	zoom_idx = clampi(zoom_idx + step, 0, ZOOMS.size() - 1)


func title_cam_reset() -> void:
	_title_t = 0.0


func on_level_built() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = game.level_num * 7919
	_far.clear()
	var lw: float = game.lv.pixel_size().x
	var x := -400.0
	while x < lw * 0.4 + 800.0:
		var chars := ""
		for i in 24:
			chars += ["|", "|", "!", ":", "|", "¦"][rng.randi_range(0, 5)]
		_far.append({"x": x, "chars": chars, "b": rng.randf_range(0.5, 1.0), "w": rng.randi_range(1, 2)})
		x += rng.randf_range(28.0, 80.0)
	_vines.clear()
	x = -200.0
	while x < lw * 0.7 + 600.0:
		_vines.append({"x": x, "len": rng.randi_range(2, 7), "ph": rng.randf() * TAU})
		x += rng.randf_range(20.0, 70.0)
	_motes.clear()
	for i in 40:
		_motes.append({"p": Vector2(rng.randf_range(0, lw), rng.randf_range(32, 300)), "ph": rng.randf() * TAU})
	_neck.clear()


func clamp_cam(c: Vector2) -> Vector2:
	if s <= 0.0 or vp == Vector2.ZERO:
		return c
	var half := vp / s * 0.5
	var size: Vector2 = game.lv.pixel_size()
	c.x = size.x * 0.5 if size.x < half.x * 2.0 else clampf(c.x, half.x, size.x - half.x)
	c.y = size.y * 0.5 if size.y < half.y * 2.0 else clampf(c.y, half.y, size.y - half.y)
	return c


func _process(delta: float) -> void:
	t += delta
	vp = get_viewport_rect().size
	s = vp.y / (D.CHUNK_H * D.TILE) * ZOOMS[zoom_idx]
	fs_t = maxi(6, int(D.TILE * s * 0.66))
	fs_e = maxi(6, int(LH * s * 1.02))
	adv_e = bold.get_char_size("M".unicode_at(0), fs_e).x / s
	if game.is_title():
		_title_t += delta
		var lw: float = game.lv.pixel_size().x
		game.cam = clamp_cam(Vector2(lw * 0.5 - cos(_title_t * 0.035) * lw * 0.5, 160))
	if not game.player.is_empty():
		_neck.push_front(_neck_pos())
		if _neck.size() > 16:
			_neck.pop_back()
	queue_redraw()


func sp(w: Vector2) -> Vector2:
	return (w - game.cam) * s + vp * 0.5 + off


# ---------------------------------------------------------------- draw

func _draw() -> void:
	if game == null or game.lv == null:
		return
	off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * game.shake * s * 0.5
	var b: Dictionary = game.biome
	draw_rect(Rect2(Vector2.ZERO, vp), b.bg)
	_draw_background(b)
	_draw_terrain(b)
	_draw_door(b)
	_draw_items()
	for e in game.enemies:
		_draw_enemy(e)
	for pr in game.projectiles:
		_glyph(pr.pos, "*", Color(1.0, 0.55, 0.4), fs_e * 1.2, bold)
	if not game.is_title():
		for gh in game.ghosts:
			var c := Color(0.55, 0.85, 1.0, gh.life / 0.22 * 0.55)
			_sprite(gh.lines, gh.foot, gh.facing, c)
		_draw_hero()
		_draw_slashes()
	for pt in game.particles:
		var c: Color = pt.c
		c.a = clampf(pt.life / pt.max, 0.0, 1.0)
		_glyph(pt.p, pt.g, c, fs_e * pt.s, bold)


func _draw_background(b: Dictionary) -> void:
	var cam: Vector2 = game.cam
	var top := 0.0
	var row_h := D.TILE * 1.15 * s
	var f_far := 0.35
	for col in _far:
		var sx: float = (col.x - cam.x * f_far) * s + vp.x * 0.5
		if sx < -40 or sx > vp.x + 40:
			continue
		var c: Color = b.far * col.b
		c.a = 1.0
		var y := top
		var i := 0
		while y < vp.y + row_h:
			var g: String = col.chars[i % col.chars.length()]
			draw_char(font, Vector2(sx, y + row_h * 0.8), g, fs_t, c)
			if col.w == 2:
				draw_char(font, Vector2(sx + fs_t * 0.6, y + row_h * 0.8), g, fs_t, c)
			y += row_h
			i += 1
	var f_mid := 0.7
	var vc: Color = b.far.lerp(b.edge, 0.3)
	for v in _vines:
		var sx: float = (v.x - cam.x * f_mid) * s + vp.x * 0.5
		if sx < -20 or sx > vp.x + 20:
			continue
		var y0 := sp(Vector2(0, D.TILE * 2.0)).y
		for k in v.len:
			var sway = sin(t * 1.3 + v.ph + k * 0.6) * k * 0.8 * s
			var g = ":" if k < v.len - 1 else ["j", "!", "'", "*"][int(v.ph * 10) % 4]
			draw_char(font, Vector2(sx + sway, y0 + (k + 0.8) * fs_t * 0.9), g, int(fs_t * 0.85), vc * (1.0 - k * 0.08))
	var mc: Color = b.mote
	for m in _motes:
		var p: Vector2 = m.p + Vector2(sin(t * 0.4 + m.ph) * 30.0, cos(t * 0.3 + m.ph) * 20.0)
		var c := mc
		c.a = 0.25 + 0.35 * (0.5 + 0.5 * sin(t * 2.0 + m.ph))
		_glyph(p, "·", c, fs_e, font)


func _draw_terrain(b: Dictionary) -> void:
	var lv = game.lv
	var T := D.TILE
	var tl = (game.cam - vp / s * 0.5) / T
	var br = (game.cam + vp / s * 0.5) / T
	var x0 := maxi(0, int(floor(tl.x)) - 1)
	var x1 := mini(lv.w - 1, int(ceil(br.x)) + 1)
	var y0 := maxi(0, int(floor(tl.y)) - 1)
	var y1 := mini(lv.h - 1, int(ceil(br.y)) + 1)
	var pc := Vector2(-9999, -9999)
	if not game.player.is_empty():
		pc = Physics.center(game.player)
	var tile_px := T * s
	var cap := fs_t * 0.36
	var adv_t := font.get_char_size("#".unicode_at(0), fs_t).x

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var tt: int = lv.tiles[y * lv.w + x]
			if tt == Level.AIR:
				continue
			var o := sp(Vector2(x * T, y * T))
			var h := _hash01(x, y)
			match tt:
				Level.SOLID:
					draw_rect(Rect2(o, Vector2(tile_px + 1, tile_px + 1)), b.fill)
					var up_air = not lv.solid(x, y - 1)
					var exposed = up_air or not lv.solid(x, y + 1) or not lv.solid(x - 1, y) or not lv.solid(x + 1, y)
					if not exposed:
						continue
					var c: Color = b.top if up_air else b.edge * 0.75
					c = c * (0.85 + h * 0.2)
					c.a = 1.0
					for k in 2:
						var hk := _hash01(x * 2 + k, y + 977)
						var g = "#" if hk < 0.96 else EDGE_GLYPHS[int(hk * 1000.0) % EDGE_GLYPHS.size()]
						var cx := o.x + tile_px * (0.25 + 0.5 * k) - adv_t * 0.5
						draw_char(font, Vector2(cx, o.y + tile_px * 0.5 + cap), g, fs_t, c)
					if up_air and lv.at(x, y - 1) == Level.AIR and h > 0.3:
						_draw_grass(b, x, y - 1, o.y, h, pc, tile_px, adv_t)
				Level.ONEWAY:
					var c2: Color = b.top * 0.85
					c2.a = 1.0
					for k in 2:
						draw_char(font, Vector2(o.x + tile_px * (0.25 + 0.5 * k) - adv_t * 0.5, o.y + tile_px * 0.3 + cap), "=", fs_t, c2)
				Level.SPIKES:
					var fl := 0.8 + 0.2 * sin(t * 5.0 + x)
					for k in 2:
						draw_char(font, Vector2(o.x + tile_px * (0.25 + 0.5 * k) - adv_t * 0.5, o.y + tile_px * 0.72 + cap),
							"^", fs_t, Color(1.0 * fl, 0.42 * fl, 0.35 * fl))


func _draw_grass(b: Dictionary, x: int, y: int, ground_y: float, h: float, pc: Vector2, tile_px: float, adv_t: float) -> void:
	var T := D.TILE
	for k in 2:
		var wx := (x + 0.25 + 0.5 * k) * T
		var lean := sin(wx * 0.045 - t * 1.8 + h * 2.0) + 0.5 * sin(wx * 0.13 + t * 0.7)
		var g: String = GRASS_GLYPHS[int(h * 60.0 + k * 3) % GRASS_GLYPHS.size()]
		var dx := wx - pc.x
		if absf(dx) < 12.0 and absf(pc.y - (y + 1) * T) < 26.0:
			g = "/" if dx > 0.0 else "\\"
		elif lean > 1.0:
			g = "/"
		var c: Color = b.grass * (0.6 + 0.4 * h + maxf(0.0, lean - 0.6) * 0.3)
		c.a = 1.0
		var sx := sp(Vector2(wx, 0)).x - adv_t * 0.4
		draw_char(font, Vector2(sx, ground_y - tile_px * 0.08), g, int(fs_t * 0.85), c)


func _draw_door(b: Dictionary) -> void:
	var r: Rect2 = game.lv.door
	if r.size == Vector2.ZERO:
		return
	var c: Color = b.top * (0.75 + 0.25 * sin(t * 3.0))
	c.a = 1.0
	var rows := 3
	for i in rows + 1:
		var y := r.position.y + r.size.y - i * 12.0
		_glyph(Vector2(r.position.x + 2, y - 4), "|", c, fs_t, font)
		_glyph(Vector2(r.end.x - 2, y - 4), "|", c, fs_t, font)
	for i in 4:
		_glyph(Vector2(r.position.x + 4 + i * 8.0, r.position.y - 2), "_", c, fs_t, font)
	for i in 5:
		var ph := fmod(t * 0.6 + i * 0.21, 1.0)
		var p := Vector2(r.position.x + 6 + fmod(i * 7.3, r.size.x - 12), r.end.y - ph * r.size.y)
		var mc: Color = b.mote
		mc.a = 1.0 - ph
		_glyph(p, "·", mc, fs_e, font)
	_glyph(r.get_center() + Vector2(0, -4), ">", c, int(fs_t * 1.2), bold)


func _draw_items() -> void:
	for pk in game.pickups:
		var p: Vector2 = pk.pos + Vector2(0, sin(t * 3.0 + pk.pos.x) * 2.0)
		_glyph(p, "♥", Color(1.0, 0.35, 0.45), fs_e * 1.3, bold)
	for sh in game.shards:
		var c := Color(1.0, 0.85, 0.35) * (0.8 + 0.2 * sin(t * 10.0 + sh.pos.x))
		c.a = 1.0
		_glyph(sh.pos + sh.size * 0.5, "*", c, fs_e, bold)


func _draw_enemy(e: Dictionary) -> void:
	var col: Color = D.ENEMIES[e.kind].color
	if e.flash > 0.0:
		col = Color(1, 1, 1)
	_sprite(Foes.frame(e), Physics.foot(e), e.dir, col)
	if e.kind == "knight" and e.state == "tele" and int(t * 14.0) % 2 == 0:
		_glyph(Vector2(Physics.center(e).x, e.pos.y - 8), "!", Color(1.0, 0.3, 0.25), fs_e * 1.4, bold)
	if e.kind == "spitter" and e.state == "charge":
		var c := Color(1.0, 0.5, 0.4, 0.5 + 0.5 * sin(t * 30.0))
		_glyph(Physics.center(e) + Vector2(0, -10), "·", c, fs_e * 1.6, bold)


func _draw_hero() -> void:
	var p: Dictionary = game.player
	if p.is_empty() or p.dead or p.respawn_t > 0.0:
		return
	if p.blink > 0.0 and p.inv > 0.0 and int(p.blink * 18.0) % 2 == 0:
		return
	# scarf
	var neck := _neck_pos()
	for k in 4:
		var hist: Vector2 = _neck[mini(k * 3 + 2, _neck.size() - 1)] if not _neck.is_empty() else neck
		var wind := Vector2(-p.facing * (5.0 + k * 4.5), sin(t * 8.0 - k * 1.1) * 2.0 + k * 0.8)
		var pt := neck + wind + ((hist - neck) * 0.3).limit_length(8.0)
		var c := Color(1.0, 0.3, 0.26) * (1.0 - k * 0.12)
		c.a = 1.0
		_glyph(pt, "~" if k < 3 else "-", c, fs_e * (1.0 - k * 0.1), bold)
	var col := Color(0.97, 0.95, 0.88)
	if p.heal_t > 0.0:
		col = Color(0.6, 1.0, 0.7)
	_sprite(Hero.frame(p), Physics.foot(p), p.facing, col)


func _neck_pos() -> Vector2:
	var p: Dictionary = game.player
	return Physics.foot(p) + Vector2(-p.facing * 1.5, -LH * 2.0 - 1.0)


func _draw_slashes() -> void:
	var p: Dictionary = game.player
	var c := Physics.center(p)
	for sl in game.slashes:
		var reveal := clampf(sl.t / 0.07, 0.0, 1.0)
		var alpha := 1.0 - clampf((sl.t - 0.07) / 0.15, 0.0, 1.0)
		var base := 0.0 if sl.facing > 0 else PI
		var center := c + Vector2(sl.facing * 4.0, -2.0)
		match sl.kind:
			"up":
				base = -PI * 0.5
				center = c + Vector2(0, -8)
			"down":
				base = PI * 0.5
				center = c + Vector2(0, 10)
		var big: bool = sl.combo == 2
		var radius := 24.0 if big else 20.0
		var spread := deg_to_rad(80.0)
		var n := 8
		var col := Color(1.0, 0.88, 0.5) if big else Color(0.85, 0.97, 1.0)
		var sweep_down: bool = sl.combo != 1
		for k in n:
			var f := float(k) / float(n - 1)
			if f > reveal:
				break
			var u := f if sweep_down else 1.0 - f
			var a: float = base + float(sl.facing if sl.kind == "side" else 1) * lerpf(-spread, spread, u)
			var pt := center + Vector2(cos(a), sin(a)) * radius
			var cc := col
			cc.a = alpha * (0.55 + 0.45 * f)
			_glyph(pt, _tangent_glyph(a), cc, fs_e * (1.35 if big else 1.15), bold)
			if k % 2 == 0:
				var inner := center + Vector2(cos(a), sin(a)) * radius * 0.65
				cc.a *= 0.4
				_glyph(inner, "·", cc, fs_e, bold)


static func _tangent_glyph(a: float) -> String:
	var d := fposmod(a + PI * 0.5, PI)
	if d < PI / 8.0 or d > PI * 7.0 / 8.0:
		return "-"
	if d < PI * 3.0 / 8.0:
		return "\\"
	if d < PI * 5.0 / 8.0:
		return "|"
	return "/"


# ---------------------------------------------------------------- helpers

func _mirror(line: String) -> String:
	if _mirror_cache.has(line):
		return _mirror_cache[line]
	var out := ""
	for i in range(line.length() - 1, -1, -1):
		var ch := line[i]
		out += D.MIRROR.get(ch, ch)
	_mirror_cache[line] = out
	return out


## Draws a multi-line sprite whose bottom-center stands at foot (world units).
func _sprite(lines: Array, foot: Vector2, facing: int, col: Color) -> void:
	var n := lines.size()
	for i in n:
		var line: String = lines[i] if facing >= 0 else _mirror(lines[i])
		var y := foot.y - (n - 1 - i) * LH - LH * 0.5
		var x0 := foot.x - line.length() * adv_e * 0.5 + adv_e * 0.5
		for j in line.length():
			var ch := line[j]
			if ch != " ":
				_glyph(Vector2(x0 + j * adv_e, y), ch, col, fs_e, bold)


## Draws one glyph centered on a world position.
func _glyph(w: Vector2, g: String, col: Color, size: float, f: Font) -> void:
	var fs := maxi(4, int(size))
	var p := sp(w)
	var cw := f.get_char_size(g.unicode_at(0), fs).x
	draw_char(f, Vector2(p.x - cw * 0.5, p.y + fs * 0.36), g, fs, col)


static func _hash01(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return float(n % 10007) / 10007.0
