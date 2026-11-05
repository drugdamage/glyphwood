## Short postgame floors: a seeded tour for old saves, or a chosen destination
## and rule for new descents. A second biome lends enemies and colour.
extends RefCounted

const D := preload("res://scripts/data.gd")

const MODES := ["onslaught", "restless", "relic"]
const SCOUT_MAX := 2


static func index_for_id(id: String) -> int:
	for i in D.BIOMES.size():
		if D.BIOMES[i].id == id:
			return i
	return -1


## Three deterministic offers, with different destinations and rules.
## A new offer excludes both the current and previous primary biome.
static func options(seed_value: int, next_level: int, current: int, previous: int = -1, scouts: int = 0) -> Array:
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
		var primary: int = pool[(i + clampi(scouts, 0, SCOUT_MAX)) % pool.size()]
		var echo := (primary + rng.randi_range(1, D.BIOMES.size() - 1)) % D.BIOMES.size()
		offers.append({"level": next_level, "primary": primary, "echo_index": echo,
			"mode": MODES[i], "previous": current})
	return offers


static func valid(route: Dictionary, level_num: int) -> bool:
	return int(route.get("level", -1)) == level_num and int(route.get("primary", -1)) in range(D.BIOMES.size()) \
		and int(route.get("echo_index", -1)) in range(D.BIOMES.size()) \
		and route.get("primary") != route.get("echo_index") and route.get("mode", "") in MODES


static func guardian_boss(route: Dictionary) -> String:
	var index: int = int(route.echo_index) if route.mode == "restless" else int(route.primary)
	return D.BIOMES[index].boss


static func menu_items(m) -> Array:
	var g = m.game
	var current := index_for_id(g.biome.id)
	var previous: int = int(g.player.get("route", {}).get("previous", -1))
	var out: Array = []
	for route in options(g.run_seed, g.level_num + 1, current, previous, int(g.player.get("route_refresh", 0))):
		var dest: String = g.L("biome_" + D.BIOMES[route.primary].id)
		var tip: String = g.L("route_" + route.mode + "_d") + " "
		tip += g.L("route_echo") % g.L("biome_" + D.BIOMES[route.echo_index].id)
		tip += " " + g.L("route_guardian") % g.L("boss_" + guardian_boss(route))
		out.append(m._btn(dest + " · " + g.L("route_" + route.mode), g.choose_route.bind(route), {"tip": tip}))
	out.append(m._btn(g.L("m_back"), m.close))
	return out


static func shard_mult(b: Dictionary) -> float:
	return {"onslaught": 1.4, "restless": 1.3}.get(b.get("mode", ""), 1.0)


static func scout_price(p: Dictionary) -> int:
	return 35 + 25 * int(p.get("route_refresh", 0))


static func scout_shop_item(m) -> Dictionary:
	var p: Dictionary = m.game.player
	if m.game.level_num < D.FINAL_LEVEL or int(p.get("route_refresh", 0)) >= SCOUT_MAX:
		return {}
	return {"type": "buy", "id": "lodestone", "price": scout_price(p), "act": buy_scout.bind(m),
		"label": m.game.L("route_scout"), "color": Color(0.6, 0.85, 1.0),
		"note": m.game.L("route_scout_note") % [int(p.get("route_refresh", 0)) + 1, SCOUT_MAX]}


static func buy_scout(m) -> void:
	var p: Dictionary = m.game.player
	if m.game.level_num < D.FINAL_LEVEL or int(p.get("route_refresh", 0)) >= SCOUT_MAX:
		return
	var cost := scout_price(p)
	if p.shards < cost:
		m.game.sfx("error", -6.0)
		m._message(m.game.L("shop_poor"))
		return
	p.shards -= cost
	p.route_refresh = int(p.get("route_refresh", 0)) + 1
	m.game.sfx("buy")
	m._message(m.game.L("route_scout_done"))
	m.game.save_run()


static func select_route(p: Dictionary, route: Dictionary, seed_value: int, level_num: int, current: int) -> bool:
	var previous: int = int(p.get("route", {}).get("previous", -1))
	var scouts: int = int(p.get("route_refresh", 0))
	if not options(seed_value, level_num + 1, current, previous, scouts).has(route):
		return false
	p.route = route.duplicate()
	p.route_refresh = 0
	return true


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
		b.boss = guardian_boss(route)
	return b
