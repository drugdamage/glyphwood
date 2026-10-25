## Item pictures for the HUD, the inventory and the shop, in pixels like the
## rest of the game: a weapon is its own sprite from the hand (the head end of
## a long one) pointing up and to the right, a helmet or body armour is the
## piece laid over the hero, anything else a picture from gear_sprites.gd ICONS.
extends RefCounted

const G := preload("res://scripts/gear_sprites.gd")
const S := preload("res://scripts/sprites.gd")
const Items := preload("res://scripts/items.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")
const Hero := preload("res://scripts/hero.gd")
## About how many pixels across a weapon's picture is: blown up by a whole
## number to fill its box.
const WEAPON_PX := 24.0


## Draws the picture of item [id] in the middle of [r], dyed [col] where the
## item takes a colour, at [fade] opacity.
static func draw(ci: CanvasItem, id: String, r: Rect2, col: Color, fade: float = 1.0) -> void:
	var box := floorf(minf(r.size.x, r.size.y))
	var tex: Texture2D
	var k := 1.0
	if Items.def(id).get("slot", "") == "weapon":
		# made to fill the box exactly, at a whole number of screen pixels a pixel
		k = maxf(1.0, roundf(box / WEAPON_PX))
		tex = SpriteCache.weapon_icon(id, int(box / k))
	else:
		tex = texture(id, col)
		if tex == null:
			return
		# a whole number of screen pixels to a texel keeps the pixels square
		var fit := minf(r.size.x / tex.get_width(), r.size.y / tex.get_height())
		k = floorf(fit) if fit >= 1.0 else fit
	var ts := Vector2(tex.get_size())
	var size := ts * k
	if fade >= 1.0:
		ci.draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.4, Color(col.r, col.g, col.b, 0.07))
	ci.draw_texture_rect(tex, Rect2((r.get_center() - size * 0.5).round(), size), false, Color(1, 1, 1, fade))


## The texture of item [id]'s picture, or null when it has none.
static func texture(id: String, col: Color) -> Texture2D:
	var d: Dictionary = Items.def(id)
	if d.get("slot", "") == "weapon":
		return SpriteCache.weapon_icon(id)
	if G.HEADS.has(id):
		var pal: Array = S.HERO_PAL.duplicate()
		pal[1] = Hero.dye("head", col)
		return SpriteCache.tex(G.HEADS[id], pal)
	if G.BODIES.has(id):
		var pal: Array = S.HERO_PAL.duplicate()
		pal[0] = Hero.dye("body", col)
		return SpriteCache.tex(G.BODIES[id], pal)
	if G.ICONS.has(id):
		return SpriteCache.tex(G.ICONS[id], [col])
	return null
