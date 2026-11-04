## Isolated postgame flow and seeded level generation; no game scene.
extends SceneTree

const D := preload("res://scripts/data.gd")
const Endless := preload("res://scripts/endless.gd")
const Level := preload("res://scripts/level.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _initialize() -> void:
	var original: Array = D.BIOMES.duplicate(true)
	for n in range(1, D.FINAL_LEVEL + 1):
		check(Endless.biome(7, n) == D.BIOMES[(n - 1) / 3], "first descent keeps original biome and boss")
	for seed_value in range(40):
		var previous := D.BIOMES.size() - 1
		for tour in 3:
			var seen: Array = []
			for slot in D.BIOMES.size():
				var n := D.FINAL_LEVEL + 1 + tour * D.BIOMES.size() + slot
				var index := Endless.biome_index(seed_value, n)
				check(not seen.has(index), "one visit to each biome per tour")
				if slot > 0 or tour > 0:
					check(index != previous, "no same biome on adjacent postgame floors")
				seen.append(index)
				previous = index
				var b := Endless.biome(seed_value, n)
				check(b.id == D.BIOMES[index].id and b.boss == D.BIOMES[index].boss, "selected biome keeps its guardian")
				check(b.foes.size() > D.BIOMES[index].foes.size() and b.has("echo"), "enemy pool mixes a second biome")
				check(Endless.biome(seed_value, n) == b, "postgame biome deterministic")
		for n in [18, 19, 20, 25, 36, 1000]:
			var b := Endless.biome(seed_value, n)
			var a := Level.new()
			var c := Level.new()
			var r1 := RandomNumberGenerator.new()
			var r2 := RandomNumberGenerator.new()
			r1.seed = hash([seed_value, n])
			r2.seed = r1.seed
			a.build(n, b, r1, n > 18 or n % 3 == 0)
			c.build(n, b, r2, n > 18 or n % 3 == 0)
			check(a.tiles == c.tiles and a.props == c.props, "same seed rebuilds same floor and chests")
			if n > 18:
				var bosses := 0
				var shops := 0
				for ar in a.arenas:
					if ar.boss:
						bosses += 1
				for pr in a.props:
					if pr.kind == "shop":
						shops += 1
				check(a.gw == 4 and a.gh == 3 and bosses == 1, "short floor has one guardian")
				check(shops == 1 and not a.door_open, "merchant and exit: seed=%d level=%d shops=%d door=%s" % [seed_value, n, shops, str(a.door_open)])
	check(D.BIOMES == original, "mixing does not mutate story biomes")
	print("Endless: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
