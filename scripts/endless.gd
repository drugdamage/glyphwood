## Short postgame floors: each tour visits all six biomes in a seeded order,
## with a second biome lending enemies and some colour to each destination.
extends RefCounted

const D := preload("res://scripts/data.gd")


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


static func biome(seed_value: int, level_num: int) -> Dictionary:
	var index := biome_index(seed_value, level_num)
	if level_num <= D.FINAL_LEVEL:
		return D.BIOMES[index]
	var floor := level_num - D.FINAL_LEVEL - 1
	var order := _order(seed_value, int(floor / D.BIOMES.size()))
	var echo: Dictionary = D.BIOMES[order[(floor + 1) % D.BIOMES.size()]]
	var b: Dictionary = D.BIOMES[index].duplicate(true)
	b.foes.append_array(echo.foes)
	for key in ["sky_top", "sky_bot", "fill", "deep", "edge", "top", "far", "mid", "mote", "light", "torch", "water"]:
		b[key] = b[key].lerp(echo[key], 0.25)
	b.echo = echo.id
	return b
