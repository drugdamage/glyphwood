## Regional loot catalog checks; no game scene or user saves are opened.
extends SceneTree

const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const D := preload("res://scripts/data.gd")


func _initialize() -> void:
	var seen: Array = []
	var failures := 0
	for b in D.BIOMES:
		var goods: Array = Items.BIOME_GOODS.get(b.id, [])
		if goods.size() < 3:
			failures += 1
		var p := Hero.create()
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var draws: Array = []
		for k in 3:
			var id := Items.random_unowned(p, rng, b.id, draws)
			if not goods.has(id) or draws.has(id):
				failures += 1
			draws.append(id)
		for id in goods:
			if not Items.ITEMS.has(id) or Items.def(id).price <= 0 or seen.has(id):
				failures += 1
			seen.append(id)
		p.bag = goods.duplicate()
		if Items.random_unowned(p, rng, b.id) != "":
			failures += 1
	for id in Items.ITEMS:
		if seen.has(id) != (Items.def(id).price > 0):
			failures += 1
	if Items.BIOME_GOODS.wood.has("headsman_axe") or not Items.BIOME_GOODS.crypt.has("headsman_axe"):
		failures += 1
	print("Biome goods: %d priced items, %d failures" % [seen.size(), failures])
	quit(1 if failures else 0)
