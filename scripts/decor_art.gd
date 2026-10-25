## Floor decorations painted into the cached terrain chunks: graves, crosses,
## candles, reeds, pews, sarcophagi and the rest, one small pixel picture each
## (pixel_art.gd), in the biome's colours; the variant [v] picks a mirrored or
## slightly different picture.
extends RefCounted

const D := preload("res://scripts/data.gd")
const PixelArt := preload("res://scripts/pixel_art.gd")

## Pictures that may stand mirrored.
const MIRROR := ["bones", "fern", "reeds", "stump", "gallows", "pew", "rock", "skull", "crystal", "ice", "mushroom2"]
const FLOWERS := [Color(1.0, 0.55, 0.7), Color(1.0, 0.9, 0.45), Color(0.9, 0.9, 1.0), Color(0.75, 0.6, 1.0)]


## Paints one floor decoration into a terrain chunk; [o] is the top-left of
## its tile in the chunk's pixels and [s] the screen pixels per world unit.
static func paint_floor(ci: CanvasItem, d: Dictionary, o: Vector2, s: float, b: Dictionary) -> void:
	var v: int = d.v
	var pal := PixelArt.biome_pal(b)
	var name: String = d.kind
	match d.kind:
		"flower":
			pal["f"] = FLOWERS[v]
			pal["F"] = FLOWERS[v].lightened(0.4)
		"mushroom":
			if b.look == "hollow":
				pal["m"] = Color(0.4, 0.62, 0.95)
				pal["M"] = Color(0.7, 0.85, 1.0)
			if v > 1:
				name = "mushroom2"
		"crystal":
			if b.look == "ember":
				pal["a"] = Color(0.9, 0.3, 0.2)
				pal["A"] = Color(1.0, 0.62, 0.45)
		"candle":
			if v > 1:
				name = "candle2"
		"urn":
			if v % 2 == 1:
				pal["n"] = pal.e
				pal["N"] = pal.E
	if not PixelArt.ART.has(name):
		return
	var foot := o + Vector2(D.TILE * 0.5 + (v - 1.5) * 1.5, D.TILE) * s
	PixelArt.draw(ci, name, foot, s, pal, name in MIRROR and v % 2 == 1)
