## Biome collections, persistent blueprints and merchant transactions.
## Fragments unlock a recipe; shards still pay for the finished item.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const Inventory := preload("res://scripts/inventory.gd")
const Hero := preload("res://scripts/hero.gd")
const Skills := preload("res://scripts/skills.gd")

const PIECES := 3
const BASIC := ["pilgrim_sword", "pilgrim_hood", "gambeson", "wanderer_boots"]
const CATALOGS := {
	"wood": ["pilgrim_sword", "glyph_saber", "thorn_chakram", "pilgrim_hood", "gambeson", "wanderer_boots",
		"feather", "lodestone", "thorn_ring"],
	"hollow": ["hollow_spear", "grave_maul", "bone_boomerang", "iron_sallet", "chain_hauberk", "iron_greaves",
		"inkwell", "stone_skin", "iron_shroud"],
	"ember": ["ember_brand", "greatblade", "cinder_veil", "quickhand", "black_candle", "heart_glyph"],
	"mire": ["widow_fangs", "bloodletter", "bile_flask", "plague_mask", "thorned_sabatons", "marsh_wrap", "fang", "lucky_coin"],
	"cathedral": ["bell_halberd", "bone_scythe", "grave_javelin", "cathedral_plate", "choir_hood",
		"funeral_bell", "saints_finger", "penitent_chain"],
	"crypt": ["night_katana", "frost_brand", "headsman_axe", "rime_mail", "phantom_step", "raven_quill", "blood_rosary", "wraith_lantern"],
}


static func needs_recipe(id: String) -> bool:
	return Items.def(id).get("slot", "") in ["weapon", "armor", "throw"] and not BASIC.has(id) and Items.def(id).price > 0


static func pieces(p: Dictionary, id: String) -> int:
	return clampi(int(p.get("fragments", {}).get(id, 0)), 0, PIECES)


static func unlocked(p: Dictionary, id: String) -> bool:
	return not needs_recipe(id) or pieces(p, id) >= PIECES or Items.owns(p, id)


## Old worlds keep every owned item and its recipe, including items in the bag.
static func migrate(p: Dictionary) -> void:
	for id in Items.ITEMS:
		if needs_recipe(id) and Items.owns(p, id):
			p.fragments[id] = PIECES


static func stock(p: Dictionary, biome_id: String) -> Array:
	var out: Array = []
	for id in CATALOGS.get(biome_id, []):
		if not Items.owns(p, id):
			out.append(id)
	return out


## Finish the tracked local recipe first, then the most complete one.
## No duplicate fragments: surplus goes into the next unfinished recipe.
static func collect(p: Dictionary, biome_id: String, amount: int) -> Array:
	var found: Array = []
	for k in amount:
		var best := ""
		for id in CATALOGS.get(biome_id, []):
			if not needs_recipe(id) or unlocked(p, id):
				continue
			if id == p.get("research", ""):
				best = id
				break
			if best == "" or pieces(p, id) > pieces(p, best):
				best = id
		if best == "":
			break
		p.fragments[best] = pieces(p, best) + 1
		found.append(best)
	return found


static func chest_key(pr: Dictionary) -> String:
	return "%d:%d" % [roundi(pr.pos.x), roundi(pr.pos.y)]


## Only the current floor needs a ledger. Reopening a world cannot farm pieces.
static func prepare_floor(p: Dictionary, level: int, props: Array) -> void:
	if p.get("loot_level", -1) != level:
		p.loot_level = level
		p.opened_chests = []
	for pr in props:
		if pr.kind == "chest" and p.opened_chests.has(chest_key(pr)):
			pr.open = true


static func claim_chest(p: Dictionary, pr: Dictionary) -> bool:
	var key := chest_key(pr)
	pr.open = true
	if p.opened_chests.has(key):
		return false
	p.opened_chests.append(key)
	return true


static func notify_fragments(g, found: Array) -> void:
	var seen: Array = []
	for id in found:
		if seen.has(id):
			continue
		seen.append(id)
		var message: String = g.L("recipe_ready") % g.L("item_" + id) if pieces(g.player, id) == PIECES else \
			g.L("recipe_found") % [g.L("item_" + id), pieces(g.player, id), PIECES]
		g.toast(message, Items.def(id).color)


static func track(m, id: String) -> void:
	if unlocked(m.game.player, id):
		m._message(m.game.L("recipe_unlocked"))
		return
	m.game.player.research = id
	m.game.save_run()
	m._message(m.game.L("recipe_tracking") % m._item_name(id))


static func collection(m) -> Array:
	var out: Array = []
	var p: Dictionary = m.game.player
	for biome_id in CATALOGS:
		for id in CATALOGS[biome_id]:
			if not needs_recipe(id):
				continue
			out.append({"type": "buy", "id": id, "price": 0, "act": track.bind(m, id), "collection": true,
				"note": m.game.L("biome_" + biome_id) + " · " + progress(m, p, id),
				"tip": Inventory.numbers(m, p, id)})
	out.append(m._btn(m.game.L("m_back"), m.close))
	return out


static func progress(m, p: Dictionary, id: String) -> String:
	if unlocked(p, id):
		return m.game.L("recipe_unlocked")
	var label: String = m.game.L("recipe_progress") % [pieces(p, id), PIECES]
	return ("◆ " if p.get("research", "") == id else "") + label


static func shop_items(m) -> Array:
	var g = m.game
	var p: Dictionary = g.player
	var out: Array = []
	# Derive stock afresh: newly completed recipes appear without rerolling.
	g.shop_prop.stock = stock(p, g.biome.id)
	for id in g.shop_prop.stock:
		var locked := not unlocked(p, id)
		var it := {"type": "buy", "id": id, "price": Items.def(id).price, "act": buy.bind(m, id), "locked": locked}
		if locked:
			it.note = progress(m, p, id)
			it.tip = Inventory.numbers(m, p, id) + "\n" + g.L("recipe_help")
		out.append(it)
	for id in ["mend", "vigor", "whet", "haste", "forget"]:
		if (id == "haste" and p.up_spd >= Items.HASTE_MAX) or (id == "forget" and Skills.spent(p) == 0):
			continue
		var note: String = g.L("shop_" + id + "_d")
		match id:
			"mend": note = "%d / %d" % [p.hp, p.max_hp]
			"vigor": note = note % p.up_hp
			"whet": note = note % p.up_dmg
			"haste": note = note % [p.up_spd, Items.HASTE_MAX]
		out.append({"type": "buy", "id": id, "price": Items.service_price(p, id, g.level_num), "act": buy.bind(m, id),
			"label": g.L("shop_" + id), "color": Color(0.7, 0.85, 0.9), "note": note})
	out.append(m._btn(g.L("recipes"), m.open.bind("recipes")))
	if not p.bag.is_empty():
		out.append(m._btn(g.L("shop_sell"), m.open.bind("sell"), {"note": str(p.bag.size())}))
	out.append(m._btn(g.L("m_leave"), m.close))
	return out


static func buy(m, id: String) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var service: bool = id in ["mend", "vigor", "whet", "haste", "forget"]
	if not service:
		if not stock(p, g.biome.id).has(id):
			return
		if not unlocked(p, id):
			track(m, id)
			return
	if (id == "haste" and p.up_spd >= Items.HASTE_MAX) or (id == "forget" and Skills.spent(p) == 0):
		return
	var price: int = Items.service_price(p, id, g.level_num) if service else Items.def(id).price
	if id == "mend" and p.hp >= p.max_hp:
		g.sfx("error", -6.0)
		m._message(g.L("shop_full"))
		return
	if p.shards < price:
		g.sfx("error", -6.0)
		m._message(g.L("shop_poor"))
		return
	p.shards -= price
	g.sfx("buy")
	match id:
		"mend": p.hp = p.max_hp
		"vigor":
			p.up_hp += 1
			Hero.refresh(p)
			p.hp = mini(p.max_hp, p.hp + 10)
		"whet": p.up_dmg += 1
		"haste": p.up_spd += 1
		"forget":
			Skills.forget_all(p)
			m._message(g.L("shop_forgot"))
		_:
			var equipped := Items.give(p, id)
			g.item_found(id, equipped)
	Hero.refresh(p)
	g.save_run()
