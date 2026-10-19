## In-game interface: health, flasks, ink, shards, equipment, minimap, level
## banner, tutorial hints with key caps, boss health bar, toasts and the
## mouse crosshair. Menus are drawn by menu.gd on top of this.
extends Node2D

const D := preload("res://scripts/data.gd")
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


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b


func _process(delta: float) -> void:
	t += delta
	_banner_t += delta
	queue_redraw()


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
	return fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 4)).x


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


func _draw_status(p: Dictionary) -> void:
	var x := 26.0 * u
	var y := 42.0 * u
	var hs := int(26 * u)
	for i in p.max_hp:
		var full: bool = i < p.hp
		var c := Color(1.0, 0.32, 0.38) if full else Color(0.32, 0.12, 0.14)
		if full and p.hp <= 1:
			c = c * (0.7 + 0.3 * sin(t * 10.0))
			c.a = 1.0
		x += _text(Vector2(x, y), "♥", hs, c, bold) + 5.0 * u
	y += 30.0 * u
	x = 26.0 * u
	var fs := int(16 * u)
	for i in p.max_flasks:
		var on: bool = i < p.flasks
		x += _text(Vector2(x, y), "[+]", fs, Color(0.5, 1.0, 0.6) if on else Color(0.2, 0.3, 0.22), bold) + 6.0 * u
	x += 12.0 * u
	# ink bar: three knives' worth
	var bars := 18
	var ink: float = p.ink
	var ink_col := Color(0.55, 0.65, 1.0)
	if game.ink_flash > 0.0 and int(t * 16.0) % 2 == 0:
		ink_col = Color(1.0, 0.4, 0.4)
	x += _text(Vector2(x, y), "~", fs, ink_col, bold) + 4.0 * u
	for i in bars:
		var filled := (i + 1) * Hero.MAX_INK / bars <= ink + 0.01
		var c2 := ink_col if filled else Color(0.16, 0.18, 0.3)
		x += _text(Vector2(x, y), "|", fs, c2, bold) + (5.0 * u if (i + 1) % 6 == 0 else 0.0)
	x += 14.0 * u
	x += _text(Vector2(x, y), "◆ ", fs, Color(1.0, 0.85, 0.35), bold)
	_text(Vector2(x, y), str(p.shards), fs, Color(0.95, 0.92, 0.85), bold)
	# equipment
	y += 26.0 * u
	x = 26.0 * u
	var wd: Dictionary = Items.def(p.weapon)
	x += _icon(Vector2(x, y), wd.glyph, wd.color, fs) + 10.0 * u
	for i in Items.CHARM_SLOTS:
		if i < p.charms.size():
			var cd: Dictionary = Items.def(p.charms[i])
			x += _icon(Vector2(x, y), cd.glyph, cd.color, fs) + 4.0 * u
		else:
			x += _icon(Vector2(x, y), "·", Color(0.3, 0.32, 0.3), fs) + 4.0 * u


func _icon(pos: Vector2, g: String, c: Color, fs: int) -> float:
	var w := fs * 1.5
	var r := Rect2(pos.x, pos.y - fs * 1.05, w, fs * 1.4)
	draw_rect(r, Color(0, 0, 0, 0.45))
	draw_rect(r, Color(c.r, c.g, c.b, 0.45), false, maxf(1.0, u))
	var gw := _width(g, fs, bold)
	_text(Vector2(pos.x + (w - gw) * 0.5, pos.y), g, fs, c, bold)
	return w


func _draw_minimap(vp: Vector2) -> void:
	var lv = game.lv
	var cw := 34.0 * u
	var ch := 20.0 * u
	var x0: float = vp.x - 26.0 * u - lv.gw * cw
	var y0 := 22.0 * u
	draw_rect(Rect2(x0 - 6 * u, y0 - 6 * u, lv.gw * cw + 12 * u, lv.gh * ch + 12 * u), Color(0, 0, 0, 0.45))
	var pc := Physics.center(game.player)
	var cur = lv.room_at_tile(int(pc.x / D.TILE), int(pc.y / D.TILE))
	for r in lv.rooms:
		if r == null or not r.seen:
			continue
		var rect := Rect2(x0 + r.gx * cw + 1, y0 + r.gy * ch + 1, cw - 2, ch - 2)
		var col: Color = game.biome.top
		draw_rect(rect, Color(col.r, col.g, col.b, 0.22 if r != cur else 0.5))
		draw_rect(rect, Color(col.r, col.g, col.b, 0.7), false, maxf(1.0, u))
		var mark := _room_mark(r)
		if mark != "":
			var fs := int(11 * u)
			_text(Vector2(rect.get_center().x - _width(mark, fs, bold) * 0.5, rect.get_center().y + fs * 0.35), mark, fs,
				Color(1.0, 0.9, 0.6), bold)
	if cur != null:
		var fx: float = (pc.x / D.TILE - cur.x0) / D.ROOM_W
		var fy: float = (pc.y / D.TILE - cur.y0) / D.ROOM_H
		var dot := Vector2(x0 + (cur.gx + fx) * cw, y0 + (cur.gy + fy) * ch)
		if int(t * 4.0) % 2 == 0:
			draw_circle(dot, 2.2 * u, Color(1, 1, 1))
	var label := "%s · %s" % [game.biome_name(), game.L("level") % game.level_num]
	var fs2 := int(14 * u)
	_text(Vector2(vp.x - 26.0 * u - _width(label, fs2), y0 + lv.gh * ch + 22 * u), label, fs2, game.biome.top * 0.95)


const ROOM_MARKS := {"exit": ">", "boss": "B", "shop": "$", "shrine": "+", "arena": "!", "treasure": "C", "vault": "C"}


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
	if _hint_shown == "" or _hint_a <= 0.0 or game.menu.active():
		return
	var text := hint_text(_hint_shown)
	var fs := int(17 * u)
	var w := rich(Vector2.ZERO, text, fs, Color.WHITE, true)
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
