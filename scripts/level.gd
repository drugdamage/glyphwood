## Builds a level by chaining hand-made chunks. Tiles live in a flat byte array.
extends RefCounted

const D := preload("res://scripts/data.gd")

const AIR := 0
const SOLID := 1
const ONEWAY := 2
const SPIKES := 3

var w := 0
var h := 0
var tiles := PackedByteArray()
var spawns: Array = []      # {kind, pos (bottom-center world)}
var pickups: Array = []     # {kind, pos}
var start := Vector2.ZERO   # bottom-center of the player
var door := Rect2()


func build(level_num: int, rng: RandomNumberGenerator) -> void:
	var count := mini(4 + level_num, 9)
	var order: Array = [D.CHUNK_START]
	var last := -1
	for i in count:
		var pick := rng.randi_range(0, D.CHUNKS.size() - 1)
		if pick == last:
			pick = (pick + 1) % D.CHUNKS.size()
		last = pick
		order.append(D.CHUNKS[pick])
	order.append(D.CHUNK_END)

	w = order.size() * D.CHUNK_W
	h = D.CHUNK_H
	tiles = PackedByteArray()
	tiles.resize(w * h)
	spawns.clear()
	pickups.clear()
	for ci in order.size():
		var chunk: Array = order[ci]
		for y in h:
			var row: String = chunk[y]
			for x in D.CHUNK_W:
				var gx := ci * D.CHUNK_W + x
				var c := row[x]
				var t := AIR
				var foot := Vector2((gx + 0.5) * D.TILE, (y + 1) * D.TILE)
				match c:
					"#": t = SOLID
					"=": t = ONEWAY
					"^": t = SPIKES
					"P": start = foot
					"D": door = Rect2(gx * D.TILE, (y - 2) * D.TILE, D.TILE * 2, D.TILE * 3)
					"h": pickups.append({"kind": "heart", "pos": foot})
					"c": spawns.append({"kind": "crawler", "pos": foot})
					"b": spawns.append({"kind": "bat", "pos": foot})
					"k": spawns.append({"kind": "knight", "pos": foot})
					"s": spawns.append({"kind": "spitter", "pos": foot})
					"e":
						var r := rng.randf()
						var kind := "crawler" if r < 0.5 else ("knight" if r < 0.8 else "spitter")
						spawns.append({"kind": kind, "pos": foot})
				tiles[y * w + gx] = t


func at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w:
		return SOLID
	if ty >= h:
		return SOLID
	return tiles[ty * w + tx]


func solid(tx: int, ty: int) -> bool:
	return at(tx, ty) == SOLID


func pixel_size() -> Vector2:
	return Vector2(w, h) * D.TILE
