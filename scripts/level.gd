## Builds a level as a grid of rooms. A path runs from the start room in the top
## row to the exit (or boss) room in the bottom row, moving sideways and down
## through shafts. Rooms next to the path become side rooms: shop, treasure
## rooms and hand-made vaults. Lanterns (checkpoints) stand in the start room,
## halfway along the path and right before the exit or boss.
## Tiles live in a flat byte array.
extends RefCounted

const D := preload("res://scripts/data.gd")

const AIR := 0
const SOLID := 1
const ONEWAY := 2
const SPIKES := 3
const WATER := 4
const LAVA := 5
const CRACKED := 6
const GATE := 7

const RW := D.ROOM_W
const RH := D.ROOM_H

var w := 0
var h := 0
var gw := 0
var gh := 0
var tiles := PackedByteArray()
var rooms: Array = []        # gy * gw + gx -> room Dictionary or null
var path: Array = []         # rooms from start to exit
var spawns: Array = []       # {kind, pos (feet), elite, room}
var props: Array = []        # {kind, pos (feet), ...}
var pickups: Array = []      # {kind, pos}
var decor: Array = []        # {x, y, kind, v}
var torches: Array = []      # world positions
var arenas: Array = []       # {room, rect, gates, waves, state}
var signs := 0
var start := Vector2.ZERO
var door := Rect2()
var door_open := true
var biome: Dictionary = {}
var boss_level := false

var _rng: RandomNumberGenerator
var _level := 1


func build(level_num: int, b: Dictionary, rng: RandomNumberGenerator, with_boss: bool) -> void:
	_rng = rng
	_level = level_num
	biome = b
	boss_level = with_boss
	# levels grow as the descent goes on: wider from the third, taller from the fifth
	gw = 4 if level_num < 3 else (5 if level_num < 7 else 6)
	gh = 2 if level_num == 1 else (3 if level_num < 5 else 4)
	w = gw * RW
	h = gh * RH
	tiles = PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(SOLID)
	rooms.clear()
	rooms.resize(gw * gh)
	_make_path()
	_make_side_rooms()
	# a lantern every three or four rooms of the path, and one before the exit
	path[0].lantern = true
	var stretches := maxi(1, int(ceil((path.size() - 2) / 3.5)))
	for k in range(1, stretches):
		path[int(k * (path.size() - 1) / float(stretches))].lantern = true
	if path.size() >= 3:
		path[-2].lantern = true
	for r in rooms:
		if r != null:
			_gen_room(r)


# ---------------------------------------------------------------- layout

func _room(gx: int, gy: int) -> Dictionary:
	var r := {
		"gx": gx, "gy": gy, "kind": "normal", "l": false, "r": false, "u": -1, "d": -1,
		"x0": gx * RW, "y0": gy * RH, "seen": false, "floor": [], "ceil": [], "protect": [], "lantern": false,
	}
	rooms[gy * gw + gx] = r
	return r


func room_at_tile(tx: int, ty: int) -> Variant:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return null
	return rooms[int(ty / RH) * gw + int(tx / RW)]


func _make_path() -> void:
	path.clear()
	var gx := _rng.randi_range(0, gw - 1)
	var gy := 0
	var dir := -1 if _rng.randf() < 0.5 else 1
	var cur := _room(gx, gy)
	path.append(cur)
	var guard := 0
	while guard < 64:
		guard += 1
		var go_down := _rng.randf() < 0.32
		var nx := gx + dir
		if nx < 0 or nx >= gw or rooms[gy * gw + nx] != null:
			go_down = true
		if go_down:
			if gy == gh - 1:
				if path.size() < 4 and nx >= 0 and nx < gw and rooms[gy * gw + nx] == null:
					go_down = false
				else:
					break
		if go_down:
			var sx := _rng.randi_range(8, RW - 8 - D.SHAFT_W)
			cur.d = sx
			gy += 1
			cur = _room(gx, gy)
			cur.u = sx
			dir = -1 if _rng.randf() < 0.5 else 1
		else:
			if dir > 0:
				cur.r = true
			else:
				cur.l = true
			gx = nx
			cur = _room(gx, gy)
			if dir > 0:
				cur.l = true
			else:
				cur.r = true
		path.append(cur)
	path[0].kind = "start"
	path[-1].kind = "boss" if boss_level else "exit"
	if path.size() >= 4:
		path[_rng.randi_range(1, path.size() - 2)].kind = "arena"
	# long paths get a second arena, in whichever half has none yet
	if path.size() >= 10:
		var half := path.size() / 2
		var first := false
		for i in range(1, half):
			first = first or path[i].kind == "arena"
		var lo := half if first else 1
		var hi := path.size() - 2 if first else half - 1
		for attempt in 6:
			var r: Dictionary = path[_rng.randi_range(lo, hi)]
			if r.kind == "normal":
				r.kind = "arena"
				break


func _make_side_rooms() -> void:
	var wanted := ["shop"]
	var extra := ["treasure", "vault", "treasure", "vault", "treasure"]
	extra.shuffle()
	wanted.append_array(extra)
	var cells: Array = []
	for gy in gh:
		for gx in gw:
			if rooms[gy * gw + gx] == null:
				cells.append(Vector2i(gx, gy))
	cells.shuffle()
	for c in cells:
		if wanted.is_empty():
			break
		var left = rooms[c.y * gw + c.x - 1] if c.x > 0 else null
		var right = rooms[c.y * gw + c.x + 1] if c.x < gw - 1 else null
		var link = null
		var side := 0
		if left != null and path.has(left) and left.kind != "boss":
			link = left
			side = -1
		elif right != null and path.has(right) and right.kind != "boss":
			link = right
			side = 1
		if link == null:
			continue
		var r := _room(c.x, c.y)
		r.kind = wanted.pop_front()
		if side < 0:
			r.l = true
			link.r = true
		else:
			r.r = true
			link.l = true


# ---------------------------------------------------------------- tiles

func at(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return SOLID
	return tiles[ty * w + tx]


func solid(tx: int, ty: int) -> bool:
	var t := at(tx, ty)
	return t == SOLID or t == CRACKED or t == GATE


func is_hazard(t: int) -> bool:
	return t == SPIKES or t == LAVA


func set_t(tx: int, ty: int, t: int) -> void:
	if tx >= 0 and ty >= 0 and tx < w and ty < h:
		tiles[ty * w + tx] = t


func pixel_size() -> Vector2:
	return Vector2(w, h) * D.TILE


func _foot(tx: int, row: int) -> Vector2:
	return Vector2((tx + 0.5) * D.TILE, row * D.TILE)


# ---------------------------------------------------------------- rooms

func _gen_room(r: Dictionary) -> void:
	if r.kind == "vault" and not _gen_vault(r):
		r.kind = "treasure"
	if r.kind == "vault":
		return
	var flat: bool = r.kind in ["boss", "shop", "arena"]
	var f := _floor_line(r, flat)
	var c := _ceil_line(r, f)
	r.floor = f
	r.ceil = c
	var x0: int = r.x0
	var y0: int = r.y0
	for x in RW:
		for y in range(c[x] + 1, f[x]):
			set_t(x0 + x, y0 + y, AIR)
	_walls(r)
	if r.d >= 0:
		for x in range(r.d, r.d + D.SHAFT_W):
			for y in range(f[x], RH):
				set_t(x0 + x, y0 + y, AIR)
			r.protect.append(x)
	if r.u >= 0:
		for x in range(r.u - 2, r.u + D.SHAFT_W + 2):
			r.protect.append(x)
		for x in range(r.u, r.u + D.SHAFT_W):
			for y in range(0, c[x] + 1):
				set_t(x0 + x, y0 + y, AIR)
	match r.kind:
		"start":
			var sx := 6 if not r.l else RW - 8
			if r.r and r.l:
				sx = RW / 2
			for cand in [sx, RW / 2, 6, RW - 8, 12, RW - 14]:
				var clear := true
				for x in range(cand - 3, cand + 6):
					if r.protect.has(x):
						clear = false
				if clear:
					sx = cand
					break
			for x in range(sx - 3, sx + 4):
				r.protect.append(x)
			start = _foot(x0 + sx, y0 + f[sx])
			if _level == 1 or _rng.randf() < 0.5:
				_add_prop("sign", x0 + sx + 4, y0 + f[sx + 4], {"text": "sign_start" if _level == 1 else _lore()})
			if f[sx - 3] == f[sx]:
				_add_prop("lantern", x0 + sx - 3, y0 + f[sx], {"lit": true, "start": true})
			r.lantern = false
		"boss":
			_arena(r, true)
		"arena":
			_arena(r, false)
		"shop":
			_add_prop("shop", x0 + RW / 2, y0 + f[RW / 2], {"stock": []})
			_torch(x0 + RW / 2 - 6, y0 + f[RW / 2] - 3)
			_torch(x0 + RW / 2 + 6, y0 + f[RW / 2] - 3)
	if r.lantern and r.kind != "boss" and r.kind != "arena":
		_lantern(r)
	if r.kind in ["normal", "treasure", "start", "exit"]:
		_pits(r)
		_platforms(r)
		_secret(r)
	if r.kind == "exit":
		_exit_door(r)
	if r.kind in ["normal", "treasure", "exit"] or (r.kind == "start" and _level > 1):
		_enemies(r)
	_decorate(r)


## Floor surface row (first solid tile) per column. Steps are at most 2 tiles.
func _floor_line(r: Dictionary, flat: bool) -> Array:
	var f: Array = []
	f.resize(RW)
	var lo := RH - 9
	var hi := RH - 4
	var cur := D.EDGE_FLOOR if (r.l or flat) else _rng.randi_range(lo, hi)
	var x := 0
	while x < RW:
		var seg := _rng.randi_range(3, 7)
		for k in seg:
			if x < RW:
				f[x] = cur
				x += 1
		if flat:
			cur = D.EDGE_FLOOR
		elif r.r and x > RW - 14:
			cur = cur + clampi(D.EDGE_FLOOR - cur, -2, 2)
		else:
			cur = clampi(cur + [-2, -1, -1, 0, 0, 1, 1, 2][_rng.randi_range(0, 7)], lo, hi)
	if r.l:
		for i in 4:
			f[i] = D.EDGE_FLOOR
	if r.r:
		for i in range(RW - 4, RW):
			f[i] = D.EDGE_FLOOR
	for i in range(1, RW):
		f[i] = clampi(f[i], f[i - 1] - 2, f[i - 1] + 2)
	return f


## Last solid row of the ceiling per column (-1 = open sky).
func _ceil_line(r: Dictionary, f: Array) -> Array:
	var c: Array = []
	c.resize(RW)
	var sky: bool = biome.sky and r.gy == 0
	var tall: bool = r.kind in ["boss", "arena"]
	var cur := _rng.randi_range(1, 5)
	for x in RW:
		if x % 3 == 0:
			cur = clampi(cur + _rng.randi_range(-1, 1), 1, 7)
		var v := cur
		if sky:
			v = -1
		elif tall:
			v = 1
		v = mini(v, f[x] - 9)
		if (x < 4 and r.l) or (x >= RW - 4 and r.r):
			v = mini(v, D.EDGE_FLOOR - D.DOOR_H - 2)
		c[x] = v
	return c


func _walls(r: Dictionary) -> void:
	var x0: int = r.x0
	var y0: int = r.y0
	var sky: bool = biome.sky and r.gy == 0
	for side in [0, 1]:
		var open: bool = r.l if side == 0 else r.r
		for k in 2:
			var x: int = x0 + (k if side == 0 else RW - 1 - k)
			for y in RH:
				var in_door := y >= D.EDGE_FLOOR - D.DOOR_H and y < D.EDGE_FLOOR
				# open-sky rooms have no wall above a side opening
				if sky and open and y < D.EDGE_FLOOR:
					continue
				if not (open and in_door):
					set_t(x, y0 + y, SOLID)
	if not (biome.sky and r.gy == 0):
		for x in RW:
			if r.u >= 0 and x >= r.u and x < r.u + D.SHAFT_W:
				continue
			set_t(x0 + x, y0, SOLID)
	for x in RW:
		if r.d >= 0 and x >= r.d and x < r.d + D.SHAFT_W:
			continue
		set_t(x0 + x, y0 + RH - 1, SOLID)


func _pits(r: Dictionary) -> void:
	var f: Array = r.floor
	var count := _rng.randi_range(0, 2) + (1 if _level > 2 else 0)
	for i in count:
		var kind: String = biome.pits[_rng.randi_range(0, biome.pits.size() - 1)]
		var pw := _rng.randi_range(2, 4) if kind != "water" else _rng.randi_range(3, 6)
		var px := _rng.randi_range(6, RW - 8 - pw)
		var ok := true
		for x in range(px - 2, px + pw + 2):
			if r.protect.has(x) or f[x] != f[px - 1]:
				ok = false
		if not ok:
			continue
		var base: int = f[px - 1]
		var depth := 3 if kind == "water" else 2
		if base + depth >= RH - 1:
			continue
		for x in range(px, px + pw):
			for y in range(base, base + depth):
				var t := AIR
				if kind == "water":
					t = WATER
				elif y == base + depth - 1:
					t = SPIKES if kind == "spikes" else LAVA
				elif kind == "lava":
					t = LAVA
				set_t(r.x0 + x, r.y0 + y, t)
			f[x] = base + depth
			r.protect.append(x)


func _platforms(r: Dictionary) -> void:
	var f: Array = r.floor
	var c: Array = r.ceil
	var count := _rng.randi_range(1, 3) + (1 if r.kind == "treasure" else 0)
	var tops: Array = []
	for i in count:
		var pw := _rng.randi_range(3, 6)
		var px := _rng.randi_range(4, RW - 5 - pw)
		var low := 99
		for x in range(px, px + pw):
			low = mini(low, f[x])
		var py := low - _rng.randi_range(3, 4)
		var tiers := 1 if _rng.randf() < 0.5 else 2
		for tier in tiers:
			var y := py - tier * 4
			var x1 := px + (_rng.randi_range(-3, 3) if tier > 0 else 0)
			x1 = clampi(x1, 3, RW - 4 - pw)
			var fits := true
			for x in range(x1, x1 + pw):
				if y <= c[x] + 2 or y < 3:
					fits = false
			if not fits:
				break
			for x in range(x1, x1 + pw):
				if at(r.x0 + x, r.y0 + y) == AIR:
					set_t(r.x0 + x, r.y0 + y, ONEWAY)
			tops.append(Vector2i(x1 + pw / 2, y))
	if tops.is_empty():
		return
	tops.sort_custom(func(a, b): return a.y < b.y)
	var best: Vector2i = tops[0]
	if r.kind == "treasure":
		_add_prop("chest", r.x0 + best.x, r.y0 + best.y, {"open": false})
	elif _rng.randf() < 0.45:
		pickups.append({"kind": "cache" if _rng.randf() < 0.7 else "heart", "pos": _foot(r.x0 + best.x, r.y0 + best.y) - Vector2(0, 8)})


## Hidden pocket under the floor, roofed with cracked tiles.
func _secret(r: Dictionary) -> void:
	if _rng.randf() > 0.3:
		return
	var f: Array = r.floor
	for attempt in 6:
		var x := _rng.randi_range(6, RW - 12)
		var ok := true
		for k in range(x - 1, x + 6):
			if r.protect.has(k) or f[k] != f[x] or f[x] > RH - 6:
				ok = false
		if not ok:
			continue
		var y: int = f[x]
		for k in range(x, x + 5):
			set_t(r.x0 + k, r.y0 + y, CRACKED)
			for yy in range(y + 1, y + 3):
				set_t(r.x0 + k, r.y0 + yy, AIR)
			r.protect.append(k)
		if _rng.randf() < 0.5:
			_add_prop("chest", r.x0 + x + 2, r.y0 + y + 3, {"open": false})
		else:
			pickups.append({"kind": "cache", "pos": _foot(r.x0 + x + 2, r.y0 + y + 3) - Vector2(0, 8)})
		return


func _arena(r: Dictionary, boss: bool) -> void:
	var f: Array = r.floor
	var x0: int = r.x0
	var y0: int = r.y0
	for side in [-1, 1]:
		var px: int = RW / 2 + side * 12 - 2
		for x in range(px, px + 5):
			set_t(x0 + x, y0 + D.EDGE_FLOOR - 4, ONEWAY)
	if boss:
		for x in range(RW / 2 - 3, RW / 2 + 3):
			set_t(x0 + x, y0 + D.EDGE_FLOOR - 8, ONEWAY)
	var gates: Array = []
	# under an open sky there is no wall above a side opening, so the gate
	# rises all the way up: nobody leaps over it to rest outside the fight
	var gate_top: int = 0 if biome.sky and r.gy == 0 else D.EDGE_FLOOR - D.DOOR_H
	for side in [0, 1]:
		if (r.l if side == 0 else r.r):
			for y in range(gate_top, D.EDGE_FLOOR):
				var gx: int = x0 + (1 if side == 0 else RW - 2)
				if at(gx, y0 + y) == AIR:
					gates.append(Vector2i(gx, y0 + y))
	if r.u >= 0:
		for x in range(r.u, r.u + D.SHAFT_W):
			gates.append(Vector2i(x0 + x, y0 + 1))
	if r.d >= 0:
		for x in range(r.d, r.d + D.SHAFT_W):
			gates.append(Vector2i(x0 + x, y0 + f[x]))
	var waves: Array = []
	if boss:
		var lift := Vector2(0, 90) if D.ENEMIES[biome.boss].fly else Vector2.ZERO
		waves.append([{"kind": biome.boss, "pos": _foot(x0 + RW / 2, y0 + D.EDGE_FLOOR) - lift, "elite": false}])
	else:
		for wv in 2 + (1 if _level > 3 else 0) + (1 if _level > 9 else 0):
			var list: Array = []
			for i in mini(7, 2 + wv + int(_level / 4)):
				list.append(_spawn_def(r, _rng.randi_range(5, RW - 6), true))
			waves.append(list)
	var rect := Rect2((x0 + 4) * D.TILE, (y0 + 2) * D.TILE, (RW - 8) * D.TILE, (RH - 3) * D.TILE)
	arenas.append({"room": r, "rect": rect, "gates": gates, "waves": waves, "state": "idle", "wave": 0, "boss": boss})
	if boss:
		door_open = false
		door = Rect2((x0 + RW / 2 - 1) * D.TILE, (y0 + D.EDGE_FLOOR - 3) * D.TILE, D.TILE * 2, D.TILE * 3)


func _exit_door(r: Dictionary) -> void:
	var f: Array = r.floor
	var best := -1
	for x in range(RW - 8, 6, -1):
		if r.protect.has(x) or r.protect.has(x - 1) or r.protect.has(x + 1):
			continue
		if f[x - 2] == f[x] and f[x - 1] == f[x] and f[x + 1] == f[x] and f[x + 2] == f[x]:
			best = x
			break
	if best < 0:
		best = RW / 2
		for x in range(best - 3, best + 4):
			for y in range(r.ceil[x] + 1, RH - 1):
				set_t(r.x0 + x, r.y0 + y, AIR if y < f[best] else SOLID)
			f[x] = f[best]
	door = Rect2((r.x0 + best - 1) * D.TILE, (r.y0 + f[best] - 3) * D.TILE, D.TILE * 2, D.TILE * 3)
	for x in range(best - 2, best + 3):
		r.protect.append(x)
	door_open = true


func _spawn_def(r: Dictionary, lx: int, ground_only: bool = false) -> Dictionary:
	var foes: Array = biome.foes
	var kind: String = foes[_rng.randi_range(0, foes.size() - 1)]
	var fly: bool = D.ENEMIES[kind].fly
	if ground_only and fly and _rng.randf() < 0.5:
		kind = foes[0]
		fly = D.ENEMIES[kind].fly
	var f: Array = r.floor
	var pos := _foot(r.x0 + lx, r.y0 + f[lx])
	if fly:
		pos.y -= _rng.randf_range(3.0, 6.0) * D.TILE
	return {"kind": kind, "pos": pos, "elite": _rng.randf() < minf(0.4, 0.05 + 0.015 * _level)}


func _enemies(r: Dictionary) -> void:
	var count := _rng.randi_range(2, 3) + int(_level / 3)
	if r.kind == "start":
		count = 1
	count = mini(count, 7)
	var used: Array = []
	for i in count:
		for attempt in 8:
			var lx := _rng.randi_range(6, RW - 7)
			if r.protect.has(lx) or used.has(lx):
				continue
			if r.kind == "start" and absf(_foot(r.x0 + lx, 0).x - start.x) < 12 * D.TILE:
				continue
			var t := at(r.x0 + lx, r.y0 + r.floor[lx] - 1)
			if t != AIR:
				continue
			used.append(lx)
			spawns.append(_spawn_def(r, lx))
			break


# ---------------------------------------------------------------- props and decor

func _add_prop(kind: String, tx: int, row: int, extra: Dictionary) -> void:
	var p := {"kind": kind, "pos": _foot(tx, row)}
	p.merge(extra)
	props.append(p)


func _lantern(r: Dictionary) -> void:
	var f: Array = r.floor
	for x in [RW / 2, RW / 2 - 6, RW / 2 + 6, 9, RW - 10, 14, RW - 15]:
		var ok: bool = f[x - 1] == f[x] and f[x + 1] == f[x]
		for k in range(x - 2, x + 3):
			if r.protect.has(k):
				ok = false
		if ok:
			for k in range(x - 3, x + 4):
				r.protect.append(k)
			_add_prop("lantern", r.x0 + x, r.y0 + f[x], {"lit": false})
			return


func _torch(tx: int, ty: int) -> void:
	if at(tx, ty) == AIR:
		torches.append(Vector2((tx + 0.5) * D.TILE, (ty + 0.5) * D.TILE))


func _lore() -> String:
	signs += 1
	return "lore_%d" % _rng.randi_range(1, 8)


func _decorate(r: Dictionary) -> void:
	var f: Array = r.floor
	var c: Array = r.ceil
	var bid: String = biome.id
	var floor_kinds: Array = {
		"wood": ["grave", "cross", "fern", "rock", "grave", "skull", "candle"],
		"hollow": ["skull", "bones", "candle", "grave", "rock", "candle"],
		"ember": ["bones", "skull", "vent", "crystal", "rock", "cross"],
		"mire": ["reeds", "stump", "skull", "reeds", "gallows", "rock", "candle", "reeds"],
		"cathedral": ["pew", "candelabra", "bones", "font", "candle", "urn", "pew"],
		"crypt": ["sarcophagus", "ice", "skull", "urn", "crystal", "bones", "ice"],
	}[bid]
	var ceil_kinds: Array = {
		"wood": ["vine", "root", "web"], "hollow": ["chain", "web", "chain", "stalactite"], "ember": ["stalactite", "chain"],
		"mire": ["noose", "vine", "root", "noose"], "cathedral": ["chain", "banner", "web", "banner"],
		"crypt": ["icicle", "chain", "icicle", "web"],
	}[bid]
	for x in range(2, RW - 2):
		var tx: int = r.x0 + x
		var fy: int = r.y0 + f[x]
		if at(tx, fy) == SOLID and at(tx, fy - 1) == AIR and _rng.randf() < 0.16:
			decor.append({"x": tx, "y": fy - 1, "kind": floor_kinds[_rng.randi_range(0, floor_kinds.size() - 1)],
				"v": _rng.randi_range(0, 3)})
		var cy: int = r.y0 + c[x]
		if c[x] >= 0 and at(tx, cy) == SOLID and at(tx, cy + 1) == AIR and _rng.randf() < 0.18:
			decor.append({"x": tx, "y": cy + 1, "kind": ceil_kinds[_rng.randi_range(0, ceil_kinds.size() - 1)],
				"v": _rng.randi_range(2, 6)})
	if r.kind in ["normal", "treasure", "exit", "arena", "boss", "start"]:
		var step := 14 if biome.sky else 9
		var x := _rng.randi_range(3, step)
		while x < RW - 3:
			if not r.protect.has(x):
				_torch(r.x0 + x, r.y0 + f[x] - 3)
			x += step + _rng.randi_range(0, 5)


# ---------------------------------------------------------------- vaults

func _gen_vault(r: Dictionary) -> bool:
	var tpl: Array = D.VAULTS[_rng.randi_range(0, D.VAULTS.size() - 1)]
	var f: Array = []
	var c: Array = []
	f.resize(RW)
	c.resize(RW)
	f.fill(D.EDGE_FLOOR)
	c.fill(0)
	r.floor = f
	r.ceil = c
	var x0: int = r.x0
	var y0: int = r.y0
	for y in RH:
		var row: String = tpl[y]
		for x in RW:
			var ch := row[x]
			var t := AIR
			var feet := _foot(x0 + x, y0 + y + 1)
			match ch:
				"#": t = SOLID
				"=": t = ONEWAY
				"^": t = SPIKES
				"~": t = WATER
				"%": t = CRACKED
				"C": _add_prop("chest", x0 + x, y0 + y + 1, {"open": false})
				"*": pickups.append({"kind": "cache", "pos": feet - Vector2(0, 8)})
				"h": pickups.append({"kind": "heart", "pos": feet - Vector2(0, 8)})
				"T": torches.append(feet - Vector2(0, D.TILE * 0.5))
				"e": spawns.append({"kind": biome.foes[0], "pos": feet, "elite": false})
				"b": spawns.append({"kind": "bat", "pos": feet, "elite": false})
			if (ch == "~" or ch == "C" or ch == "*") and y > 0 and tpl[y - 1][x] == "~":
				t = WATER
			set_t(x0 + x, y0 + y, t)
	for y in range(D.EDGE_FLOOR - D.DOOR_H, D.EDGE_FLOOR):
		for k in 2:
			if not r.l:
				set_t(x0 + k, y0 + y, SOLID)
			if not r.r:
				set_t(x0 + RW - 1 - k, y0 + y, SOLID)
	return true
