## Item pictures for the inventory, the merchant and the equipment slots of the
## HUD, drawn as small gothic vector images: weapons come from weapon_art.gd,
## laid across the frame; throwing weapons, charms, armour and the merchant's
## services each have their own picture in dark-rimmed iron, bone, gold and the
## item's colour. Coordinates are in a unit square: -1..1 across, +y down.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const WeaponArt := preload("res://scripts/weapon_art.gd")

const RIM := Color(0.03, 0.01, 0.02, 0.92)
const IRON := Color(0.36, 0.34, 0.38)
const IRON_HI := Color(0.62, 0.6, 0.66)
const GOLD := Color(0.78, 0.6, 0.28)
const BONE := Color(0.86, 0.82, 0.7)
const BLOOD := Color(0.62, 0.04, 0.08)
const WOOD := Color(0.3, 0.2, 0.14)
const CLOTH := Color(0.2, 0.15, 0.14)

## How far each weapon kind reaches along and across its blade (weapon_art
## units: x from the pommel to the tip, y across), to fit it in the frame.
const EXTENT := {
	"sword": Rect2(-7, -4.5, 23, 9), "great": Rect2(-10.6, -6.2, 31.6, 12.4), "spear": Rect2(-13, -4.6, 36, 9.2),
	"mace": Rect2(-5.4, -5, 24, 10), "dagger": Rect2(-3.8, -2.4, 14.3, 4.8), "katana": Rect2(-7.3, -3.3, 25.3, 4.6),
	"rapier": Rect2(-6.4, -3.6, 25.4, 7.2), "scythe": Rect2(-12, -12, 30, 14.6), "halberd": Rect2(-12, -5, 34, 13.4),
	"axe": Rect2(-6, -12.4, 23, 16.6),
}

static var _ci: CanvasItem
static var _c := Vector2.ZERO
static var _k := 1.0
## Opacity of everything drawn (faint outlines of empty slots use less).
static var _fade := 1.0


## Draws the picture of item (or service) [id] inside [r]; [col] is its
## colour, [fade] the opacity of the whole picture.
static func draw(ci: CanvasItem, id: String, r: Rect2, col: Color, fade: float = 1.0) -> void:
	_ci = ci
	_c = r.get_center()
	_k = minf(r.size.x, r.size.y) * 0.42
	_fade = fade
	var d: Dictionary = Items.def(id)
	if fade >= 1.0:
		ci.draw_circle(_c, _k * 0.95, Color(col.r, col.g, col.b, 0.07))
		ci.draw_circle(_c, _k * 0.6, Color(col.r, col.g, col.b, 0.06))
	if d.get("slot", "") == "weapon":
		_weapon(d.get("kind", "sword"), col)
		return
	match id:
		"ink_knife":
			_i_ink_knife(col)
		"bone_boomerang":
			_i_bone_boomerang(col)
		"thorn_chakram":
			_i_thorn_chakram(col)
		"bile_flask":
			_i_bile_flask(col)
		"grave_javelin":
			_i_grave_javelin(col)
		"heart_glyph":
			_i_heart_glyph(col)
		"phantom_step":
			_i_phantom_step(col)
		"feather":
			_i_feather(col)
		"lodestone":
			_i_lodestone(col)
		"quickhand":
			_i_quickhand(col)
		"fang":
			_i_fang(col)
		"thorn_ring":
			_i_thorn_ring(col)
		"lucky_coin":
			_i_lucky_coin(col)
		"inkwell":
			_i_inkwell(col)
		"stone_skin":
			_i_stone_skin(col)
		"raven_quill":
			_i_raven_quill(col)
		"iron_shroud":
			_i_iron_shroud(col)
		"blood_rosary":
			_i_blood_rosary(col)
		"black_candle":
			_i_black_candle(col)
		"funeral_bell":
			_i_funeral_bell(col)
		"penitent_chain":
			_i_penitent_chain(col)
		"saints_finger":
			_i_saints_finger(col)
		"wraith_lantern":
			_i_wraith_lantern(col)
		"ember_heart":
			_i_ember_heart(col)
		"moon_lens":
			_i_moon_lens(col)
		"root_crown":
			_i_root_crown(col)
		"gallows_knot":
			_i_gallows_knot(col)
		"tide_pearl":
			_i_tide_pearl(col)
		"frost_crown":
			_i_frost_crown(col)
		"pilgrim_hood":
			_i_pilgrim_hood(col)
		"iron_sallet":
			_i_iron_sallet(col)
		"plague_mask":
			_i_plague_mask(col)
		"gambeson":
			_i_gambeson(col)
		"chain_hauberk":
			_i_chain_hauberk(col)
		"cathedral_plate":
			_i_cathedral_plate(col)
		"wanderer_boots":
			_i_wanderer_boots(col)
		"iron_greaves":
			_i_iron_greaves(col)
		"thorned_sabatons":
			_i_thorned_sabatons(col)
		"mend":
			_i_mend(col)
		"vigor":
			_i_vigor(col)
		"whet":
			_i_whet(col)
		"haste":
			_i_haste(col)
		"forget":
			_i_forget(col)
		_:
			_gem(col)


## A weapon laid across the frame from the lower left to the upper right.
static func _weapon(kind: String, col: Color) -> void:
	var e: Rect2 = EXTENT.get(kind, EXTENT.sword)
	var a := -PI * 0.25
	var s: float = _k * 2.7 / maxf(e.size.x, e.size.y * 1.6)
	if kind == "dagger":
		# a pair of fangs, crossed
		s *= 0.8
		for side in [-1.0, 1.0]:
			var aa: float = a if side > 0 else -PI * 0.75
			var at: Vector2 = _c - Vector2(e.get_center().x, 0).rotated(aa) * s + Vector2(0, _k * 0.15)
			WeaponArt.draw(_ci, kind, at, aa, 1.0, s, col if side > 0 else col.darkened(0.2), 1.0)
		return
	var at := _c - e.get_center().rotated(a) * s
	WeaponArt.draw(_ci, kind, at, a, 1.0, s, col, 1.0)


# ---------------------------------------------------------------- drawing helpers

static func pt(x: float, y: float) -> Vector2:
	return _c + Vector2(x, y) * _k


static func pts(list: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, list.size(), 2):
		out.append(pt(list[i], list[i + 1]))
	return out


static func rimw() -> float:
	return maxf(1.0, _k * 0.07)


static func _f(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * _fade)


## A filled shape with a dark rim; [list] holds x, y pairs.
static func shape(list: Array, fill: Color) -> void:
	var p := pts(list)
	_ci.draw_colored_polygon(p, _f(fill))
	p.append(p[0])
	_ci.draw_polyline(p, _f(RIM), rimw(), true)


static func disc(x: float, y: float, rad: float, fill: Color, rim: bool = true) -> void:
	if rim:
		_ci.draw_circle(pt(x, y), rad * _k + rimw() * 0.6, _f(RIM))
	_ci.draw_circle(pt(x, y), rad * _k, _f(fill))


static func ring(x: float, y: float, rad: float, col: Color, w: float) -> void:
	_ci.draw_arc(pt(x, y), rad * _k, 0.0, TAU, 32, _f(RIM), w * _k + rimw(), true)
	_ci.draw_arc(pt(x, y), rad * _k, 0.0, TAU, 32, _f(col), w * _k, true)


static func seg(x0: float, y0: float, x1: float, y1: float, col: Color, w: float, rim: bool = true) -> void:
	if rim:
		_ci.draw_line(pt(x0, y0), pt(x1, y1), _f(RIM), w * _k + rimw())
	_ci.draw_line(pt(x0, y0), pt(x1, y1), _f(col), w * _k)


static func curve(list: Array, col: Color, w: float, rim: bool = true) -> void:
	var p := pts(list)
	if rim:
		_ci.draw_polyline(p, _f(RIM), w * _k + rimw(), true)
	_ci.draw_polyline(p, _f(col), w * _k, true)


## A heart of [rad] centred at x, y.
static func heart(x: float, y: float, rad: float, fill: Color) -> void:
	var list: Array = []
	for i in 28:
		var a := TAU * i / 28.0
		var hx := 16.0 * pow(sin(a), 3)
		var hy := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		list.append(x + hx / 17.0 * rad)
		list.append(y + hy / 17.0 * rad)
	shape(list, fill)


## Any item without a picture of its own: a cut gem.
static func _gem(col: Color) -> void:
	shape([0, -0.8, 0.6, -0.2, 0, 0.85, -0.6, -0.2], col)
	shape([0, -0.8, 0.25, -0.2, 0, 0.85, -0.25, -0.2], col.lightened(0.25))


# ---------------------------------------------------------------- thrown weapons


static func _i_ink_knife(col: Color) -> void:
	shape([-0.12, 0.02, 0.8, -0.8, 0.02, 0.12], col.lerp(IRON_HI, 0.3))
	seg(-0.05, 0.05, 0.62, -0.62, col.lightened(0.5), 0.05, false)
	seg(-0.32, 0.12, -0.12, 0.32, IRON_HI, 0.12)
	seg(-0.2, 0.2, -0.62, 0.62, CLOTH, 0.16)
	ring(-0.72, 0.72, 0.13, IRON_HI, 0.07)
	disc(0.45, 0.3, 0.1, Color(0.2, 0.2, 0.5), false)
	disc(0.5, 0.48, 0.06, Color(0.2, 0.2, 0.5), false)


static func _i_bone_boomerang(col: Color) -> void:
	shape([-0.85, 0.35, -0.12, -0.62, 0.1, -0.62, 0.85, 0.35, 0.62, 0.55, 0.0, -0.25, -0.62, 0.55], col)
	for x in [-0.45, 0.45]:
		seg(x - 0.06, -0.05, x + 0.06, 0.05, Color(0.4, 0.34, 0.28), 0.05, false)
	disc(0.0, -0.5, 0.09, BLOOD)


static func _i_thorn_chakram(col: Color) -> void:
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		var tip := d * 0.92
		var b1 := d * 0.5 + n * 0.16
		var b2 := d * 0.55 - n * 0.12
		shape([b1.x, b1.y, tip.x + n.x * 0.12, tip.y + n.y * 0.12, b2.x, b2.y], col.darkened(0.15))
	ring(0, 0, 0.5, col, 0.16)
	ring(0, 0, 0.3, IRON, 0.07)
	disc(0, 0, 0.08, GOLD)


static func _i_bile_flask(col: Color) -> void:
	disc(0, 0.25, 0.55, Color(0.18, 0.2, 0.16))
	disc(0, 0.32, 0.45, col.darkened(0.15), false)
	shape([-0.16, -0.25, -0.16, -0.62, 0.16, -0.62, 0.16, -0.25], Color(0.22, 0.24, 0.2))
	shape([-0.2, -0.62, -0.2, -0.85, 0.2, -0.85, 0.2, -0.62], WOOD)
	disc(-0.2, 0.08, 0.12, col.lightened(0.4), false)
	disc(0.15, 0.45, 0.07, col.lightened(0.3), false)
	disc(0.28, 0.2, 0.05, col.lightened(0.3), false)
	seg(-0.2, -0.5, 0.2, -0.5, GOLD, 0.06, false)


static func _i_grave_javelin(col: Color) -> void:
	seg(-0.88, 0.88, 0.5, -0.5, WOOD, 0.1)
	shape([0.35, -0.35, 0.68, -0.48, 0.95, -0.95, 0.48, -0.68], col.lerp(IRON_HI, 0.4))
	for q in [-0.55, 0.0, 0.3]:
		seg(q - 0.08, -q - 0.08, q + 0.08, -q + 0.08, IRON_HI, 0.06, false)
	shape([-0.88, 0.88, -0.98, 0.62, -0.72, 0.72], BLOOD)
	shape([-0.88, 0.88, -0.62, 0.98, -0.72, 0.72], BLOOD)

# ---------------------------------------------------------------- charms


static func _i_heart_glyph(col: Color) -> void:
	heart(0, 0.05, 0.8, col.darkened(0.2))
	heart(0, 0.0, 0.5, col)
	disc(-0.25, -0.25, 0.1, col.lightened(0.5), false)


static func _i_phantom_step(col: Color) -> void:
	for i in 3:
		var x := -0.55 + i * 0.4
		var c := Color(col.r, col.g, col.b, 0.35 + 0.3 * i)
		curve([x - 0.2, -0.55, x + 0.2, 0.0, x - 0.2, 0.55], c, 0.14, i == 2)
	disc(0.6, 0.0, 0.08, col.lightened(0.5), false)


static func _i_feather(col: Color) -> void:
	var spine: Array = []
	var vane: Array = []
	for i in 9:
		var q := i / 8.0
		var x := lerpf(-0.75, 0.7, q)
		var y := lerpf(0.75, -0.75, q) + sin(q * PI) * 0.18
		spine.append_array([x, y])
	for i in 9:
		var q := i / 8.0
		var w := sin(q * PI) * 0.32 + 0.02
		vane.append_array([lerpf(-0.6, 0.7, q) - w * 0.7, lerpf(0.6, -0.75, q) - w * 0.7 + sin(q * PI) * 0.18])
	for i in range(8, -1, -1):
		var q := i / 8.0
		var w := sin(q * PI) * 0.32 + 0.02
		vane.append_array([lerpf(-0.6, 0.7, q) + w * 0.7, lerpf(0.6, -0.75, q) + w * 0.7 + sin(q * PI) * 0.18])
	shape(vane, col.darkened(0.1))
	curve(spine, BONE, 0.06, false)


static func _i_lodestone(col: Color) -> void:
	for side in [-1.0, 1.0]:
		curve([side * 0.55, -0.7, side * 0.85, 0.0, side * 0.55, 0.7], GOLD.darkened(0.2), 0.05, false)
	shape([0, -0.72, 0.5, -0.15, 0.32, 0.6, -0.32, 0.6, -0.5, -0.15], col.darkened(0.25))
	shape([0, -0.72, 0.18, -0.15, 0.0, 0.6, -0.18, -0.15], col)
	seg(-0.5, -0.15, 0.5, -0.15, col.lightened(0.3), 0.04, false)


static func _i_quickhand(col: Color) -> void:
	shape([-0.5, -0.8, 0.5, -0.8, 0.08, 0.0, 0.5, 0.8, -0.5, 0.8, -0.08, 0.0], Color(0.75, 0.82, 0.85, 0.35))
	shape([-0.32, 0.55, 0.32, 0.55, 0.42, 0.75, -0.42, 0.75], col)
	shape([-0.12, -0.55, 0.12, -0.55, 0.0, -0.35], col)
	seg(0, -0.3, 0, 0.5, col, 0.04, false)
	for y in [-0.85, 0.85]:
		seg(-0.65, y, 0.65, y, GOLD, 0.12)


static func _i_fang(col: Color) -> void:
	curve([-0.75, -0.75, -0.3, -0.45, 0.3, -0.45, 0.75, -0.75], CLOTH.lightened(0.2), 0.06, false)
	shape([-0.32, -0.5, 0.32, -0.5, 0.18, 0.1, 0.0, 0.82, -0.1, 0.15], BONE)
	shape([0.0, 0.82, -0.08, 0.45, 0.1, 0.45], col)
	seg(0.05, -0.35, 0.02, 0.2, Color(1, 1, 1, 0.5), 0.05, false)


static func _i_thorn_ring(col: Color) -> void:
	ring(0, 0, 0.5, col.darkened(0.3), 0.14)
	for i in 9:
		var d := Vector2.from_angle(TAU * i / 9.0 + 0.2)
		var n := d.orthogonal()
		var a := d * 0.55 + n * 0.1
		var b := d * 0.9 + n * 0.18
		var c := d * 0.58 - n * 0.06
		shape([a.x, a.y, b.x, b.y, c.x, c.y], col)


static func _i_lucky_coin(col: Color) -> void:
	disc(0, 0, 0.72, col.darkened(0.3))
	disc(0, 0, 0.6, col, false)
	ring(0, 0, 0.48, col.darkened(0.25), 0.04)
	seg(0, -0.32, 0, 0.32, col.darkened(0.45), 0.09, false)
	seg(-0.2, -0.12, 0.2, -0.12, col.darkened(0.45), 0.09, false)
	disc(-0.3, -0.35, 0.08, Color(1, 1, 0.9, 0.7), false)


static func _i_inkwell(col: Color) -> void:
	shape([-0.55, 0.1, -0.42, -0.12, 0.42, -0.12, 0.55, 0.1, 0.55, 0.75, -0.55, 0.75], Color(0.12, 0.12, 0.2))
	shape([-0.2, -0.12, -0.2, -0.32, 0.2, -0.32, 0.2, -0.12], IRON)
	shape([-0.45, 0.25, 0.45, 0.25, 0.45, 0.62, -0.45, 0.62], col.darkened(0.35))
	curve([0.05, -0.28, 0.4, -0.7, 0.8, -0.9], BONE, 0.05)
	shape([0.4, -0.7, 0.62, -0.95, 0.85, -0.85, 0.6, -0.62], BONE.darkened(0.15))


static func _i_stone_skin(col: Color) -> void:
	shape([-0.62, -0.7, 0.62, -0.7, 0.68, 0.15, 0.0, 0.85, -0.68, 0.15], col.darkened(0.15))
	curve([-0.3, -0.7, -0.1, -0.2, -0.35, 0.2], col.darkened(0.55), 0.05, false)
	curve([0.35, -0.4, 0.15, 0.05, 0.3, 0.45], col.darkened(0.55), 0.05, false)
	seg(-0.55, -0.55, 0.55, -0.55, col.lightened(0.2), 0.05, false)


static func _i_raven_quill(col: Color) -> void:
	_i_feather(Color(0.14, 0.15, 0.22))
	curve([-0.3, 0.2, 0.2, -0.25], col, 0.05, false)
	shape([-0.75, 0.75, -0.92, 0.95, -0.62, 0.85], GOLD)


static func _i_iron_shroud(col: Color) -> void:
	shape([0, -0.85, 0.5, -0.5, 0.62, 0.3, 0.75, 0.85, -0.75, 0.85, -0.62, 0.3, -0.5, -0.5], col.darkened(0.15))
	shape([0, -0.55, 0.28, -0.3, 0.25, 0.15, -0.25, 0.15, -0.28, -0.3], Color(0.03, 0.02, 0.04))
	disc(-0.1, -0.1, 0.05, Color(0.8, 0.85, 1.0), false)
	disc(0.1, -0.1, 0.05, Color(0.8, 0.85, 1.0), false)
	for x in [-0.4, 0.0, 0.4]:
		seg(x, 0.35, x * 1.15, 0.8, col.darkened(0.4), 0.04, false)


static func _i_blood_rosary(col: Color) -> void:
	for i in 12:
		var a := TAU * i / 12.0 - PI * 0.5
		disc(cos(a) * 0.55, sin(a) * 0.45 - 0.2, 0.09, col.darkened(0.1))
	seg(0, 0.25, 0, 0.55, GOLD, 0.05, false)
	seg(0, 0.5, 0, 0.95, GOLD, 0.1)
	seg(-0.16, 0.65, 0.16, 0.65, GOLD, 0.1)


static func _i_black_candle(col: Color) -> void:
	shape([-0.3, -0.35, 0.3, -0.35, 0.3, 0.6, -0.3, 0.6], col.darkened(0.2))
	shape([-0.3, -0.35, -0.15, -0.35, -0.15, 0.05, -0.24, 0.12, -0.3, 0.02], col.lightened(0.15))
	shape([-0.55, 0.6, 0.55, 0.6, 0.4, 0.82, -0.4, 0.82], IRON)
	seg(0, -0.35, 0, -0.5, Color(0.1, 0.1, 0.1), 0.04, false)
	shape([0, -0.95, 0.14, -0.62, 0, -0.48, -0.14, -0.62], Color(1.0, 0.7, 0.3))
	shape([0, -0.8, 0.06, -0.62, 0, -0.54, -0.06, -0.62], Color(1.0, 0.95, 0.7))


static func _i_funeral_bell(col: Color) -> void:
	shape([-0.12, -0.75, 0.12, -0.75, 0.38, -0.5, 0.45, 0.2, 0.68, 0.5, -0.68, 0.5, -0.45, 0.2, -0.38, -0.5], col.darkened(0.1))
	seg(-0.6, 0.42, 0.6, 0.42, col.darkened(0.4), 0.05, false)
	seg(-0.3, -0.35, -0.32, 0.25, col.lightened(0.35), 0.05, false)
	ring(0, -0.85, 0.12, IRON_HI, 0.06)
	disc(0, 0.68, 0.14, IRON)


static func _i_penitent_chain(col: Color) -> void:
	# oval links hanging in a curve, every other one seen edge-on
	for i in 6:
		var q := i / 5.0
		var x := lerpf(-0.75, 0.6, q)
		var y := -0.7 + sin(q * PI) * 0.55 + q * 0.4
		if i % 2 == 0:
			_ci.draw_set_transform(pt(x, y), 0.6 - q, Vector2(1.0, 0.62))
			_ci.draw_arc(Vector2.ZERO, 0.17 * _k, 0.0, TAU, 20, _f(RIM), 0.08 * _k + rimw(), true)
			_ci.draw_arc(Vector2.ZERO, 0.17 * _k, 0.0, TAU, 20, _f(col), 0.08 * _k, true)
			_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			seg(x - 0.12, y - 0.06, x + 0.12, y + 0.06, col.lightened(0.15), 0.08)
	seg(0.68, 0.25, 0.68, 0.95, GOLD, 0.09)
	seg(0.5, 0.48, 0.86, 0.48, GOLD, 0.09)


static func _i_saints_finger(col: Color) -> void:
	shape([-0.4, -0.75, 0.4, -0.75, 0.4, 0.55, -0.4, 0.55], Color(0.55, 0.65, 0.7, 0.25))
	shape([-0.55, 0.55, 0.55, 0.55, 0.45, 0.85, -0.45, 0.85], GOLD)
	shape([-0.5, -0.95, 0.5, -0.95, 0.4, -0.75, -0.4, -0.75], GOLD)
	seg(0, 0.4, 0, -0.5, col, 0.16)
	for y in [-0.15, 0.15]:
		seg(-0.08, y, 0.08, y, col.darkened(0.35), 0.03, false)


static func _i_wraith_lantern(col: Color) -> void:
	ring(0, -0.82, 0.12, IRON_HI, 0.05)
	shape([-0.45, -0.6, 0.45, -0.6, 0.3, -0.72, -0.3, -0.72], IRON)
	shape([-0.4, -0.6, 0.4, -0.6, 0.45, 0.55, -0.45, 0.55], Color(col.r, col.g, col.b, 0.22))
	shape([0, -0.3, 0.2, 0.15, 0, 0.35, -0.2, 0.15], col)
	disc(0, 0.12, 0.08, Color(1, 1, 1, 0.8), false)
	for x in [-0.42, 0.0, 0.42]:
		seg(x, -0.6, x * 1.1, 0.55, IRON, 0.05)
	shape([-0.55, 0.55, 0.55, 0.55, 0.45, 0.78, -0.45, 0.78], IRON)


static func _i_ember_heart(col: Color) -> void:
	heart(0, 0.05, 0.78, Color(0.25, 0.05, 0.03))
	curve([-0.35, -0.2, -0.05, 0.1, -0.2, 0.4, 0.05, 0.6], col, 0.07, false)
	curve([0.35, -0.3, 0.1, 0.0, 0.3, 0.3], col.lightened(0.3), 0.06, false)
	shape([-0.1, -0.85, 0.05, -0.55, -0.15, -0.5], col)
	shape([0.25, -0.95, 0.35, -0.6, 0.15, -0.62], col.lightened(0.2))


static func _i_moon_lens(col: Color) -> void:
	ring(0, 0, 0.7, GOLD, 0.1)
	disc(0, 0, 0.6, Color(0.05, 0.06, 0.1), false)
	disc(-0.05, 0, 0.42, col, false)
	disc(0.15, -0.08, 0.38, Color(0.05, 0.06, 0.1), false)
	seg(0.55, 0.55, 0.85, 0.85, GOLD, 0.12)


static func _i_root_crown(col: Color) -> void:
	shape([-0.75, 0.45, -0.7, -0.45, -0.38, 0.0, -0.18, -0.7, 0, -0.1, 0.18, -0.7, 0.38, 0.0, 0.7, -0.45, 0.75, 0.45], WOOD)
	shape([-0.75, 0.25, 0.75, 0.25, 0.75, 0.55, -0.75, 0.55], WOOD.darkened(0.2))
	for x in [-0.7, -0.18, 0.18, 0.7]:
		disc(x, -0.55 if absf(x) < 0.5 else -0.38, 0.1, col)
	curve([-0.6, 0.55, -0.7, 0.8, -0.5, 0.95], WOOD, 0.05, false)
	curve([0.6, 0.55, 0.72, 0.85], WOOD, 0.05, false)


static func _i_gallows_knot(col: Color) -> void:
	seg(0, -0.95, 0, -0.35, col, 0.1)
	for i in 4:
		seg(-0.15, -0.35 + i * 0.12, 0.15, -0.3 + i * 0.12, col.darkened(0.15), 0.1)
	ring(0, 0.4, 0.38, col, 0.1)
	curve([0.1, 0.1, 0.4, 0.05, 0.55, 0.3], col.darkened(0.25), 0.05, false)


static func _i_tide_pearl(col: Color) -> void:
	var shell: Array = [0, 0.75]
	for i in 9:
		var a := PI + PI * i / 8.0
		shell.append_array([cos(a) * 0.8, 0.2 + sin(a) * 0.75])
	shape(shell, Color(0.55, 0.5, 0.6))
	for i in 5:
		var a := PI + PI * (i + 1) / 6.0
		seg(0, 0.7, cos(a) * 0.72, 0.2 + sin(a) * 0.68, Color(0.35, 0.3, 0.42), 0.04, false)
	disc(0, 0.15, 0.28, col)
	disc(-0.08, 0.06, 0.08, Color(1, 1, 1, 0.8), false)


static func _i_frost_crown(col: Color) -> void:
	shape([-0.75, 0.5, -0.75, -0.2, -0.45, 0.1, -0.25, -0.75, 0, 0.0, 0.25, -0.75, 0.45, 0.1, 0.75, -0.2, 0.75, 0.5], col.darkened(0.2))
	shape([-0.25, -0.75, -0.12, -0.2, -0.32, -0.2], col.lightened(0.5))
	shape([0.25, -0.75, 0.32, -0.2, 0.12, -0.2], col.lightened(0.5))
	seg(-0.75, 0.35, 0.75, 0.35, col.lightened(0.3), 0.06, false)
	disc(0, 0.15, 0.1, Color(0.6, 0.85, 1.0))

# ---------------------------------------------------------------- armour


static func _i_pilgrim_hood(col: Color) -> void:
	var hood: Array = [0.0, -0.9]
	for i in 7:
		var a := -PI * 0.5 + PI * 0.5 * (i + 1) / 7.0
		hood.append_array([cos(a) * 0.6, -0.25 + sin(a) * 0.65])
	hood.append_array([0.85, 0.85, -0.85, 0.85])
	for i in 7:
		var a := PI + PI * 0.5 * i / 7.0
		hood.append_array([cos(a) * 0.6, -0.25 + sin(a) * 0.65])
	shape(hood, col.darkened(0.15))
	shape([0, -0.55, 0.3, -0.35, 0.34, 0.1, 0.0, 0.32, -0.34, 0.1, -0.3, -0.35], Color(0.04, 0.03, 0.04))
	disc(-0.12, -0.08, 0.04, Color(0.9, 0.75, 0.5), false)
	disc(0.12, -0.08, 0.04, Color(0.9, 0.75, 0.5), false)
	seg(-0.65, 0.55, 0.65, 0.55, col.darkened(0.45), 0.05, false)
	disc(0, 0.68, 0.08, GOLD)


static func _i_iron_sallet(col: Color) -> void:
	shape([-0.55, 0.3, -0.62, -0.25, -0.3, -0.75, 0.3, -0.78, 0.62, -0.35, 0.65, 0.25, 0.9, 0.6, 0.3, 0.45, -0.55, 0.45], col)
	shape([-0.55, -0.05, 0.62, -0.05, 0.62, 0.08, -0.55, 0.08], Color(0.04, 0.03, 0.05))
	curve([0.0, -0.78, 0.05, -0.1], col.lightened(0.3), 0.05, false)
	curve([-0.45, -0.45, -0.1, -0.68], col.lightened(0.45), 0.05, false)
	for x in [-0.4, 0.4]:
		disc(x, 0.3, 0.05, GOLD, false)


static func _i_plague_mask(col: Color) -> void:
	shape([-0.5, -0.7, 0.3, -0.75, 0.55, -0.3, 0.95, 0.55, 0.3, 0.3, -0.45, 0.45, -0.62, -0.1], col)
	curve([0.3, -0.05, 0.85, 0.5], col.darkened(0.4), 0.04, false)
	for x in [-0.32, 0.12]:
		ring(x, -0.3, 0.16, IRON, 0.06)
		disc(x, -0.3, 0.13, Color(0.75, 0.08, 0.1), false)
		disc(x - 0.04, -0.34, 0.04, Color(1, 0.7, 0.6), false)
	seg(-0.6, -0.55, -0.85, -0.75, CLOTH.lightened(0.2), 0.06, false)


static func _torso(col: Color) -> void:
	shape([-0.35, -0.8, 0.35, -0.8, 0.8, -0.55, 0.85, 0.05, 0.55, 0.0, 0.5, 0.8, -0.5, 0.8, -0.55, 0.0, -0.85, 0.05,
		-0.8, -0.55], col)
	shape([-0.2, -0.8, 0.2, -0.8, 0, -0.55], Color(0.05, 0.03, 0.04))


static func _i_gambeson(col: Color) -> void:
	_torso(col)
	for y in [-0.35, 0.0, 0.35]:
		seg(-0.48, y, 0.48, y, col.darkened(0.35), 0.04, false)
	for x in [-0.25, 0.0, 0.25]:
		seg(x, -0.55, x, 0.75, col.darkened(0.35), 0.03, false)


static func _i_chain_hauberk(col: Color) -> void:
	_torso(col.darkened(0.35))
	for row in 6:
		for i in 5:
			var x := -0.4 + i * 0.2 + (0.1 if row % 2 == 1 else 0.0)
			var y := -0.45 + row * 0.22
			if absf(x) < 0.5:
				ring(x, y, 0.07, col, 0.03)
	seg(-0.5, 0.75, 0.5, 0.75, col.lightened(0.2), 0.06, false)


static func _i_cathedral_plate(col: Color) -> void:
	_torso(col.darkened(0.1))
	shape([0, -0.55, 0.42, -0.3, 0.38, 0.45, 0, 0.7, -0.38, 0.45, -0.42, -0.3], col)
	seg(0, -0.5, 0, 0.62, col.lightened(0.35), 0.04, false)
	seg(0, -0.25, 0, 0.3, GOLD, 0.08, false)
	seg(-0.15, -0.08, 0.15, -0.08, GOLD, 0.08, false)
	for x in [-0.72, 0.72]:
		disc(x, -0.45, 0.08, GOLD)


static func _i_wanderer_boots(col: Color) -> void:
	shape([-0.45, -0.8, 0.15, -0.8, 0.15, 0.25, 0.8, 0.45, 0.8, 0.75, -0.45, 0.75], col)
	shape([-0.5, -0.85, 0.2, -0.85, 0.2, -0.6, -0.5, -0.6], col.darkened(0.3))
	seg(-0.45, 0.62, 0.8, 0.62, col.darkened(0.5), 0.06, false)
	for y in [-0.35, -0.1, 0.15]:
		seg(-0.12, y, 0.12, y + 0.06, BONE, 0.04, false)


static func _i_iron_greaves(col: Color) -> void:
	for x in [-0.32, 0.32]:
		shape([x - 0.25, -0.85, x + 0.25, -0.85, x + 0.2, 0.55, x + 0.3, 0.85, x - 0.3, 0.85, x - 0.2, 0.55], col)
		disc(x, -0.25, 0.14, col.lightened(0.2))
		seg(x, -0.75, x, 0.5, col.lightened(0.35), 0.03, false)


static func _i_thorned_sabatons(col: Color) -> void:
	shape([-0.45, -0.75, 0.15, -0.75, 0.15, 0.2, 0.85, 0.42, 0.85, 0.75, -0.45, 0.75], col)
	for y in [-0.45, -0.1, 0.25]:
		seg(-0.45, y, 0.15, y, col.darkened(0.35), 0.04, false)
	for q in [[-0.45, -0.6], [-0.45, -0.1], [0.4, 0.3], [0.7, 0.38]]:
		shape([q[0] - 0.08, q[1], q[0], q[1] - 0.28, q[0] + 0.08, q[1]], BONE)

# ---------------------------------------------------------------- merchant services


static func _i_mend(col: Color) -> void:
	shape([-0.2, -0.75, 0.2, -0.75, 0.2, -0.2, 0.75, -0.2, 0.75, 0.2, 0.2, 0.2, 0.2, 0.75, -0.2, 0.75, -0.2, 0.2, -0.75, 0.2,
		-0.75, -0.2, -0.2, -0.2], col)


static func _i_vigor(col: Color) -> void:
	heart(0, 0.05, 0.8, col.darkened(0.2))
	seg(0, -0.25, 0, 0.3, Color(1, 0.9, 0.85), 0.12, false)
	seg(-0.28, 0.02, 0.28, 0.02, Color(1, 0.9, 0.85), 0.12, false)


static func _i_whet(col: Color) -> void:
	shape([-0.85, 0.45, 0.6, 0.45, 0.75, 0.75, -0.7, 0.75], Color(0.4, 0.38, 0.36))
	shape([-0.5, 0.25, 0.75, -0.75, 0.85, -0.62, -0.38, 0.38], col)
	seg(-0.5, 0.25, -0.75, 0.45, CLOTH, 0.12)
	for i in 3:
		disc(0.2 + i * 0.15, 0.1 - i * 0.12, 0.04, Color(1.0, 0.85, 0.4), false)


static func _i_haste(col: Color) -> void:
	_i_wanderer_boots(Color(0.45, 0.36, 0.3))
	for i in 3:
		seg(-0.95, -0.3 + i * 0.3, -0.6, -0.3 + i * 0.3, col, 0.06, false)
	shape([-0.45, -0.6, -0.95, -0.95, -0.55, -0.45], col)


static func _i_forget(col: Color) -> void:
	disc(0, -0.15, 0.6, BONE)
	shape([-0.32, 0.3, 0.32, 0.3, 0.25, 0.75, -0.25, 0.75], BONE)
	for x in [-0.25, 0.25]:
		disc(x, -0.15, 0.16, Color(0.06, 0.03, 0.05), false)
	shape([0, 0.12, 0.08, 0.3, -0.08, 0.3], Color(0.06, 0.03, 0.05))
	for x in [-0.12, 0.0, 0.12]:
		seg(x, 0.45, x, 0.72, Color(0.06, 0.03, 0.05), 0.03, false)
	disc(0.62, -0.7, 0.16, col)
