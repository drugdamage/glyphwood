## Screen-space interface: hearts, flasks, shards, level banner, title, pause and death screens.
extends Node2D

const D := preload("res://scripts/data.gd")

var game
var font: Font
var bold: Font
var t := 0.0
var _banner_level := -1
var _banner_t := 0.0


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
	var s: float = vp.y / 900.0
	if game.hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.85, 0.05, 0.05, game.hurt_flash * 0.16))
	match int(game.state):  # 0 TITLE, 1 PLAY, 2 DEAD, 3 PAUSE
		0:
			_draw_title(vp, s)
		1:
			_draw_play(vp, s)
		2:
			_draw_play(vp, s)
			_draw_dead(vp, s)
		3:
			_draw_play(vp, s)
			_draw_pause(vp, s)
	if game.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, game.fade))


func _text(pos: Vector2, text: String, size: int, color: Color, f: Font = null) -> float:
	var fnt := f if f != null else font
	draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _center(y: float, text: String, size: int, color: Color, f: Font = null) -> void:
	var fnt := f if f != null else font
	var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(fnt, Vector2((get_viewport_rect().size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_play(vp: Vector2, s: float) -> void:
	var p: Dictionary = game.player
	if p.is_empty():
		return
	for i in 12:
		draw_rect(Rect2(0, i * 9.0 * s, vp.x, 9.0 * s), Color(0, 0, 0, 0.55 * (1.0 - i / 12.0)))
	var x := 28.0 * s
	var y := 44.0 * s
	var hs := int(26 * s)
	for i in p.max_hp:
		var full: bool = i < p.hp
		var c := Color(1.0, 0.32, 0.38) if full else Color(0.3, 0.12, 0.14)
		if full and p.hp <= 1:
			c = c * (0.7 + 0.3 * sin(t * 10.0))
			c.a = 1.0
		x += _text(Vector2(x, y), "♥", hs, c, bold) + 6.0 * s
	y += 30.0 * s
	x = 28.0 * s
	var fs := int(17 * s)
	for i in p.max_flasks:
		var on: bool = i < p.flasks
		x += _text(Vector2(x, y), "[+]", fs, Color(0.5, 1.0, 0.6) if on else Color(0.2, 0.3, 0.22), bold) + 8.0 * s
	x += 14.0 * s
	x += _text(Vector2(x, y), "* ", fs, Color(1.0, 0.85, 0.35), bold)
	_text(Vector2(x, y), str(game.shard_count), fs, Color(0.92, 0.9, 0.82))

	var label := "%s  %d" % [game.biome_name(), game.level_num]
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_text(Vector2(vp.x - lw - 28.0 * s, 44.0 * s), label, fs, game.biome.top * 0.9)

	if _banner_level != game.level_num:
		_banner_level = game.level_num
		_banner_t = 0.0
	if _banner_t < 3.0:
		var a := clampf(minf(_banner_t * 2.0, (3.0 - _banner_t) * 1.5), 0.0, 1.0)
		var c: Color = game.biome.top
		c.a = a
		_center(vp.y * 0.3, game.biome_name().to_upper(), int(44 * s), c, bold)
		var c2 := Color(0.8, 0.85, 0.82, a * 0.8)
		_center(vp.y * 0.3 + 34 * s, game.L("cleared") % game.level_num, int(16 * s), c2)

	if game.level_num == 1 and game.level_time < 14.0:
		var a2 := clampf((14.0 - game.level_time) * 0.5, 0.0, 0.85)
		_center(vp.y - 26.0 * s, game.L("controls"), int(14 * s), Color(0.75, 0.82, 0.78, a2))


func _draw_title(vp: Vector2, s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))
	var title := "GLYPHWOOD"
	var fs := int(84 * s)
	var spacing := 14.0 * s
	var widths: Array[float] = []
	var total := 0.0
	for c in title:
		var cw := bold.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(cw)
		total += cw + spacing
	total -= spacing
	var y := vp.y * 0.42
	var x := (vp.x - total) * 0.5
	var glitch := "#%&*+=/\\|"
	var accent: Color = game.biome.top
	for i in title.length():
		var g := title[i]
		if sin(t * 6.0 + i * 13.0) > 0.997:
			g = glitch[int(t * 20.0 + i) % glitch.length()]
		var col := Color(0.95, 0.96, 0.92).lerp(accent, 0.35 + 0.25 * sin(t * 0.8 + i * 0.5))
		var gw := bold.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(bold, Vector2(x + (widths[i] - gw) * 0.5, y), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += widths[i] + spacing
	_center(y + 46 * s, game.L("subtitle"), int(20 * s), Color(0.75, 0.82, 0.78))
	var a := 0.7 + 0.3 * sin(t * 3.0)
	_center(y + 110 * s, game.L("press_start"), int(20 * s), Color(1.0, 0.45, 0.38, a), bold)
	_center(vp.y - 58 * s, game.L("controls"), int(14 * s), Color(0.6, 0.68, 0.64))
	_center(vp.y - 30 * s, game.L("title_keys"), int(13 * s), Color(0.45, 0.52, 0.5))


func _draw_pause(vp: Vector2, s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.6))
	_center(vp.y * 0.45, game.L("paused"), int(54 * s), Color(0.95, 0.95, 0.9), bold)
	_center(vp.y * 0.45 + 50 * s, game.L("pause_keys"), int(16 * s), Color(0.7, 0.78, 0.74))
	_center(vp.y - 30 * s, game.L("controls"), int(14 * s), Color(0.6, 0.68, 0.64))


func _draw_dead(vp: Vector2, s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.62))
	var y := vp.y * 0.42
	_center(y, game.L("died"), int(64 * s), Color(1.0, 0.32, 0.28), bold)
	_center(y + 50 * s, game.L("died_sub") % [game.biome_name(), game.level_num], int(18 * s), Color(0.88, 0.9, 0.88))
	var secs := int(game.run_time)
	var tm := "%d:%02d" % [secs / 60, secs % 60]
	_center(y + 82 * s, game.L("stats") % [game.kills, game.shard_count, tm], int(16 * s), Color(0.62, 0.7, 0.66))
	var a := 0.55 + 0.45 * sin(t * 3.0)
	_center(y + 130 * s, game.L("again"), int(16 * s), Color(1.0, 0.9, 0.55, a))
