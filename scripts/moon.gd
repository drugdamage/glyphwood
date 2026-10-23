## The blood moon over open-sky biomes, in three cached layers placed over the
## sky each frame: the throbbing halo (its heartbeat is the layer's alpha), the
## body (shading, craters, cracks and the eclipse shadow, repainted only when
## the shadow moves) and the few moving bits (clouds, eye, drips, a bat),
## repainted every frame. Drawn by renderer.gd, whose values it reads.
extends Node2D

const Physics := preload("res://scripts/physics.gd")


## A layer whose drawing is done by a callback and kept until redrawn.
class Layer:
	extends Node2D
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


var _w
var _halo: Layer
var _body: Layer
var _fx: Layer
var _c := Vector2.ZERO
var _r := 0.0
var _key := ""


func setup(renderer) -> void:
	_w = renderer
	_halo = _layer(_paint_halo)
	_body = _layer(_paint_body)
	_fx = _layer(_paint_fx)


func _layer(fn: Callable) -> Layer:
	var p := Layer.new()
	p.fn = fn
	add_child(p)
	return p


## Places the layers for this frame.
func place() -> void:
	visible = _w.game.biome.sky
	if not visible:
		return
	# the moon drifts very slowly against the camera
	var title: bool = _w.game.is_title()
	_c = Vector2(_w.vp.x * (0.87 if title else 0.78), _w.vp.y * (0.1 if title else 0.15)) - _w.game.cam * _w.s * 0.02
	var r := minf(24.0 * _w.s, _w.vp.y * 0.075)
	var hb := fposmod(_w.t, 1.5)
	var beat := exp(-hb * 8.0) + (0.7 * exp(-(hb - 0.28) * 8.0) if hb > 0.28 else 0.0)
	_halo.modulate.a = (0.75 + 0.6 * beat) / 1.35
	var key := "%.2f|%.2f" % [r, snappedf(sin(_w.t * 0.05), 0.02)]
	if r != _r:
		_r = r
		_halo.queue_redraw()
	if key != _key:
		_key = key
		_body.queue_redraw()
	position = _c
	_fx.queue_redraw()


## The halo around a blood moon, at the peak of its heartbeat (the layer's
## alpha follows the beat).
func _paint_halo(ci: CanvasItem) -> void:
	for k in 7:
		var f := 1.0 + k * 0.45
		ci.draw_circle(Vector2.ZERO, _r * f, Color(0.6, 0.02, 0.03, 0.07 * 1.35 * (1.0 - k / 7.0)))


## A blood moon: a shaded disc with an eclipse shadow eating into it and
## craters that read as a skull, cracks across it.
func _paint_body(ci: CanvasItem) -> void:
	var r := _r
	var disc: PackedVector2Array = _w._circle_poly(Vector2.ZERO, r, 40)
	# shading from deep blood at the rim to a sick glow toward the upper left
	for k in 7:
		var f := 1.0 - k / 7.0
		ci.draw_circle(Vector2(-0.22, -0.26) * r * (1.0 - f), r * f, Color(0.42, 0.03, 0.03).lerp(Color(0.86, 0.22, 0.12), 1.0 - f))
	# craters: two sockets, a nose and a row of teeth, plus scattered pits
	var pits := [[-0.36, -0.12, 0.2], [0.14, -0.14, 0.19], [-0.1, 0.17, 0.08], [0.52, 0.34, 0.07], [-0.55, 0.3, 0.06],
		[0.1, -0.6, 0.06], [-0.2, -0.55, 0.05]]
	for i in 5:
		pits.append([-0.36 + i * 0.12, 0.43, 0.045])
	for q in pits:
		var pc := Vector2(q[0], q[1]) * r
		ci.draw_circle(pc + Vector2(0.03, 0.04) * r, q[2] * r, Color(0.95, 0.38, 0.22, 0.35))
		ci.draw_circle(pc, q[2] * r, Color(0.28, 0.02, 0.03, 0.85))
	# cracks
	var cracks := [[Vector2(-0.9, -0.2), Vector2(-0.55, -0.1), Vector2(-0.4, 0.05)],
		[Vector2(0.3, 0.6), Vector2(0.45, 0.8), Vector2(0.4, 0.95)],
		[Vector2(0.6, -0.7), Vector2(0.4, -0.45), Vector2(0.42, -0.3)]]
	for cr in cracks:
		var line := PackedVector2Array()
		for v in cr:
			line.append(v * r)
		ci.draw_polyline(line, Color(0.2, 0.0, 0.02, 0.8), maxf(1.0, r * 0.03))
	# the eclipse shadow, kept inside the disc
	var shadow: PackedVector2Array = _w._circle_poly(Vector2(0.9, 0.12) * r * (0.95 + 0.05 * snappedf(sin(_w.t * 0.05), 0.02)), r * 0.98, 40)
	for poly in Geometry2D.intersect_polygons(disc, shadow):
		ci.draw_colored_polygon(poly, Color(0.07, 0.0, 0.01, 0.78))


## What moves on the moon: drifting black clouds, a burning eye, blood dripping
## from the rim and now and then a bat crossing it.
func _paint_fx(ci: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_paint_fx_inner(ci)
	_w.game.prof_add("moon", t0)


func _paint_fx_inner(ci: CanvasItem) -> void:
	var r := _r
	for k in 3:
		var cw := r * (2.6 + k * 0.7)
		var cx := fposmod(_w.t * (6.0 + k * 3.0) * _w.s + k * 140.0 * _w.s, cw + r * 6.0) - cw * 0.5 - r * 3.0
		var cy := (-0.35 + k * 0.42) * r
		var ell := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			ell.append(Vector2(cx + cos(a) * cw * 0.5, cy + sin(a) * r * 0.09))
		ci.draw_colored_polygon(ell, Color(0.03, 0.01, 0.02, 0.72))
	_draw_moon_eye(ci, Vector2(-0.36, -0.12) * r, r)
	# blood runs down from the lower rim and drips off
	var blood := Color(0.55, 0.02, 0.03)
	for i in 4:
		var x: float = [-0.32, 0.06, 0.3, -0.12][i]
		var top := Vector2(x, sqrt(1.0 - x * x) - 0.04) * r
		var ph := fposmod(_w.t * 0.3 + i * 0.29, 1.0)
		var drip := r * 0.22 * minf(ph * 2.0, 1.0)
		ci.draw_line(top, top + Vector2(0, drip), blood, maxf(1.0, r * 0.05))
		if ph > 0.5:
			var f := (ph - 0.5) * 2.0
			ci.draw_circle(top + Vector2(0, drip + f * f * r * 3.0), maxf(1.0, r * 0.045), Color(blood, 1.0 - f))
	var bt := fposmod(_w.t, 23.0)
	if bt < 4.0:
		var bp := Vector2(lerpf(-2.2, 2.2, bt / 4.0) * r, sin(bt * 5.0) * r * 0.15 - r * 0.2)
		var bat := "^v^" if int(_w.t * 8.0) % 2 == 0 else "vvv"
		var bw: float = _w.bold.get_string_size(bat, HORIZONTAL_ALIGNMENT_LEFT, -1, _w.fs).x
		ci.draw_string(_w.bold, Vector2(bp.x - bw * 0.5, bp.y + _w.fs * 0.36), bat, HORIZONTAL_ALIGNMENT_LEFT, -1, _w.fs, Color(0.02, 0.0, 0.01))


## A burning slit eye in the moon's left socket (at [e] from the moon's centre)
## that looks toward the hero and blinks every few seconds.
func _draw_moon_eye(ci: CanvasItem, e: Vector2, r: float) -> void:
	var look := Vector2(_w.vp.x * 0.5, _w.vp.y * 0.6) - _c
	if not _w.game.player.is_empty() and not _w.game.is_title():
		look = _w.sp(Physics.center(_w.game.player)) - _c
	var bl := fposmod(_w.t, 6.7)
	var open := 1.0 if bl > 0.24 else absf(bl - 0.12) / 0.12
	var glow := 0.75 + 0.25 * sin(_w.t * 3.1)
	ci.draw_circle(e, r * 0.32, Color(1.0, 0.35, 0.05, 0.14 * open * glow))
	var iris := Color(1.0, 0.72, 0.18).lerp(Color(1.0, 0.95, 0.5), glow - 0.75)
	ci.draw_colored_polygon(_w._ellipse(e, Vector2(0.16, 0.13 * open + 0.01) * r, 20), iris)
	var pp := e + (look - e).normalized() * r * 0.06
	ci.draw_colored_polygon(_w._ellipse(pp, Vector2(0.03, 0.11 * open + 0.005) * r, 12), Color(0.05, 0.0, 0.0))
	# a scowling brow slanting down toward the middle of the face
	ci.draw_line(e + Vector2(-0.24, -0.27) * r, e + Vector2(0.22, -0.12) * r, Color(0.12, 0.0, 0.01), maxf(1.5, r * 0.08))
