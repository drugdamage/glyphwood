## Weapons in the hero's hand, in a gothic style: a small silhouette per weapon
## kind with a dark rim (arming sword with drooping quillons and a wheel pommel,
## flamberge, partisan with a blood-red tassel, flanged mace, rondel dagger,
## black katana, swept-hilt rapier, scythe, halberd and a headsman's axe with a
## cross cut through it), and the pose that swings it with the attacks.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const Physics := preload("res://scripts/physics.gd")

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
	elif p.get("guard", false):
		# held upright in front of the body
		a = -1.3
		reach = 6.0
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


## The weapon in the hero's hand, drawn by the renderer [r] on its dynamic layer.
static func draw_held(r, p: Dictionary, tint: Color) -> void:
	var d: Dictionary = Items.def(p.weapon)
	var kind: String = d.get("kind", "sword")
	var po := pose(p, kind)
	var a: float = po[0]
	var f: float = p.facing
	var shoulder := Physics.foot(p) + Vector2(f * 4.0, -15.0)
	var hand: Vector2 = shoulder + Vector2(cos(a) * f, sin(a)) * (4.5 + po[1])
	var col: Color = d.get("color", Color(0.85, 0.9, 1.0)) * tint
	col.a = 1.0
	draw(r._dyn, kind, r.sp(hand), a, f, r.s, col, p.st.reach)
	if kind == "dagger":
		# the off hand holds a second fang, reversed
		draw(r._dyn, kind, r.sp(Physics.foot(p) + Vector2(-f * 3.0, -13.0)), a + 2.4, f, r.s, col * 0.8, p.st.reach)


## The second weapon slung across the back, darker, behind the hero.
static func draw_back(r, p: Dictionary, tint: Color) -> void:
	if p.get("weapon2", "") == "":
		return
	var d: Dictionary = Items.def(p.weapon2)
	var f: float = p.facing
	var col: Color = d.get("color", Color(0.85, 0.9, 1.0)) * tint * 0.7
	col.a = 1.0
	var at := Physics.foot(p) + Vector2(-f * 3.0, -9.0)
	draw(r._dyn, d.get("kind", "sword"), r.sp(at), -2.05, f, r.s * 0.85, col, 1.0)


## Blackened iron, worn gold, bone and a blood-red gem, shared by every hilt.
const IRON := Color(0.36, 0.34, 0.38)
const IRON_HI := Color(0.62, 0.6, 0.66)
const GOLD := Color(0.72, 0.56, 0.26)
const BONE := Color(0.86, 0.82, 0.7)
const GEM := Color(0.78, 0.06, 0.1)
const GRIP := Color(0.16, 0.1, 0.1)
const WOOD := Color(0.24, 0.16, 0.12)
const RIM := Color(0.03, 0.01, 0.02, 0.9)


## Draws one weapon with its grip at [at] (screen), pointing along angle [a]
## (mirrored when [f] is -1), [s] pixels per world unit. +x runs from the hand
## to the tip; [col] is the weapon's own colour, used for its blade or head.
static func draw(ci: CanvasItem, kind: String, at: Vector2, a: float, f: float, s: float, col: Color, reach: float) -> void:
	var rot := a if f > 0.0 else PI - a
	ci.draw_set_transform(at, rot, Vector2(s, s * f))
	var ln := 1.0 + (reach - 1.0) * 0.6
	# blades are dark steel tinted by the weapon's colour, with a bright edge
	var steel := col.lerp(Color(0.5, 0.52, 0.58), 0.3)
	var hi := col.lerp(Color(1, 1, 1), 0.55)
	match kind:
		"great":
			_flamberge(ci, ln, steel, hi)
		"spear":
			_partisan(ci, ln, steel, hi)
		"mace":
			_flanged_mace(ci, steel, hi)
		"dagger":
			_rondel(ci, ln, steel, hi)
		"katana":
			_katana(ci, ln, col)
		"rapier":
			_rapier(ci, ln, steel, hi)
		"scythe":
			_scythe(ci, ln, col, hi)
		"halberd":
			_halberd(ci, ln, steel, hi)
		"axe":
			_headsman(ci, steel, hi)
		_:
			_arming_sword(ci, ln, steel, hi)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- parts

## A tapering blade from x0 to its point at x1, with a dark fuller and a bright edge.
static func _blade(ci: CanvasItem, x0: float, x1: float, half: float, steel: Color, hi: Color) -> void:
	var tip := x1 - half * 2.4
	_rim_poly(ci, PackedVector2Array([Vector2(x0, -half), Vector2(tip, -half * 0.85), Vector2(x1, 0), Vector2(tip, half * 0.85),
		Vector2(x0, half)]), steel, RIM)
	ci.draw_line(Vector2(x0 + 1.0, 0), Vector2(tip - 1.5, 0), Color(0.08, 0.06, 0.08, 0.8), maxf(0.35, half * 0.35))
	ci.draw_line(Vector2(x0 + 0.6, -half * 0.75), Vector2(tip, -half * 0.6), hi, 0.35)


## Quillons that droop toward the blade and end in small knobs, with a gem in the middle.
static func _cross(ci: CanvasItem, half: float, droop: float, metal: Color) -> void:
	var pts := PackedVector2Array([Vector2(droop, -half), Vector2(0, -half * 0.55), Vector2(-0.6, 0), Vector2(0, half * 0.55),
		Vector2(droop, half)])
	ci.draw_polyline(pts, RIM, 2.0)
	ci.draw_polyline(pts, metal, 1.1)
	for side in [-1.0, 1.0]:
		ci.draw_circle(Vector2(droop + 0.2, half * side), 0.85, RIM)
		ci.draw_circle(Vector2(droop + 0.2, half * side), 0.6, metal)
	_rim_poly(ci, PackedVector2Array([Vector2(-0.4, 0), Vector2(0.5, -1.2), Vector2(1.4, 0), Vector2(0.5, 1.2)]), metal, RIM)
	ci.draw_circle(Vector2(0.5, 0), 0.45, GEM)


## A wrapped grip from x0 back to x1 (x1 < x0).
static func _grip(ci: CanvasItem, x0: float, x1: float, w: float) -> void:
	ci.draw_line(Vector2(x1, 0), Vector2(x0, 0), RIM, w + 0.8)
	ci.draw_line(Vector2(x1, 0), Vector2(x0, 0), GRIP, w)
	var x := x1 + 0.6
	while x < x0 - 0.3:
		ci.draw_line(Vector2(x, -w * 0.5), Vector2(x + 0.6, w * 0.5), Color(0.38, 0.16, 0.12), 0.3)
		x += 1.0


## A wheel pommel: a ring with a cross inside.
static func _wheel(ci: CanvasItem, c: Vector2, r: float, metal: Color) -> void:
	ci.draw_circle(c, r + 0.4, RIM)
	ci.draw_circle(c, r, metal)
	ci.draw_circle(c, r * 0.55, RIM)
	ci.draw_line(c + Vector2(-r * 0.55, 0), c + Vector2(r * 0.55, 0), metal, 0.4)
	ci.draw_line(c + Vector2(0, -r * 0.55), c + Vector2(0, r * 0.55), metal, 0.4)


## A wooden haft from x0 to x1 with iron bands.
static func _haft(ci: CanvasItem, x0: float, x1: float, bands: Array) -> void:
	ci.draw_line(Vector2(x0, 0), Vector2(x1, 0), RIM, 2.6)
	ci.draw_line(Vector2(x0, 0), Vector2(x1, 0), WOOD, 1.4)
	for bx in bands:
		ci.draw_line(Vector2(bx, -1.0), Vector2(bx, 1.0), IRON, 0.8)


## A hanging strip of blood-red cloth, tied at p.
static func _tassel(ci: CanvasItem, p: Vector2) -> void:
	_rim_poly(ci, PackedVector2Array([p, p + Vector2(-1.2, 1.0), p + Vector2(-3.8, 2.6), p + Vector2(-3.0, 1.0)]), Color(0.5, 0.04, 0.07), RIM)


# ---------------------------------------------------------------- kinds

static func _arming_sword(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	_blade(ci, 1.0, 16.0 * ln, 1.35, steel, hi)
	_cross(ci, 4.4, 1.6, IRON_HI)
	_grip(ci, -0.6, -4.8, 1.6)
	_wheel(ci, Vector2(-5.8, 0), 1.25, IRON_HI)


## A two-handed flamberge: a wavy blade, parrying hooks above the ricasso.
static func _flamberge(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var end := 21.0 * ln
	var n := 14
	for k in n + 1:
		var x := lerpf(4.0, end - 3.0, float(k) / n)
		var w := lerpf(2.1, 1.0, float(k) / n) + 0.45 * sin(x * 1.1)
		top.append(Vector2(x, -w))
		bottom.append(Vector2(x, w))
	top.append(Vector2(end, 0))
	bottom.reverse()
	var pts := PackedVector2Array([Vector2(1.0, -1.5)])
	pts.append_array(top)
	pts.append_array(bottom)
	pts.append(Vector2(1.0, 1.5))
	_rim_poly(ci, pts, steel, RIM)
	ci.draw_line(Vector2(4.5, 0), Vector2(end - 4.0, 0), Color(0.08, 0.06, 0.08, 0.8), 0.6)
	ci.draw_line(Vector2(4.5, -1.5), Vector2(end - 4.0, -0.7), hi, 0.35)
	for side in [-1.0, 1.0]:
		_rim_poly(ci, PackedVector2Array([Vector2(3.2, 1.4 * side), Vector2(4.6, 3.2 * side), Vector2(4.2, 1.4 * side)]), IRON_HI, RIM)
	_cross(ci, 6.2, 2.2, IRON_HI)
	_grip(ci, -0.8, -8.0, 2.0)
	_rim_poly(ci, PackedVector2Array([Vector2(-8.0, 0), Vector2(-9.2, -1.6), Vector2(-10.6, 0), Vector2(-9.2, 1.6)]), IRON_HI, RIM)
	ci.draw_circle(Vector2(-9.2, 0), 0.55, GEM)


## A partisan: a long leaf blade with two curved wings and a red tassel.
static func _partisan(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	_haft(ci, -13.0, 12.0 * ln, [-9.0, -4.0, 8.0 * ln])
	_tassel(ci, Vector2(11.0 * ln, 1.0))
	for side in [-1.0, 1.0]:
		_rim_poly(ci, PackedVector2Array([Vector2(12.0 * ln, 0.8 * side), Vector2(11.0 * ln, 4.6 * side), Vector2(13.4 * ln, 3.4 * side),
			Vector2(14.0 * ln, 1.0 * side)]), steel, RIM)
	_rim_poly(ci, PackedVector2Array([Vector2(12.6 * ln, -1.6), Vector2(19.0 * ln, -1.0), Vector2(23.0 * ln, 0), Vector2(19.0 * ln, 1.0),
		Vector2(12.6 * ln, 1.6)]), steel, RIM)
	ci.draw_line(Vector2(13.4 * ln, 0), Vector2(20.0 * ln, 0), Color(0.08, 0.06, 0.08, 0.8), 0.5)
	ci.draw_line(Vector2(13.4 * ln, -1.1), Vector2(21.0 * ln, -0.5), hi, 0.35)
	ci.draw_circle(Vector2(12.2 * ln, 0), 0.9, GOLD)


## A flanged mace: an iron crown of blades around a spike, on a banded shaft.
static func _flanged_mace(ci: CanvasItem, steel: Color, hi: Color) -> void:
	_grip(ci, 1.0, -4.5, 1.7)
	ci.draw_line(Vector2(0.8, 0), Vector2(10.0, 0), RIM, 2.6)
	ci.draw_line(Vector2(0.8, 0), Vector2(10.0, 0), IRON, 1.5)
	ci.draw_line(Vector2(3.5, -1.1), Vector2(3.5, 1.1), GOLD, 0.7)
	_wheel(ci, Vector2(-5.4, 0), 1.0, IRON_HI)
	var head := Vector2(12.5, 0)
	for k in 6:
		var sa := -PI * 0.5 + k * PI / 5.0
		var d := Vector2(cos(sa) * 0.6, sin(sa))
		_rim_poly(ci, PackedVector2Array([head + d * 1.2 + Vector2(-2.0, 0), head + d * 5.0 + Vector2(-1.0, 0), head + d * 5.0 + Vector2(1.6, 0),
			head + d * 1.2 + Vector2(2.4, 0)]), steel, RIM)
	ci.draw_circle(head, 2.4, RIM)
	ci.draw_circle(head, 1.9, IRON)
	_rim_poly(ci, PackedVector2Array([head + Vector2(1.5, -1.0), head + Vector2(6.0, 0), head + Vector2(1.5, 1.0)]), hi, RIM)
	ci.draw_circle(head, 0.7, GEM)


## A rondel dagger: a slim spike between two iron discs.
static func _rondel(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	_blade(ci, 0.9, 10.5 * ln, 0.9, steel, hi)
	for x in [0.4, -3.8]:
		ci.draw_line(Vector2(x, -2.4), Vector2(x, 2.4), RIM, 1.6)
		ci.draw_line(Vector2(x, -2.2), Vector2(x, 2.2), IRON_HI, 0.8)
	_grip(ci, 0.0, -3.6, 1.3)
	ci.draw_circle(Vector2(-3.8, 0), 0.45, GEM)


## A dark-steel katana with an edge in its own colour and a four-lobed guard.
static func _katana(ci: CanvasItem, ln: float, col: Color) -> void:
	var edge := PackedVector2Array()
	var back := PackedVector2Array()
	for k in 9:
		var q := k / 8.0
		var x := 1.0 + q * 17.0 * ln
		var bow := -2.2 * q * q
		edge.append(Vector2(x, bow - 1.1 * (1.0 - q * 0.8)))
		back.append(Vector2(x, bow + 0.9 * (1.0 - q)))
	var line := edge.duplicate()
	back.reverse()
	edge.append_array(back)
	_rim_poly(ci, edge, Color(0.3, 0.28, 0.33), RIM)
	ci.draw_polyline(line, col, 0.45)
	for d in [Vector2(0, -1.3), Vector2(0, 1.3), Vector2(-0.6, 0), Vector2(0.6, 0)]:
		ci.draw_circle(d, 1.05, RIM)
		ci.draw_circle(d, 0.75, GOLD)
	ci.draw_line(Vector2(-6.5, 0), Vector2(-0.6, 0), RIM, 2.2)
	ci.draw_line(Vector2(-6.5, 0), Vector2(-0.6, 0), Color(0.1, 0.06, 0.08), 1.5)
	for k in 3:
		ci.draw_line(Vector2(-5.6 + k * 1.7, -0.75), Vector2(-4.8 + k * 1.7, 0.75), col * 0.8, 0.5)
	ci.draw_circle(Vector2(-6.6, 0), 0.7, GOLD)


## A rapier: a long needle blade under a swept hilt of loops.
static func _rapier(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	_blade(ci, 1.0, 19.0 * ln, 0.75, steel, hi)
	_cross(ci, 3.4, -0.8, GOLD)
	for r in [2.6, 3.6]:
		ci.draw_arc(Vector2(-1.6, 0), r, PI * 0.55, PI * 1.45, 10, RIM, 1.1)
		ci.draw_arc(Vector2(-1.6, 0), r, PI * 0.55, PI * 1.45, 10, GOLD, 0.5)
	_grip(ci, -0.6, -4.4, 1.3)
	_rim_poly(ci, PackedVector2Array([Vector2(-4.4, 0), Vector2(-5.2, -1.1), Vector2(-6.4, 0), Vector2(-5.2, 1.1)]), GOLD, RIM)


## A scythe: a long snath with two nibs, a skull-knot and a crescent of bone
## that sweeps back toward the hand.
static func _scythe(ci: CanvasItem, ln: float, col: Color, hi: Color) -> void:
	var tip := 14.0 * ln
	_haft(ci, -12.0, tip, [-10.0])
	for nx in [-5.0, 4.0]:
		ci.draw_line(Vector2(nx, 0), Vector2(nx + 0.8, 2.6), RIM, 1.6)
		ci.draw_line(Vector2(nx, 0), Vector2(nx + 0.8, 2.6), WOOD, 0.8)
	# the back of the blade is a curve from the snath's end up and back; the
	# blade and its edge lie on the inner side, widest at the heel
	var p0 := Vector2(tip, -0.5)
	var p1 := Vector2(tip + 4.0, -9.0 * ln)
	var p2 := Vector2(tip - 10.0 * ln, -12.0 * ln)
	var spine := PackedVector2Array()
	var inner := PackedVector2Array()
	var n := 12
	for k in n + 1:
		var q := float(k) / n
		var pt := p0.lerp(p1, q).lerp(p1.lerp(p2, q), q)
		var tan := (p1 - p0).lerp(p2 - p1, q).normalized()
		var inward := Vector2(tan.y, -tan.x)
		spine.append(pt)
		inner.append(pt + inward * 3.2 * (1.0 - pow(q, 2.5)))
	var edge := inner.duplicate()
	inner.reverse()
	spine.append_array(inner)
	_rim_poly(ci, spine, col, RIM)
	ci.draw_polyline(edge, hi, 0.45)
	# a small skull binding the blade to the snath
	ci.draw_circle(Vector2(tip, 0), 1.5, RIM)
	ci.draw_circle(Vector2(tip, 0), 1.15, BONE)
	ci.draw_circle(Vector2(tip - 0.4, -0.45), 0.3, RIM)
	ci.draw_circle(Vector2(tip - 0.4, 0.45), 0.3, RIM)


## A halberd: spike, crescent axe, back fluke and a red tassel on a banded pole.
static func _halberd(ci: CanvasItem, ln: float, steel: Color, hi: Color) -> void:
	var top := 15.0 * ln
	_haft(ci, -12.0, top, [-8.0, top - 5.0])
	_tassel(ci, Vector2(top - 5.5, 1.0))
	_rim_poly(ci, PackedVector2Array([Vector2(top - 1.0, -1.0), Vector2(top + 7.0, 0), Vector2(top - 1.0, 1.0)]), steel, RIM)
	var blade := PackedVector2Array([Vector2(top - 4.5, 0.8)])
	for k in 7:
		var q := k / 6.0
		blade.append(Vector2(top - 6.5 + q * 7.5, 0.8 + 6.5 - pow(q * 2.0 - 1.0, 2.0) * 1.8 + q * 0.5))
	blade.append(Vector2(top + 0.5, 0.8))
	_rim_poly(ci, blade, steel, RIM)
	ci.draw_line(Vector2(top - 5.8, 6.4), Vector2(top + 0.6, 7.6), hi, 0.4)
	ci.draw_line(Vector2(top - 2.6, 2.4), Vector2(top - 2.6, 5.2), Color(0.06, 0.04, 0.06), 0.5)
	ci.draw_line(Vector2(top - 3.6, 3.4), Vector2(top - 1.6, 3.4), Color(0.06, 0.04, 0.06), 0.5)
	_rim_poly(ci, PackedVector2Array([Vector2(top - 3.0, -0.8), Vector2(top - 5.5, -5.0), Vector2(top - 1.2, -0.8)]), IRON_HI, RIM)


## A headsman's axe: a broad blade with a long beard and a cross cut through it.
static func _headsman(ci: CanvasItem, steel: Color, hi: Color) -> void:
	_haft(ci, -6.0, 14.5, [-3.0, 7.5])
	var edge := PackedVector2Array()
	for k in 7:
		var q := k / 6.0
		edge.append(Vector2(lerpf(6.4, 17.0, q), -10.6 - sin(q * PI) * 1.8 + q * 0.6))
	var head := PackedVector2Array([Vector2(10.0, -1.2), Vector2(9.6, -5.4), Vector2(6.4, -8.8)])
	head.append_array(edge)
	head.append_array(PackedVector2Array([Vector2(16.6, -6.2), Vector2(15.4, -2.4), Vector2(14.6, -1.2)]))
	_rim_poly(ci, head, steel, RIM)
	ci.draw_polyline(edge, hi, 0.55)
	var c := Vector2(12.6, -6.4)
	ci.draw_line(c + Vector2(0, -2.4), c + Vector2(0, 2.6), Color(0.02, 0.01, 0.02), 1.1)
	ci.draw_line(c + Vector2(-1.6, -0.8), c + Vector2(1.6, -0.8), Color(0.02, 0.01, 0.02), 1.1)
	_rim_poly(ci, PackedVector2Array([Vector2(13.8, 0.8), Vector2(15.4, 4.2), Vector2(15.8, 0.8)]), IRON_HI, RIM)
	ci.draw_circle(Vector2(14.5, 0), 0.6, GOLD)


static func _rim_poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, rim: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, rim, 0.7, true)
