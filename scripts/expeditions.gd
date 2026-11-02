## After the first descent: choose a short, mixed-biome expedition at each exit.
## Choices and fallback routes depend only on world seed and depth.
extends RefCounted

const D := preload("res://scripts/data.gd")
const MODIFIERS := ["hunt", "restless", "discovery"]


static func choices(seed_value: int, level: int, previous: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, level, "expedition"])
	var pool: Array = range(D.BIOMES.size())
	pool.erase(previous)
	var out: Array = []
	for i in MODIFIERS.size():
		var at := rng.randi_range(0, pool.size() - 1)
		var primary: int = pool.pop_at(at)
		var secondary := (primary + rng.randi_range(1, D.BIOMES.size() - 1)) % D.BIOMES.size()
		# A different primary means its guardian cannot repeat on the next route.
		out.append({"level": level, "primary": primary, "secondary": secondary, "modifier": MODIFIERS[i]})
	return out


static func valid(route: Dictionary, level: int) -> bool:
	return int(route.get("level", -1)) == level and int(route.get("primary", -1)) in range(D.BIOMES.size()) \
		and int(route.get("secondary", -1)) in range(D.BIOMES.size()) \
		and route.get("primary") != route.get("secondary") and route.get("modifier", "") in MODIFIERS


static func biome(p: Dictionary, seed_value: int, level: int) -> Dictionary:
	if level <= D.FINAL_LEVEL:
		return D.BIOMES[int((maxi(1, level) - 1) / D.LEVELS_PER_BIOME)]
	if not valid(p.get("expedition", {}), level):
		# Legacy endless saves start at their saved depth, with all equipment intact.
		p.expedition = choices(seed_value, level, (level - 2) % D.BIOMES.size())[0]
	var route: Dictionary = p.expedition
	var b: Dictionary = D.BIOMES[route.primary].duplicate(true)
	var echo: Dictionary = D.BIOMES[route.secondary]
	b.foes.append_array(echo.foes)
	for key in ["sky_top", "sky_bot", "fill", "deep", "edge", "top", "far", "mid", "mote", "light", "torch", "water"]:
		b[key] = b[key].lerp(echo[key], 0.3)
	b.modifier = route.modifier
	b.echo = echo.id
	return b


static func reward_mult(b: Dictionary) -> float:
	return {"hunt": 1.4, "restless": 1.3}.get(b.get("modifier", ""), 1.0)


static func menu_items(m) -> Array:
	var g = m.game
	var previous := 0
	for i in D.BIOMES.size():
		if D.BIOMES[i].id == g.biome.id:
			previous = i
	var out: Array = []
	for route in choices(g.run_seed, g.level_num + 1, previous):
		var name: String = g.L("biome_" + D.BIOMES[route.primary].id)
		out.append(m._btn(name + " · " + g.L("exp_" + route.modifier), g.choose_expedition.bind(route),
			{"tip": g.L("exp_" + route.modifier + "_d") + " " + g.L("exp_echo") % g.L("biome_" + D.BIOMES[route.secondary].id)}))
	out.append(m._btn(g.L("m_back"), m.close))
	return out
