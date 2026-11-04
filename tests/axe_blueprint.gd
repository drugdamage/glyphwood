## Exercises chest fragments, the merchant gate and save serialization.
extends SceneTree

const D := preload("res://scripts/data.gd")
const Hero := preload("res://scripts/hero.gd")
const Items := preload("res://scripts/items.gd")
const Main := preload("res://scripts/main.gd")
const Menu := preload("res://scripts/menu.gd")
const Props := preload("res://scripts/props.gd")
const T := preload("res://scripts/strings.gd")
const T2 := preload("res://scripts/strings_more.gd")

var failures := 0


class FakeGame extends RefCounted:
	var player := Hero.create()
	var biome: Dictionary = D.BIOMES[5]
	var level_num := 16
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
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _initialize() -> void:
	var g := FakeGame.new()
	g.rng.seed = 41
	g.player.shards = 500
	var merchant := {"kind": "shop", "stock": []}
	Props.interact(g, merchant)
	check(merchant.stock.has(Items.AXE_BLUEPRINT) and merchant.stock.size() == 3, "Crypt merchant displays the axe")
	var m := Menu.new()
	m.game = g
	var rows: Array = m._shop_items()
	check(rows[0].id == Items.AXE_BLUEPRINT and rows[0].note.contains("0/3"), "shop shows locked blueprint progress")
	m._buy(Items.AXE_BLUEPRINT)
	check(g.player.shards == 500 and not Items.owns(g.player, Items.AXE_BLUEPRINT), "locked purchase changes no gear or money")
	var secret := {"kind": "chest", "pos": Vector2.ZERO, "open": false, "secret": true}
	Props.open_chest(g, secret)
	check(g.player.axe_fragments == 2 and g.saves == 1, "hidden chest gives two saved fragments")
	check(m._shop_items()[0].note.contains("2/3"), "shop updates progress without reopening the floor")
	var ordinary := {"kind": "chest", "pos": Vector2(20, 0), "open": false}
	Props.open_chest(g, ordinary)
	check(g.player.axe_fragments == 2, "same floor cannot exceed two fragments")
	var cf := ConfigFile.new()
	var saved := {}
	for key in Main.RUN_KEYS:
		saved[key] = g.player[key]
	cf.set_value("run", "player", saved)
	var restored := ConfigFile.new()
	check(restored.parse(cf.encode_to_text()) == OK, "progress serializes")
	g.player = Hero.create()
	for key in Main.RUN_KEYS:
		g.player[key] = restored.get_value("run", "player")[key]
	Props.open_chest(g, {"kind": "chest", "pos": Vector2(40, 0), "open": false})
	check(g.player.axe_fragments == 2, "reload cannot farm more fragments on same floor")
	g.level_num = 17
	Props.open_chest(g, {"kind": "chest", "pos": Vector2(60, 0), "open": false})
	check(Items.axe_ready(g.player) and g.player.axe_fragments == 3, "next floor completes blueprint")
	check(not m._shop_items()[0].has("note"), "shop removes lock after third fragment")
	m._buy(Items.AXE_BLUEPRINT)
	check(Items.owns(g.player, Items.AXE_BLUEPRINT) and g.player.shards == 250, "completed axe can be purchased at existing price")
	m._buy(Items.AXE_BLUEPRINT)
	check(g.player.shards == 250, "stale selection cannot charge twice")
	m.free()
	print("Axe blueprint: %d failures" % failures)
	quit(1 if failures else 0)
