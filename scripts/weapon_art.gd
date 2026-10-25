## The weapon in the hero's hand: its pixel sprite (gear_sprites.gd WEAPONS)
## in a fist at the end of a pixel arm that swings with the attacks.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")
const G := preload("res://scripts/gear_sprites.gd")

## Resting angle of each weapon kind (radians, facing right; +y is down).
const REST := {"sword": 0.35, "great": -1.35, "spear": -1.35, "mace": -1.2, "dagger": 0.5, "katana": 0.4, "rapier": 0.35,
	"scythe": -1.75, "halberd": -1.4, "axe": -1.2}
## Kinds swung from high over the shoulder and kept there in the air.
const HEAVY := ["great", "mace", "scythe", "halberd", "axe"]


## How long the hero's arm is from shoulder to fist, in world units.
const ARM := 6.0
## How far the resting fist hangs above the feet, in world units: a blade
## longer than that at its resting angle is held upright instead.
const HAND_H := 11.0
const OUTLINE := Color(0.03, 0.02, 0.03)


## The angle the weapon points at, how far it is thrust out and the angle of
## the arm holding it, from the hero's state: swings carry the arm round with
## the blade, otherwise the arm hangs and the weapon rests by kind.
static func pose(p: Dictionary, kind: String) -> Array:
	var reach := 0.0
	var a := rest_angle(p.weapon, kind)
	# the arm hangs, a little forward; heavy weapons are held upright before the body
	var arm := 1.35 if kind not in HEAVY else 0.55
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
		arm = clampf(a, -2.2, 1.6) if p.atk_kind != "down" else PI * 0.5
	elif p.get("guard", false):
		# held upright in front of the body
		a = -1.3
		arm = 0.2
		reach = 2.0
	elif p.slam:
		a = PI * 0.5
		arm = PI * 0.5
	elif p.dash_t > 0.0:
		a = 2.9
		arm = 2.3
	elif p.throw_t > 0.15:
		a = -2.2
		arm = -0.2
	elif p.hurt_t > 0.0:
		a = -2.0
		arm = 2.4
	elif p.sliding:
		a = -1.6
		arm = 1.9
	elif not p.on_floor and kind not in HEAVY:
		a -= 0.35
		arm -= 0.5
	return [a, reach, arm]


## The angle weapon [id] of [kind] rests at: by kind, or upright before the
## body when the blade would reach the ground. It doesn't sway: the weapon
## turns in steps of 11 degrees, so a small sway would flip it up and down.
static func rest_angle(id: String, kind: String) -> float:
	var a: float = REST.get(kind, 1.05)
	if length(id) * sin(a) > HAND_H:
		return -1.2
	return a


## The hero's sword arm and the weapon in its fist, in pixels, on [ci]:
## [anchor] is the screen point of the hero's feet as its sprite is placed,
## [s] screen pixels per world unit, [shoulder] where the arm hangs from in the
## frame drawn (Hero.shoulder), [f] the way the hero faces. [rest] holds the
## weapon at rest whatever the hero is doing (the inventory).
static func draw_held(ci: CanvasItem, anchor: Vector2, s: float, p: Dictionary, shoulder: Vector2i, f: int, armour: Color,
		tint: Color, rest: bool = false) -> void:
	var d: Dictionary = Items.def(p.weapon)
	var kind: String = d.get("kind", "sword")
	# in the inventory's niche every weapon is held upright, so it stays under the arch
	var po := pose(p, kind) if not rest else [-1.2, 0.0, 0.55]
	var a: float = po[0]
	var b: float = po[2]
	var stretch: float = minf(po[1], 3.0)
	var sh := Vector2(shoulder.x * f, shoulder.y)
	var hand := (sh + Vector2(cos(b) * f, sin(b)) * (ARM + stretch)).round()
	var grip: Vector2 = hand + (Vector2(cos(a) * f, sin(a)) * (po[1] - stretch)).round()
	_limb(ci, anchor, s, sh, hand, OUTLINE * tint, 4.0)
	_limb(ci, anchor, s, sh, hand, armour * tint, 2.0)
	var w: Array = SpriteCache.weapon(p.weapon, a if f > 0 else PI - a, f < 0)
	var tex: Texture2D = w[0]
	var pv: Vector2i = w[1]
	ci.draw_texture_rect(tex, Rect2(anchor + (grip - Vector2(pv)) * s, Vector2(tex.get_size()) * s), false, tint)
	# the fist closes over the grip
	_square(ci, anchor, s, grip, 2.0, Color(0.19, 0.18, 0.23) * tint)


## How far weapon [id] reaches from the hand to its point, in texels.
static func length(id: String) -> float:
	var d: Dictionary = G.WEAPONS.get(id, G.WEAPONS.rusty_blade)
	return float((d.rows[0] as String).length() - d.pivot.x)


## A line of squares [n] world units across from [a] to [b] (world units from
## the anchor), on the pixel grid.
static func _limb(ci: CanvasItem, anchor: Vector2, s: float, a: Vector2, b: Vector2, col: Color, n: float) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for k in steps + 1:
		_square(ci, anchor, s, a.lerp(b, float(k) / steps).round(), n, col)


static func _square(ci: CanvasItem, anchor: Vector2, s: float, c: Vector2, n: float, col: Color) -> void:
	col.a = 1.0
	ci.draw_rect(Rect2(anchor + (c - Vector2(n, n) * 0.5) * s, Vector2(n, n) * s), col)
