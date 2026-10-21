## Weapons in the hero's hand: a small silhouette per weapon kind (sword,
## great sword, spear, mace, dagger, katana, rapier, scythe, halberd, axe) with
## a dark rim, and the pose that swings it with the attacks.
extends RefCounted

## Resting angle of each weapon kind (radians, facing right; +y is down).
const REST := {"sword": 1.05, "great": -2.45, "spear": -1.35, "mace": -2.3, "dagger": 1.3, "katana": 2.55, "rapier": 0.9,
	"scythe": -1.75, "halberd": -1.4, "axe": -2.35}
## Kinds swung from high over the shoulder and kept there in the air.
const HEAVY := ["great", "mace", "scythe", "halberd", "axe"]


## The angle the weapon points at and how far the hand reaches out, from the
## hero's state: swings follow the attack, otherwise it rests by kind.
static func pose(p: Dictionary, kind: String) -> Array:
	var reach := 0.0
	var a: float = REST.get(kind, 1.05)
	if p.atk_t > 0.0:
		var k := clampf((p.atk_len - p.atk_t) / maxf(0.01, p.atk_len * 0.55), 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		match p.atk_kind:
			"side":
				if kind == "spear" or (kind in ["dagger", "rapier"] and p.combo != 2):
					a = 0.05
					reach = 9.0 * sin(k * PI)
				elif p.combo == 1:
					a = lerpf(1.2, -1.75, k)
				else:
					a = lerpf(-2.0 if kind in HEAVY else -1.7, 1.15, k)
			"up", "rise":
				a = lerpf(0.1, -2.3, k)
			"down":
				a = PI * 0.5
				reach = 3.0
			"lunge":
				a = 0.0
				reach = 7.0
	elif p.slam:
		a = PI * 0.5
	elif p.dash_t > 0.0:
		a = 2.9
	elif p.throw_t > 0.15:
		a = -2.2
	elif p.hurt_t > 0.0:
		a = -2.0
	elif p.sliding:
		a = -1.6
	elif not p.on_floor and kind not in HEAVY:
		a -= 0.35
	else:
		a += sin(p.anim * (9.0 if absf(p.vel.x) > 20.0 else 1.8)) * 0.06
	return [a, reach]


## Draws one weapon with its grip at [at] (screen), pointing along angle [a]
## (mirrored when [f] is -1), [s] pixels per world unit.
static func draw(ci: CanvasItem, kind: String, at: Vector2, a: float, f: float, s: float, col: Color, reach: float) -> void:
	var rot := a if f > 0.0 else PI - a
	ci.draw_set_transform(at, rot, Vector2(s, s * f))
	var dark := Color(0.03, 0.01, 0.02, 0.85)
	var grip := Color(0.3, 0.2, 0.16)
	var iron := Color(0.55, 0.5, 0.48)
	var hi := col.lerp(Color(1, 1, 1), 0.45)
	var blade := PackedVector2Array()
	var ln := 1.0 + (reach - 1.0) * 0.6
	match kind:
		"great":
			blade = PackedVector2Array([Vector2(1, -2.1), Vector2(18 * ln, -1.7), Vector2(22 * ln, 0), Vector2(18 * ln, 1.7), Vector2(1, 2.1)])
			_rim_poly(ci, blade, col, dark)
			ci.draw_line(Vector2(2, 0), Vector2(17 * ln, 0), hi, 0.8)
			_rim_poly(ci, PackedVector2Array([Vector2(-1.2, -5.5), Vector2(1.2, -4.5), Vector2(1.2, 4.5), Vector2(-1.2, 5.5)]), iron, dark)
			ci.draw_line(Vector2(-7, 0), Vector2(-1.2, 0), grip, 2.0)
			ci.draw_circle(Vector2(-7.8, 0), 1.6, iron)
		"spear":
			ci.draw_line(Vector2(-13, 0), Vector2(13 * ln, 0), dark, 2.6)
			ci.draw_line(Vector2(-13, 0), Vector2(13 * ln, 0), Color(0.42, 0.3, 0.22), 1.4)
			blade = PackedVector2Array([Vector2(13 * ln, -2.4), Vector2(21 * ln, 0), Vector2(13 * ln, 2.4), Vector2(11.5 * ln, 0)])
			_rim_poly(ci, blade, col, dark)
			ci.draw_line(Vector2(11 * ln, -2.8), Vector2(11 * ln, 2.8), iron, 1.2)
		"mace":
			ci.draw_line(Vector2(-4, 0), Vector2(10, 0), dark, 2.8)
			ci.draw_line(Vector2(-4, 0), Vector2(10, 0), grip, 1.6)
			var head := Vector2(12.5, 0)
			for k in 8:
				var sa := k * TAU / 8.0
				var dir := Vector2(cos(sa), sin(sa))
				_rim_poly(ci, PackedVector2Array([head + dir.rotated(0.4) * 2.6, head + dir * 5.6, head + dir.rotated(-0.4) * 2.6]), iron, dark)
			ci.draw_circle(head, 3.4, dark)
			ci.draw_circle(head, 2.8, col)
			ci.draw_circle(head + Vector2(-0.8, -0.8), 1.0, hi)
		"dagger":
			blade = PackedVector2Array([Vector2(0.8, -1.1), Vector2(7 * ln, -0.7), Vector2(9.5 * ln, 0), Vector2(7 * ln, 0.7), Vector2(0.8, 1.1)])
			_rim_poly(ci, blade, col, dark)
			ci.draw_line(Vector2(0.4, -2.6), Vector2(0.4, 2.6), iron, 1.1)
			ci.draw_line(Vector2(-3, 0), Vector2(0, 0), grip, 1.6)
		"katana":
			var edge := PackedVector2Array()
			var back := PackedVector2Array()
			for k in 9:
				var q := k / 8.0
				var x := 1.0 + q * 17.0 * ln
				var bow := -2.2 * q * q
				edge.append(Vector2(x, bow - 1.1 * (1.0 - q * 0.8)))
				back.append(Vector2(x, bow + 0.9 * (1.0 - q)))
			back.reverse()
			edge.append_array(back)
			_rim_poly(ci, edge, col, dark)
			ci.draw_circle(Vector2(0, 0), 2.1, dark)
			ci.draw_circle(Vector2(0, 0), 1.6, Color(0.7, 0.55, 0.3))
			ci.draw_line(Vector2(-6, 0), Vector2(-0.5, 0), Color(0.12, 0.08, 0.1), 1.9)
			for k in 3:
				ci.draw_line(Vector2(-5.2 + k * 1.7, -0.9), Vector2(-4.4 + k * 1.7, 0.9), Color(0.75, 0.15, 0.15), 0.6)
		"rapier":
			ci.draw_line(Vector2(1, 0), Vector2(17 * ln, 0), dark, 1.9)
			ci.draw_line(Vector2(1, 0), Vector2(17 * ln, 0), col, 0.9)
			ci.draw_arc(Vector2(0.6, 0), 2.6, -1.4, 1.4, 8, iron, 1.1)
			ci.draw_line(Vector2(0.4, -3.2), Vector2(0.4, 3.2), iron, 0.9)
			ci.draw_line(Vector2(-4, 0), Vector2(0, 0), grip, 1.5)
			ci.draw_circle(Vector2(-4.6, 0), 1.1, iron)
		"scythe":
			ci.draw_line(Vector2(-12, 0), Vector2(14 * ln, 0), dark, 2.6)
			ci.draw_line(Vector2(-12, 0), Vector2(14 * ln, 0), Color(0.36, 0.26, 0.2), 1.4)
			var arc := PackedVector2Array()
			var inner := PackedVector2Array()
			for k in 9:
				var q := k / 8.0
				var ang := -0.2 - q * 2.0
				arc.append(Vector2(14 * ln, 0) + Vector2(cos(ang), sin(ang)) * Vector2(3.0, 12.0 * ln) * (1.0 - q * 0.15))
				inner.append(Vector2(14 * ln, 0) + Vector2(cos(ang), sin(ang)) * Vector2(1.2, 9.0 * ln) * (1.0 - q * 0.05))
			inner.reverse()
			arc.append_array(inner)
			_rim_poly(ci, arc, col, dark)
			ci.draw_circle(Vector2(14 * ln, 0), 1.3, iron)
		"halberd":
			ci.draw_line(Vector2(-12, 0), Vector2(15 * ln, 0), dark, 2.6)
			ci.draw_line(Vector2(-12, 0), Vector2(15 * ln, 0), Color(0.4, 0.3, 0.22), 1.4)
			_rim_poly(ci, PackedVector2Array([Vector2(15 * ln, -1.4), Vector2(21 * ln, 0), Vector2(15 * ln, 1.4)]), col, dark)
			_rim_poly(ci, PackedVector2Array([Vector2(10 * ln, 0.6), Vector2(9 * ln, 6.5), Vector2(12 * ln, 7.5), Vector2(14.5 * ln, 0.6)]), col,
				dark)
			_rim_poly(ci, PackedVector2Array([Vector2(12 * ln, -0.6), Vector2(11 * ln, -4.0), Vector2(13.5 * ln, -0.6)]), iron, dark)
		"axe":
			ci.draw_line(Vector2(-5, 0), Vector2(13, 0), dark, 2.8)
			ci.draw_line(Vector2(-5, 0), Vector2(13, 0), grip, 1.6)
			var head := PackedVector2Array([Vector2(8.5, -1.2), Vector2(9.5, -7.5), Vector2(14.5, -8.5), Vector2(15.5, -3.0),
				Vector2(14.5, 1.0), Vector2(10.5, 1.4)])
			_rim_poly(ci, head, col, dark)
			ci.draw_line(Vector2(14.3, -7.6), Vector2(15.1, -2.8), hi, 0.7)
			_rim_poly(ci, PackedVector2Array([Vector2(10, 1.2), Vector2(11, 3.6), Vector2(12.4, 1.2)]), iron, dark)
		_:
			blade = PackedVector2Array([Vector2(1, -1.3), Vector2(12 * ln, -1.0), Vector2(15 * ln, 0), Vector2(12 * ln, 1.0), Vector2(1, 1.3)])
			_rim_poly(ci, blade, col, dark)
			ci.draw_line(Vector2(2, 0), Vector2(11 * ln, 0), hi, 0.6)
			_rim_poly(ci, PackedVector2Array([Vector2(-0.9, -4), Vector2(0.9, -3.2), Vector2(0.9, 3.2), Vector2(-0.9, 4)]), iron, dark)
			ci.draw_line(Vector2(-4.5, 0), Vector2(-0.9, 0), grip, 1.7)
			ci.draw_circle(Vector2(-5.2, 0), 1.3, iron)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rim_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, rim: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, rim, 0.7, true)
