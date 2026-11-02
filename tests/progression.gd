## Isolated regression suite: no main scene, gameplay loop, window or user saves.
## godot --headless --path . --script tests/progression.gd
extends SceneTree

const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Merchant := preload("res://scripts/merchant.gd")
const Expeditions := preload("res://scripts/expeditions.gd")
const Level := preload("res://scripts/level.gd")
const D := preload("res://scripts/data.gd")
const BaseText := preload("res://scripts/strings.gd")
const MoreText := preload("res://scripts/strings_more.gd")
const Text := preload("res://scripts/strings_expeditions.gd")
const Gear := preload("res://scripts/gear_sprites.gd")
const Props := preload("res://scripts/props.gd")
const Menu := preload("res://scripts/menu.gd")
const Main := preload("res://scripts/main.gd")

var checks := 0
var failures := 0


class FakeGame extends RefCounted:
	var player := Hero.create()
	var biome: Dictionary = D.BIOMES[0]
	var shop_prop := {"stock": []}
	var level_num := 1
	var saves := 0
	var awards := 0
	var run_seed := 7
	var rng := RandomNumberGenerator.new()
	var particles: Array = []
	var pickups: Array = []
	var messages: Array = []

	func shake_add(_amount: float) -> void:
		pass

	func toast(value: String, _color: Color) -> void:
		messages.append(value)

	func choose_expedition(_route: Dictionary) -> void:
		pass

	func L(key: String) -> String:
		return BaseText.STRINGS.get(key, MoreText.STRINGS.get(key, Text.STRINGS.get(key, [key])))[0]

	func sfx(_id: String, _volume: float = 0.0) -> void:
		pass

	func save_run() -> void:
		saves += 1

	func item_found(_id: String, _equipped: bool) -> void:
		awards += 1


class FakeMenu extends RefCounted:
	var game := FakeGame.new()
	var message := ""

	func _message(value: String) -> void:
		message = value

	func _item_name(id: String) -> String:
		return id


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _initialize() -> void:
	_catalogs()
	_fragments()
	_chest_rewards()
	_transactions()
	_migration()
	_routes()
	_generation()
	_menu_entries()
	_localization()
	print("Progression regression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _catalogs() -> void:
	var seen: Array = []
	for bid in Merchant.CATALOGS:
		for id in Merchant.CATALOGS[bid]:
			check(Items.ITEMS.has(id), "catalog item exists: " + id)
			check(not seen.has(id), "exclusive biome catalog: " + id)
			seen.append(id)
	for id in Items.ITEMS:
		check(seen.has(id) == (Items.def(id).price > 0), "all and only saleable items in catalogs: " + id)
	for id in ["cinder_veil", "marsh_wrap", "choir_hood", "rime_mail"]:
		check(Gear.HEADS.has(id) or Gear.BODIES.has(id), "new armor has pixel art: " + id)
	check(Items.def("headsman_axe").dmg == 30, "existing axe damage preserved")
	check(Items.UPGRADE_MAX == 3 and Hero.ARMOR_FLOOR == 0.5, "existing armor cap preserved")


func _fragments() -> void:
	var p := Hero.create()
	p.research = "thorn_chakram"
	check(Merchant.collect(p, "wood", 2) == ["thorn_chakram", "thorn_chakram"], "targeted secret chest awards two pieces")
	check(not Merchant.unlocked(p, "thorn_chakram"), "two pieces cannot unlock")
	var found := Merchant.collect(p, "wood", 2)
	check(found == ["thorn_chakram", "glyph_saber"], "surplus moves to another local recipe")
	check(Merchant.unlocked(p, "thorn_chakram"), "third piece unlocks")
	check(not Merchant.unlocked(p, "headsman_axe"), "early loot cannot unlock late axe")
	check(Merchant.collect(p, "wood", 50).size() == 2, "completed local pool never produces duplicates")
	check(Merchant.collect(p, "wood", 1).is_empty(), "exhausted collection is safe")
	check(not Merchant.collect(p, "crypt", 1).has("thorn_chakram"), "foreign tracked recipe does not consume local pieces")
	var pr := {"kind": "chest", "pos": Vector2(64, 128), "open": false}
	Merchant.prepare_floor(p, 7, [pr])
	check(Merchant.claim_chest(p, pr), "first opening claims chest")
	check(not Merchant.claim_chest(p, pr), "double interaction cannot duplicate rewards")
	var restored := {"kind": "chest", "pos": Vector2(64, 128), "open": false}
	Merchant.prepare_floor(p, 7, [restored])
	check(restored.open, "reload restores chest ledger")
	Merchant.prepare_floor(p, 8, [])
	check(Merchant.claim_chest(p, restored), "same coordinates on next floor remain claimable")


func _chest_rewards() -> void:
	for scenario in [{"secret": false, "modifier": "", "pieces": 1},
		{"secret": true, "modifier": "", "pieces": 2}, {"secret": true, "modifier": "discovery", "pieces": 3}]:
		var g := FakeGame.new()
		g.biome = D.BIOMES[0].duplicate(true)
		g.biome.modifier = scenario.modifier
		g.rng.seed = 17
		var chest := {"kind": "chest", "pos": Vector2(80, 96), "open": false, "secret": scenario.secret}
		Merchant.prepare_floor(g.player, 1, [chest])
		Props.open_chest(g, chest)
		check(Merchant.pieces(g.player, "glyph_saber") == scenario.pieces, "actual chest interaction awards expected fragments")
		check(g.player.shards >= 18 and g.player.shards <= 30 and g.saves == 1, "chest shards and ledger saved together")
		var before := g.player.duplicate(true)
		Props.open_chest(g, chest)
		check(g.player == before and g.saves == 1, "actual repeat interaction cannot duplicate any loot")


func _transactions() -> void:
	var m := FakeMenu.new()
	var p: Dictionary = m.game.player
	p.shards = 5000
	Merchant.buy(m, "glyph_saber")
	check(p.shards == 5000 and not Items.owns(p, "glyph_saber"), "locked purchase spends no shards")
	check(p.research == "glyph_saber", "clicking locked item tracks it")
	Merchant.collect(p, "wood", 3)
	Merchant.buy(m, "glyph_saber")
	check(Items.owns(p, "glyph_saber") and p.shards == 4860, "completed blueprint can be purchased")
	Merchant.buy(m, "glyph_saber")
	check(p.shards == 4860 and m.game.awards == 1, "stale purchase cannot charge twice")
	p.fragments.headsman_axe = 3
	Merchant.buy(m, "headsman_axe")
	check(not Items.owns(p, "headsman_axe") and p.shards == 4860, "foreign catalog cannot be bought")
	m.game.biome = D.BIOMES[5]
	p.shards = 0
	Merchant.buy(m, "headsman_axe")
	check(not Items.owns(p, "headsman_axe") and p.shards == 0, "unlocked recipe still costs shards")
	p.shards = 1000
	Merchant.buy(m, "headsman_axe")
	check(Items.owns(p, "headsman_axe") and p.shards == 750, "local unlocked axe purchase")
	p.bag.append("rime_mail")
	Merchant.migrate(p)
	Items.sell(p, "rime_mail")
	check(Merchant.unlocked(p, "rime_mail"), "selling gear preserves its blueprint")
	p.up_spd = Items.HASTE_MAX
	var before: int = p.shards
	Merchant.buy(m, "haste")
	check(p.up_spd == Items.HASTE_MAX and p.shards == before, "stale haste purchase respects cap")
	check(m.game.saves >= 3, "transactions save immediately")


func _migration() -> void:
	var p := Hero.create()
	Items.give(p, "headsman_axe")
	for id in ["iron_sallet", "chain_hauberk", "iron_greaves"]:
		Items.give(p, id)
		p.armor_up[id] = 3
	Hero.refresh(p)
	var stats: Dictionary = p.st.duplicate(true)
	Merchant.migrate(p)
	Hero.refresh(p)
	check(p.st == stats, "migration preserves veteran combat stats and upgrades")
	check(p.fragments.headsman_axe == 3 and p.fragments.iron_sallet == 3, "legacy gear unlocks its blueprint")
	# Exercise the actual whitelist and ConfigFile serialization, entirely in memory.
	var cf := ConfigFile.new()
	var saved := {}
	p.research = "rime_mail"
	p.opened_chests = ["64:128"]
	p.loot_level = 31
	p.expedition = Expeditions.choices(123, 31, 0)[2]
	for key in Main.RUN_KEYS:
		saved[key] = p[key]
	cf.set_value("run", "player", saved)
	var loaded := ConfigFile.new()
	check(loaded.parse(cf.encode_to_text()) == OK, "progress serializes with ConfigFile")
	var restored := Hero.create()
	var data: Dictionary = loaded.get_value("run", "player")
	for key in Main.RUN_KEYS:
		restored[key] = data[key]
	check(restored.fragments == p.fragments and restored.research == p.research, "save roundtrip preserves collection")
	check(restored.opened_chests == p.opened_chests and restored.loot_level == 31, "save roundtrip preserves claims")
	check(restored.expedition == p.expedition, "save roundtrip preserves chosen route")
	var legacy := Hero.create()
	var b := Expeditions.biome(legacy, 5, 55)
	check(b.has("modifier") and legacy.expedition.level == 55, "legacy endless save resumes at its existing depth")


func _routes() -> void:
	var original: Array = D.BIOMES.duplicate(true)
	var p := Hero.create()
	for level in range(1, 19):
		check(Expeditions.biome(p, 123, level) == D.BIOMES[(level - 1) / 3], "first descent keeps biome order")
	for seed_value in range(12):
		var previous := 5
		for level in range(19, 49):
			var choices := Expeditions.choices(seed_value, level, previous)
			check(choices == Expeditions.choices(seed_value, level, previous), "route choices deterministic")
			var seen: Array = []
			for route in choices:
				check(Expeditions.valid(route, level), "valid route")
				check(route.primary != previous and not seen.has(route.primary), "three different destinations, no immediate repeat")
				seen.append(route.primary)
				p.expedition = route
				var b := Expeditions.biome(p, seed_value, level)
				check(b.foes.size() > D.BIOMES[route.primary].foes.size(), "visitor enemies join the pool")
				check(b.boss == D.BIOMES[route.primary].boss, "guardian matches selected biome")
			previous = choices[level % 3].primary
	check(D.BIOMES == original, "expedition palette and pool do not mutate campaign data")
	check(not Expeditions.valid({}, 19), "invalid saved route falls back safely")
	check(not Expeditions.valid({"level": 19, "primary": -1, "secondary": 2, "modifier": "hunt"}, 19), "invalid biome rejected")


func _generation() -> void:
	var p := Hero.create()
	for seed_value in range(20):
		for depth in [1, 3, 9, 18, 19, 21, 43]:
			var b := Expeditions.biome(p, seed_value, depth)
			var a := Level.new()
			var c := Level.new()
			var r1 := RandomNumberGenerator.new()
			var r2 := RandomNumberGenerator.new()
			r1.seed = hash([seed_value, depth])
			r2.seed = r1.seed
			a.build(depth, b, r1, depth > 18 or depth % 3 == 0)
			c.build(depth, b, r2, depth > 18 or depth % 3 == 0)
			check(a.tiles == c.tiles and a.props == c.props, "regeneration restores same terrain and chest coordinates")
			var shops := 0
			var rewards := 0
			var bosses := 0
			for pr in a.props:
				if pr.kind == "chest":
					rewards += 1
				if pr.kind == "shop":
					shops += 1
			for ar in a.arenas:
				if ar.boss:
					bosses += 1
				else:
					rewards += 1
			check(shops == 1, "merchant exists on every generated floor")
			if depth > 18:
				check(rewards > 0, "expedition has at least one fragment source")
				check(a.gw == 4 and a.gh == 3 and bosses == 1, "short expedition has exactly one guardian")
				check(not a.door_open, "expedition exit stays closed until guardian defeated")


func _menu_entries() -> void:
	var m := Menu.new()
	m.game = FakeGame.new()
	for b in D.BIOMES:
		m.game.biome = b
		var shop: Array = m._build("shop")
		check(shop.size() > Merchant.CATALOGS[b.id].size(), "actual menu builds local stock and services")
		for row in shop:
			check(row.has("act") and row.act.is_valid(), "shop callback bound")
	var journal: Array = m._build("recipes")
	check(journal.size() > 20 and journal[0].note.contains("0/3"), "actual journal shows incomplete blueprints")
	var routes: Array = m._build("expedition")
	check(routes.size() == 4, "route menu has three choices and back")
	for i in 3:
		check(routes[i].has("tip") and routes[i].act.is_valid(), "route explanation and callback present")
	m.free()


func _localization() -> void:
	for key in Text.STRINGS:
		check(Text.STRINGS[key].size() == 7, "seven translations: " + key)
		for value in Text.STRINGS[key]:
			check(not value.is_empty() and not value.contains("TODO"), "nonempty translation: " + key)
