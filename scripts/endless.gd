## Short postgame floors: a seeded tour for old saves, or a chosen destination
## and rule for new descents. A second biome lends enemies and colour.
extends RefCounted

const D := preload("res://scripts/data.gd")

const MODES := ["onslaught", "restless", "relic"]


static func index_for_id(id: String) -> int:
	for i in D.BIOMES.size():
		if D.BIOMES[i].id == id:
			return i
	return -1


## Three deterministic offers, with different destinations and rules.
## A new offer excludes both the current and previous primary biome.
static func options(seed_value: int, next_level: int, current: int, previous: int = -1) -> Array:
	if next_level <= D.FINAL_LEVEL or current < 0 or current >= D.BIOMES.size():
		return []
	var pool: Array = range(D.BIOMES.size())
	pool.erase(current)
	pool.erase(previous)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, next_level, current, previous, "routes"])
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var offers: Array = []
	for i in MODES.size():
		var primary: int = pool[i]
		var echo := (primary + rng.randi_range(1, D.BIOMES.size() - 1)) % D.BIOMES.size()
		offers.append({"level": next_level, "primary": primary, "echo_index": echo,
			"mode": MODES[i], "previous": current})
	return offers


static func valid(route: Dictionary, level_num: int) -> bool:
	return int(route.get("level", -1)) == level_num and int(route.get("primary", -1)) in range(D.BIOMES.size()) \
		and int(route.get("echo_index", -1)) in range(D.BIOMES.size()) \
		and route.get("primary") != route.get("echo_index") and route.get("mode", "") in MODES


static func menu_items(m) -> Array:
	var g = m.game
	var current := index_for_id(g.biome.id)
	var previous: int = int(g.player.get("route", {}).get("previous", -1))
	var out: Array = []
	for route in options(g.run_seed, g.level_num + 1, current, previous):
		var dest: String = g.L("biome_" + D.BIOMES[route.primary].id)
		out.append(m._btn(dest + " · " + g.L("route_" + route.mode), g.choose_route.bind(route),
			{"tip": g.L("route_" + route.mode + "_d") + " " + g.L("route_echo") % g.L("biome_" + D.BIOMES[route.echo_index].id)}))
	out.append(m._btn(g.L("m_back"), m.close))
	return out


static func shard_mult(b: Dictionary) -> float:
	return {"onslaught": 1.4, "restless": 1.3}.get(b.get("mode", ""), 1.0)



static func _raw_order(seed_value: int, tour: int) -> Array:
	var order: Array = range(D.BIOMES.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, tour, "endless"])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: int = order[i]
		order[i] = order[j]
		order[j] = old
	return order


static func _order(seed_value: int, tour: int) -> Array:
	var order := _raw_order(seed_value, tour)
	if tour > 0:
		var previous: Array = _raw_order(seed_value, tour - 1)
		if order[0] == previous[-1]:
			var old: int = order[0]
			order[0] = order[1]
			order[1] = old
	return order


static func biome_index(seed_value: int, level_num: int) -> int:
	if level_num <= D.FINAL_LEVEL:
		return int((maxi(1, level_num) - 1) / D.LEVELS_PER_BIOME)
	var floor := level_num - D.FINAL_LEVEL - 1
	var order := _order(seed_value, int(floor / D.BIOMES.size()))
	return order[floor % D.BIOMES.size()]


static func biome(seed_value: int, level_num: int, route: Dictionary = {}) -> Dictionary:
	var index := biome_index(seed_value, level_num)
	if level_num <= D.FINAL_LEVEL:
		return D.BIOMES[index]
	var floor := level_num - D.FINAL_LEVEL - 1
	var order := _order(seed_value, int(floor / D.BIOMES.size()))
	var echo_index: int = order[(floor + 1) % D.BIOMES.size()]
	if valid(route, level_num):
		index = int(route.primary)
		echo_index = int(route.echo_index)
	var echo: Dictionary = D.BIOMES[echo_index]
	var b: Dictionary = D.BIOMES[index].duplicate(true)
	b.foes.append_array(echo.foes)
	for key in ["sky_top", "sky_bot", "fill", "deep", "edge", "top", "far", "mid", "mote", "light", "torch", "water"]:
		b[key] = b[key].lerp(echo[key], 0.25)
	b.echo = echo.id
	if valid(route, level_num):
		b.mode = route.mode
	return b
