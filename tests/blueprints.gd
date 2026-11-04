## Isolated blueprint, shop, old-save and armour checks; no game scene.
extends SceneTree

const D := preload("res://scripts/data.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear_sprites.gd")
const Inventory := preload("res://scripts/inventory.gd")
const Main := preload("res://scripts/main.gd")
const Menu := preload("res://scripts/menu.gd")
const Props := preload("res://scripts/props.gd")
const T := preload("res://scripts/strings.gd")
const T2 := preload("res://scripts/strings_more.gd")

var failures := 0
var checks := 0


class FakeGame extends RefCounted:
	var player := Hero.create()
	var biome: Dictionary = D.BIOMES[0]
	var level_num := 1
	var rng := RandomNumberGenerator.new()
	var shop_prop := {"stock": []}
	var particles: Array = []
	var shards: Array = []
	var pickups: Array = []
	var saves := 0
	var awards := 0
	var messages: Array = []

	func L(key: String) -> String:
		return T.STRINGS.get(key, T2.STRINGS.get(key, [key]))[0]

	func sfx(_kind: String, _volume: float = 0.0, _pitch: float = 1.0) -> void:
		pass

	func shake_add(_amount: float) -> void:
		pass

	func toast(message: String, _color: Color) -> void:
		messages.append(message)

	func save_run() -> void:
		saves += 1

	func item_found(_id: String, _equipped: bool) -> void:
		awards += 1

	func open_shop(pr: Dictionary) -> void:
		shop_prop = pr


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _initialize() -> void:
	for i in D.BIOMES.size():
		_check_biome(i)
	_check_migration()
	_check_armour()
	for key in ["blueprint_progress", "blueprint_found", "blueprint_hint", "endless_begin", "endless_floor",
		"item_marsh_wrap", "item_marsh_wrap_d", "item_rime_mail", "item_rime_mail_d"]:
		check(T2.STRINGS[key].size() == 7, "seven translations: " + key)
	print("Blueprints: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_biome(i: int) -> void:
	var g := FakeGame.new()
	g.biome = D.BIOMES[i]
	g.level_num = i * 3 + 1
	g.rng.seed = i + 41
	g.player.shards = 500
	var signature: String = Items.BLUEPRINTS[g.biome.id]
	var merchant := {"kind": "shop", "stock": []}
	Props.interact(g, merchant)
	check(merchant.stock.size() == 3 and merchant.stock[0] == signature, "signature displayed in local merchant")
	var m := Menu.new()
	m.game = g
	check(m._shop_items()[0].note.contains("0/3"), "locked row shows progress")
	m._buy(signature)
	check(g.player.shards == 500 and not Items.owns(g.player, signature), "locked purchase refused")
	for k in 15:
		check(Items.random_unowned(g.player, g.rng, g.biome.id) != signature, "signature never drops outright")
	Props.open_chest(g, {"kind": "chest", "pos": Vector2.ZERO, "open": false, "secret": true})
	check(Items.fragment_count(g.player, signature) == 2 and g.saves >= 1, "secret chest awards and saves two pieces")
	Props.open_chest(g, {"kind": "chest", "pos": Vector2(20, 0), "open": false})
	check(Items.fragment_count(g.player, signature) == 2, "floor limit applies")
	var cf := ConfigFile.new()
	var saved := {}
	for key in Main.RUN_KEYS:
		saved[key] = g.player[key]
	cf.set_value("run", "player", saved)
	var loaded := ConfigFile.new()
	check(loaded.parse(cf.encode_to_text()) == OK, "progress serializes")
	var data: Dictionary = loaded.get_value("run", "player", {})
	g.player = Hero.create()
	for key in Main.RUN_KEYS:
		g.player[key] = data[key]
	Props.open_chest(g, {"kind": "chest", "pos": Vector2(40, 0), "open": false})
	check(Items.fragment_count(g.player, signature) == 2, "same floor cannot be farmed after reload")
	g.level_num += 1
	Props.open_chest(g, {"kind": "chest", "pos": Vector2(60, 0), "open": false})
	check(Items.blueprint_ready(g.player, signature), "next floor completes blueprint")
	check(not m._shop_items()[0].has("note"), "shop reflects completed blueprint")
	m._buy(signature)
	check(Items.owns(g.player, signature) and g.player.shards == 500 - Items.def(signature).price,
		"completed blueprint buys at original price")
	var money: int = g.player.shards
	m._buy(signature)
	check(g.player.shards == money, "stale purchase cannot charge twice")
	m.free()


func _check_migration() -> void:
	var p := Hero.create()
	Items.migrate_blueprints(p, {"axe_fragments": 2, "axe_fragment_level": 16, "axe_fragment_floor": 2})
	check(p.fragments.headsman_axe == 2 and p.fragment_floor == 2, "pilot axe progress survives upgrade")
	Items.give(p, "cathedral_plate")
	Hero.refresh(p)
	Items.migrate_blueprints(p, {})
	check(p.fragments.cathedral_plate == 3, "previously owned signature gear is ready")
	var before: Dictionary = p.st.duplicate(true)
	Hero.refresh(p)
	check(p.st == before, "migration leaves combat stats intact")


func _check_armour() -> void:
	var p := Hero.create()
	for id in ["marsh_wrap", "rime_mail"]:
		check(Gear.BODIES.has(id), "new armour has sprite")
		check(Items.def(id).price > 0 and Items.BIOME_GOODS.values().any(func(goods: Array): return goods.has(id)),
			"new armour belongs to one biome shop")
	check(Items.def("marsh_wrap").run > 1.0 and Items.def("marsh_wrap").crit > 0.0,
		"marsh armour trades protection for speed and crit")
	check(Items.def("rime_mail").dash_cd < 1.0 and Items.def("rime_mail").run > 1.0,
		"rime armour improves movement and dash recovery")
	check(Items.def("iron_sallet").armor == 0.92 and Items.UPGRADE_MAX == 3, "old iron and reforge numbers unchanged")
