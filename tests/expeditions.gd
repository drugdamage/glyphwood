## Isolated route choice, expedition reward and armour transfer regressions.
extends SceneTree

const D := preload("res://scripts/data.gd")
const Endless := preload("res://scripts/endless.gd")
const Forge := preload("res://scripts/forge.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Level := preload("res://scripts/level.gd")
const Menu := preload("res://scripts/menu.gd")
const T := preload("res://scripts/strings.gd")
const T2 := preload("res://scripts/strings_more.gd")
const T3 := preload("res://scripts/strings_routes.gd")

var checks := 0
var failures := 0


class FakeGame extends RefCounted:
	var player := Hero.create()
	var biome: Dictionary = D.BIOMES[5]
	var level_num := 18
	var run_seed := 11
	var shop_prop := {"stock": []}
	var chosen: Dictionary = {}
	var saves := 0

	func L(key: String) -> String:
		return T.STRINGS.get(key, T2.STRINGS.get(key, T3.STRINGS.get(key, [key])))[0]

	func choose_route(route: Dictionary) -> void:
		chosen = route

	func sfx(_kind: String, _volume: float = 0.0) -> void:
		pass

	func save_run() -> void:
		saves += 1


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _initialize() -> void:
	_check_routes()
	_check_forge()
	_check_menus()
	for key in T3.STRINGS:
		check(T3.STRINGS[key].size() == 7, "seven translations: " + key)
	print("Expeditions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_routes() -> void:
	for seed_value in 30:
		for n in [19, 20, 37]:
			var current: int = (seed_value + n) % D.BIOMES.size()
			var previous: int = (current + 1) % D.BIOMES.size()
			var offers := Endless.options(seed_value, n, current, previous)
			check(offers == Endless.options(seed_value, n, current, previous), "offers deterministic")
			check(offers.size() == 3, "three route choices")
			var destinations: Array = []
			for i in offers.size():
				var route: Dictionary = offers[i]
				check(route.mode == Endless.MODES[i], "each option has one mode")
				check(route.primary not in [current, previous] and route.primary not in destinations,
					"destinations do not repeat recent biomes or each other")
				destinations.append(route.primary)
				check(Endless.valid(route, n), "offer validates at destination depth")
				var b := Endless.biome(seed_value, n, route)
				check(b.id == D.BIOMES[route.primary].id and b.echo == D.BIOMES[route.echo_index].id,
					"chosen primary and echo survive generation")
				check(b.mode == route.mode and b.foes.size() > D.BIOMES[route.primary].foes.size(),
					"route rule and mixed foes survive generation")
				check(not Endless.valid(route, n + 1), "old route cannot affect next floor")
				if n == 19:
					var lv := Level.new()
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([seed_value, n])
					lv.build(n, b, rng, true)
					for ar in lv.arenas:
						if not ar.boss:
							check(ar.waves.size() == (3 if route.mode == "onslaught" else 2),
								"onslaught adds one arena wave")
				check(Endless.shard_mult(b) == (1.4 if route.mode == "onslaught" else 1.3 if route.mode == "restless" else 1.0),
					"route shard reward")
	check(Endless.options(1, 18, 0).is_empty(), "no route before finale")
	var p := Hero.create()
	var id: String = Items.BLUEPRINTS[D.BIOMES[0].id]
	check(Items.find_fragments(p, 19, D.BIOMES[0].id, false, 1) == 2, "relic chest gives extra fragment")
	check(Items.find_fragments(p, 19, D.BIOMES[0].id, false, 1) == 1, "relic floor caps at three")
	check(Items.fragment_count(p, id) == 3, "relic route completes blueprint")
	check(Items.find_fragments(p, 19, D.BIOMES[0].id, true, 1) == 0, "no duplicate fragments after completion")


func _check_forge() -> void:
	var p := Hero.create()
	p.armor.body = "chain_hauberk"
	p.bag.append("marsh_wrap")
	p.armor_up.chain_hauberk = 3
	p.shards = 100
	var before: int = p.shards
	var cost := Forge.price(p, "marsh_wrap")
	check(Forge.candidates(p).size() == 1, "owned same-part armour offered")
	check(Forge.transfer(p, "chain_hauberk", "marsh_wrap"), "transfer succeeds")
	check(Items.upgrade_level(p, "chain_hauberk") == 2 and Items.upgrade_level(p, "marsh_wrap") == 1,
		"one level moved without creating a level")
	check(p.shards == before - cost, "only transfer fee deducted")
	check(not Forge.transfer(p, "chain_hauberk", "iron_sallet"), "different armour part rejected")
	check(not Forge.transfer(p, "chain_hauberk", "gambeson"), "unowned target rejected")
	check(not Forge.transfer(p, "marsh_wrap", "marsh_wrap"), "same-piece transfer rejected")
	p.shards = 0
	check(not Forge.transfer(p, "chain_hauberk", "marsh_wrap"), "cannot transfer without payment")
	check(Items.upgrade_level(p, "chain_hauberk") == 2 and Items.upgrade_level(p, "marsh_wrap") == 1,
		"failed transfer leaves levels intact")
	p.shards = 1000
	check(Forge.transfer(p, "chain_hauberk", "marsh_wrap"), "second transfer succeeds")
	check(Forge.transfer(p, "chain_hauberk", "marsh_wrap"), "third transfer succeeds")
	check(not Forge.transfer(p, "chain_hauberk", "marsh_wrap"), "empty source and full target reject transfer")
	check(Items.upgrade_level(p, "chain_hauberk") == 0 and Items.upgrade_level(p, "marsh_wrap") == 3,
		"source empty and destination capped at three")


func _check_menus() -> void:
	var g := FakeGame.new()
	var m := Menu.new()
	m.game = g
	var routes := m._build("routes")
	check(routes.size() == 4 and routes[0].has("tip"), "route menu shows three explained choices")
	routes[0].act.call()
	check(g.chosen == Endless.options(g.run_seed, 19, 5)[0], "route button sends selected route")
	g.player.armor.body = "chain_hauberk"
	g.player.bag.append("marsh_wrap")
	g.player.armor_up.chain_hauberk = 1
	g.player.shards = 100
	var shop := m._shop_items()
	check(shop.any(func(it: Dictionary) -> bool: return it.get("label", "") == g.L("forge_transfer")),
		"merchant offers transfer when armour qualifies")
	var forge := m._build("forge")
	check(forge.size() == 2 and forge[0].price == Forge.price(g.player, "marsh_wrap"),
		"forge menu shows source, target and current fee")
	forge[0].act.call()
	check(g.saves == 1 and Items.upgrade_level(g.player, "marsh_wrap") == 1,
		"forge purchase changes gear and saves immediately")
	m.free()
