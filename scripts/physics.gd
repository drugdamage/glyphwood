## Axis-separated AABB movement against the tile grid.
## A body is a Dictionary with pos (top-left), size, vel, on_floor, on_wall.
extends RefCounted

const D := preload("res://scripts/data.gd")
const Level := preload("res://scripts/level.gd")


static func move(b: Dictionary, lv, dt: float, drop: bool = false, use_oneway: bool = true) -> void:
	var T := D.TILE
	var pos: Vector2 = b.pos
	var size: Vector2 = b.size
	var vel: Vector2 = b.vel

	b.on_wall = 0
	var dx := vel.x * dt
	if dx != 0.0:
		pos.x += dx
		var top := int(floor(pos.y / T))
		var bot := int(floor((pos.y + size.y - 0.01) / T))
		if dx > 0.0:
			var col := int(floor((pos.x + size.x - 0.01) / T))
			for ty in range(top, bot + 1):
				if lv.solid(col, ty):
					pos.x = col * T - size.x
					vel.x = 0.0
					b.on_wall = 1
					break
		else:
			var col := int(floor(pos.x / T))
			for ty in range(top, bot + 1):
				if lv.solid(col, ty):
					pos.x = (col + 1) * T
					vel.x = 0.0
					b.on_wall = -1
					break

	b.on_floor = false
	var dy := vel.y * dt
	var prev_bottom := pos.y + size.y
	pos.y += dy
	var left := int(floor(pos.x / T))
	var right := int(floor((pos.x + size.x - 0.01) / T))
	if dy > 0.0:
		var row := int(floor((pos.y + size.y - 0.01) / T))
		for tx in range(left, right + 1):
			var t: int = lv.at(tx, row)
			var lands: bool = lv.solid(tx, row)
			if t == Level.ONEWAY and use_oneway and not drop and prev_bottom <= row * T + 0.5:
				lands = true
			if lands:
				pos.y = row * T - size.y
				vel.y = 0.0
				b.on_floor = true
				break
	elif dy < 0.0:
		var row := int(floor(pos.y / T))
		for tx in range(left, right + 1):
			if lv.solid(tx, row):
				pos.y = (row + 1) * T
				vel.y = 0.0
				break

	b.pos = pos
	b.vel = vel


## Returns -1 / 1 if a wall touches the body's left / right side, else 0.
static func wall_side(b: Dictionary, lv) -> int:
	var T := D.TILE
	var top := int(floor((b.pos.y + 4.0) / T))
	var bot := int(floor((b.pos.y + b.size.y - 6.0) / T))
	var lc := int(floor((b.pos.x - 1.0) / T))
	var rc := int(floor((b.pos.x + b.size.x + 1.0) / T))
	for ty in range(top, bot + 1):
		if lv.solid(lc, ty):
			return -1
		if lv.solid(rc, ty):
			return 1
	return 0


## True when the tile just below the body's front foot is walkable.
static func ground_ahead(b: Dictionary, lv, dir: int) -> bool:
	var T := D.TILE
	var fx: float = b.pos.x + b.size.x + 2.0 if dir > 0 else b.pos.x - 2.0
	var tx := int(floor(fx / T))
	var ty := int(floor((b.pos.y + b.size.y + 2.0) / T))
	var t: int = lv.at(tx, ty)
	return lv.solid(tx, ty) or t == Level.ONEWAY


static func rect(b: Dictionary) -> Rect2:
	return Rect2(b.pos, b.size)


static func center(b: Dictionary) -> Vector2:
	return b.pos + b.size * 0.5


static func foot(b: Dictionary) -> Vector2:
	return Vector2(b.pos.x + b.size.x * 0.5, b.pos.y + b.size.y)


## True if the rect overlaps the lower half of a spike tile or the body of a lava tile.
static func touches_spikes(r: Rect2, lv) -> bool:
	var T := D.TILE
	for ty in range(int(floor(r.position.y / T)), int(floor(r.end.y / T)) + 1):
		for tx in range(int(floor(r.position.x / T)), int(floor(r.end.x / T)) + 1):
			var t: int = lv.at(tx, ty)
			if t == Level.SPIKES:
				if r.intersects(Rect2(tx * T + 2.0, ty * T + T * 0.45, T - 4.0, T * 0.55)):
					return true
			elif t == Level.LAVA:
				if r.intersects(Rect2(tx * T, ty * T + T * 0.3, T, T * 0.7)):
					return true
	return false


## True when the body's centre is inside a water tile.
static func in_water(b: Dictionary, lv) -> bool:
	var c := center(b)
	return lv.at(int(floor(c.x / D.TILE)), int(floor(c.y / D.TILE))) == Level.WATER


## Tiles of a given type overlapping a rect, as Vector2i.
static func tiles_in(r: Rect2, lv, kind: int) -> Array:
	var out: Array = []
	var T := D.TILE
	for ty in range(int(floor(r.position.y / T)), int(floor(r.end.y / T)) + 1):
		for tx in range(int(floor(r.position.x / T)), int(floor(r.end.x / T)) + 1):
			if lv.at(tx, ty) == kind:
				out.append(Vector2i(tx, ty))
	return out
