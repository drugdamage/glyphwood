## Isolated route choice, expedition reward and armour transfer regressions.
extends SceneTree

const D := preload("res://scripts/data.gd")
const Endless := preload("res://scripts/endless.gd")
const Forge := preload("res://scripts/forge.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Level := preload("res://scripts/level.gd")
const Main := preload("res://scripts/main.gd")
const Menu := preload("res://scripts/menu.gd")
const Hone := preload("res://scripts/weapon_hone.gd")
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
	_check_hone()
	_check_relics()
	_check_scout()
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
			for scout in range(1, Endless.SCOUT_MAX + 1):
				var changed := Endless.options(seed_value, n, current, previous, scout)
				check(changed == Endless.options(seed_value, n, current, previous, scout), "scouted routes deterministic")
				check(changed.size() == 3 and changed != offers, "scouting changes available destinations")
				check(changed[0].primary not in [current, previous], "scouting still avoids recent biomes")
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
				check(b.boss == Endless.guardian_boss(route), "previewed guardian matches generated floor")
				check(b.boss == (D.BIOMES[route.echo_index].boss if route.mode == "restless"
					else D.BIOMES[route.primary].boss), "restless route changes the guardian")
				check(not Endless.valid(route, n + 1), "old route cannot affect next floor")
				if n == 19:
					var lv := Level.new()
					var again := Level.new()
					var rng := RandomNumberGenerator.new()
					var replay := RandomNumberGenerator.new()
					rng.seed = hash([seed_value, n])
					replay.seed = rng.seed
					lv.build(n, b, rng, true)
					again.build(n, b, replay, true)
					check(lv.tiles == again.tiles and lv.props == again.props,
						"chosen route rebuilds the same terrain and chest positions")
					check(lv.gw == (5 if route.mode == "relic" else 4) and lv.gh == 3,
						"relic route offers a wider short floor")
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


func _check_hone() -> void:
	var p := Hero.create()
	check(Main.RUN_KEYS.has("weapon_up") and p.has("weapon_up"), "honing survives saves and old saves default to empty")
	p.shards = 1000
	check(not Items.hone_weapon(p, Items.START_WEAPON), "starter weapon cannot replace found gear through honing")
	check(not Items.hone_weapon(p, "headsman_axe"), "cannot hone unowned weapon")
	p.bag.append("glyph_saber")
	check(Items.to_slot(p, "glyph_saber", 0), "found weapon equips from bag")
	Hero.refresh(p)
	var original: float = p.st.dmg
	var paid := 0
	for rank in Items.WEAPON_HONE_MAX:
		var cost := Items.weapon_hone_price(p, "glyph_saber")
		paid += cost
		check(Items.hone_weapon(p, "glyph_saber"), "owned weapon hones at rank %d" % rank)
		Hero.refresh(p)
		check(p.st.dmg == original + Items.WEAPON_HONE_DAMAGE * (rank + 1), "damage increases once per rank")
	check(p.shards == 1000 - paid, "honing charges the shown prices")
	check(not Items.hone_weapon(p, "glyph_saber"), "honing stops at three ranks")
	check(p.shards == 1000 - paid, "failed hone does not charge")
	check(Items.to_slot(p, "rusty_blade", 0), "switch to another weapon")
	Hero.refresh(p)
	check(p.st.dmg == Items.def("rusty_blade").dmg, "honing belongs only to its weapon")
	var sale := Items.sell_price("glyph_saber", p)
	check(sale > int(Items.def("glyph_saber").price * 0.4), "sale includes a partial honing refund")
	check(Items.sell(p, "glyph_saber") == sale and Items.weapon_hone_level(p, "glyph_saber") == 0,
		"selling removes honing and pays the quoted refund")
	check(Items.give(p, "glyph_saber"), "a new copy can be acquired after sale")
	Hero.refresh(p)
	check(p.st.dmg == original, "repurchased weapon does not regain sold honing")


func _check_relics() -> void:
	var p := Hero.create()
	var first := Items.claim_boss_relic(p, "warden")
	check(first.get("id", "") == "root_crown" and Items.owns(p, "root_crown"), "first guardian awards its relic")
	check(Items.claim_boss_relic(p, "warden").is_empty(), "repeat guardian gives no phantom relic")
	check(Items.claim_boss_relic(p, "unknown").is_empty(), "ordinary foes have no boss reward")


func _check_scout() -> void:
	var g := FakeGame.new()
	var m := Menu.new()
	m.game = g
	check(Main.RUN_KEYS.has("route_refresh") and g.player.route_refresh == 0, "scout count saves and defaults to zero")
	g.level_num = 17
	check(Endless.scout_shop_item(m).is_empty(), "route scouting starts only after the final story biome")
	g.level_num = 18
	check(Endless.scout_shop_item(m).price == 35, "first scout has quoted price")
	var before := Endless.options(g.run_seed, 19, 5)
	g.player.shards = 34
	Endless.buy_scout(m)
	check(g.player.shards == 34 and g.player.route_refresh == 0 and g.saves == 0,
		"scouting cannot charge an underfunded hero")
	g.player.shards = 100
	Endless.buy_scout(m)
	check(g.player.shards == 65 and g.player.route_refresh == 1 and g.saves == 1,
		"first scout charges and saves exactly once")
	check(Endless.options(g.run_seed, 19, 5, -1, 1) != before, "scouting changes next route menu")
	check(Endless.scout_shop_item(m).price == 60, "second scout costs more")
	Endless.buy_scout(m)
	check(g.player.shards == 5 and g.player.route_refresh == 2 and g.saves == 2,
		"second scout charges and saves exactly once")
	check(Endless.scout_shop_item(m).is_empty(), "no third scout in the same floor")
	Endless.buy_scout(m)
	check(g.player.shards == 5 and g.saves == 2, "direct repeat call cannot charge beyond limit")
	check(not Endless.select_route(g.player, before[0], g.run_seed, 18, 5),
		"an old offer cannot be chosen after scouting")
	var chosen: Dictionary = Endless.options(g.run_seed, 19, 5, -1, 2)[0]
	check(Endless.select_route(g.player, chosen, g.run_seed, 18, 5), "scouted route can be selected")
	check(g.player.route == chosen and g.player.route_refresh == 0,
		"selection preserves the route and resets scout count for the next floor")
	m.free()


func _check_menus() -> void:
	var g := FakeGame.new()
	var m := Menu.new()
	m.game = g
	var routes := m._build("routes")
	check(routes.size() == 4 and routes[0].has("tip"), "route menu shows three explained choices")
	check(routes[1].tip.contains(g.L("route_guardian") % g.L("boss_" + Endless.guardian_boss(
		Endless.options(g.run_seed, 19, 5)[1]))), "route explains the guardian before selection")
	routes[0].act.call()
	check(g.chosen == Endless.options(g.run_seed, 19, 5)[0], "route button sends selected route")
	g.player.armor.body = "chain_hauberk"
	g.player.bag.append("marsh_wrap")
	g.player.armor_up.chain_hauberk = 1
	g.player.shards = 100
	var shop := m._shop_items()
	check(shop.any(func(it: Dictionary) -> bool: return it.get("label", "") == g.L("forge_button")),
		"merchant offers transfer when armour qualifies")
	var forge := m._build("forge")
	check(forge.size() == 2 and forge[0].price == Forge.price(g.player, "marsh_wrap"),
		"forge menu shows source, target and current fee")
	forge[0].act.call()
	check(g.saves == 1 and Items.upgrade_level(g.player, "marsh_wrap") == 1,
		"forge purchase changes gear and saves immediately")
	g.player.bag.append("glyph_saber")
	g.player.shards = 1000
	var hone := m._build("hone")
	check(hone.size() == 2 and hone[0].price == Items.weapon_hone_price(g.player, "glyph_saber"),
		"honing menu quotes its exact price")
	hone[0].act.call()
	check(g.saves == 2 and Items.weapon_hone_level(g.player, "glyph_saber") == 1,
		"honing menu purchase updates gear and save")
	m.free()
