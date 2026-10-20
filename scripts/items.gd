## Items, equipment and the stats they give. The hero has one weapon slot and
## CHARM_SLOTS charm slots (one more at levels 10 and 20); everything else found
## during a run sits in the bag.
## Names and descriptions are in strings.gd as "item_<id>" and "item_<id>_d".
extends RefCounted

const CHARM_SLOTS := 3
const START_WEAPON := "rusty_blade"

## slot: "weapon" or "charm". price: shards in the shop (0 = never sold).
## Weapon stats: dmg (per hit), speed (attack rate multiplier), reach (hitbox scale).
const ITEMS := {
	"rusty_blade": {"slot": "weapon", "glyph": "/", "color": Color(0.75, 0.7, 0.62), "price": 0,
		"dmg": 10, "speed": 1.0, "reach": 1.0},
	"glyph_saber": {"slot": "weapon", "glyph": "/", "color": Color(0.55, 0.95, 1.0), "price": 140,
		"dmg": 13, "speed": 1.2, "reach": 1.0},
	"greatblade": {"slot": "weapon", "glyph": "†", "color": Color(0.85, 0.85, 0.95), "price": 170,
		"dmg": 22, "speed": 0.72, "reach": 1.3},
	"hollow_spear": {"slot": "weapon", "glyph": "|", "color": Color(0.6, 0.75, 1.0), "price": 150,
		"dmg": 12, "speed": 1.0, "reach": 1.55},
	"ember_brand": {"slot": "weapon", "glyph": "/", "color": Color(1.0, 0.55, 0.25), "price": 190,
		"dmg": 12, "speed": 1.05, "reach": 1.05, "burn": true},
	"heart_glyph": {"slot": "charm", "glyph": "♥", "color": Color(1.0, 0.35, 0.45), "price": 110, "max_hp": 30},
	"phantom_step": {"slot": "charm", "glyph": "»", "color": Color(0.6, 0.85, 1.0), "price": 150, "dash_inv": true},
	"feather": {"slot": "charm", "glyph": "∫", "color": Color(0.95, 0.95, 0.8), "price": 160, "double_jump": true},
	"lodestone": {"slot": "charm", "glyph": "◊", "color": Color(0.75, 0.75, 0.85), "price": 60, "magnet": 3.0},
	"quickhand": {"slot": "charm", "glyph": "≈", "color": Color(1.0, 0.85, 0.45), "price": 120, "speed": 1.22},
	"fang": {"slot": "charm", "glyph": "v", "color": Color(1.0, 0.4, 0.4), "price": 130, "lifesteal": 0.12},
	"thorn_ring": {"slot": "charm", "glyph": "o", "color": Color(0.55, 0.9, 0.5), "price": 90, "thorns": 15},
	"lucky_coin": {"slot": "charm", "glyph": "¢", "color": Color(1.0, 0.85, 0.35), "price": 80, "shard_mult": 1.5},
	"inkwell": {"slot": "charm", "glyph": "¤", "color": Color(0.6, 0.6, 1.0), "price": 90, "ink_gain": 1.7},
	"stone_skin": {"slot": "charm", "glyph": "□", "color": Color(0.7, 0.7, 0.65), "price": 100, "inv_time": 1.6},
	"ember_heart": {"slot": "charm", "glyph": "*", "color": Color(1.0, 0.5, 0.2), "price": 0, "dmg_mult": 1.25},
	"moon_lens": {"slot": "charm", "glyph": "(", "color": Color(0.75, 0.85, 1.0), "price": 0, "crit": 0.2},
	"root_crown": {"slot": "charm", "glyph": "w", "color": Color(0.5, 0.9, 0.5), "price": 0, "max_hp": 20, "regen": 1.8},
}

## Charms dropped by bosses (never in shops or chests).
const BOSS_DROPS := {"warden": "root_crown", "wraith": "moon_lens", "colossus": "ember_heart"}

## Hero levels that add a charm slot.
const SLOT_LEVELS := [10, 20]


static func charm_slots(p: Dictionary) -> int:
	var n := CHARM_SLOTS
	for lv in SLOT_LEVELS:
		if p.get("xp_level", 1) >= lv:
			n += 1
	return n


## Shop services that are not items: mend (full health) and two upgrades that
## get more expensive each time they are bought.
static func service_price(p: Dictionary, id: String, level_num: int) -> int:
	match id:
		"mend":
			return 8 + 2 * level_num
		"vigor":
			return int(50.0 * pow(1.4, p.up_hp))
		"whet":
			return int(60.0 * pow(1.4, p.up_dmg))
	return 0


static func def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


## Combined stats from the equipped weapon and charms.
static func stats(p: Dictionary) -> Dictionary:
	var w: Dictionary = def(p.weapon)
	var st := {
		"dmg": float(w.get("dmg", 10)), "speed": float(w.get("speed", 1.0)), "reach": float(w.get("reach", 1.0)),
		"burn": w.get("burn", false), "max_hp": 0, "regen": 1.0, "dash_inv": false, "double_jump": false,
		"magnet": 1.0, "lifesteal": 0.0, "thorns": 0, "shard_mult": 1.0, "ink_gain": 1.0, "inv_time": 1.0,
		"dmg_mult": 1.0, "crit": 0.0,
	}
	for id in p.charms:
		var c: Dictionary = def(id)
		st.max_hp += int(c.get("max_hp", 0))
		st.regen *= float(c.get("regen", 1.0))
		st.speed *= float(c.get("speed", 1.0))
		st.magnet = maxf(st.magnet, float(c.get("magnet", 1.0)))
		st.lifesteal += float(c.get("lifesteal", 0.0))
		st.thorns += int(c.get("thorns", 0))
		st.shard_mult *= float(c.get("shard_mult", 1.0))
		st.ink_gain *= float(c.get("ink_gain", 1.0))
		st.inv_time *= float(c.get("inv_time", 1.0))
		st.dmg_mult *= float(c.get("dmg_mult", 1.0))
		st.crit += float(c.get("crit", 0.0))
		if c.get("dash_inv", false):
			st.dash_inv = true
		if c.get("double_jump", false):
			st.double_jump = true
	return st


static func owns(p: Dictionary, id: String) -> bool:
	return p.weapon == id or p.charms.has(id) or p.bag.has(id)


## Adds an item to the hero. Charms go straight into a free slot, weapons into the
## bag (or replace the starting blade). Returns true if it was auto-equipped.
static func give(p: Dictionary, id: String) -> bool:
	var d := def(id)
	if d.is_empty() or owns(p, id):
		return false
	if d.slot == "charm" and p.charms.size() < charm_slots(p):
		p.charms.append(id)
		return true
	if d.slot == "weapon" and p.weapon == START_WEAPON:
		p.bag.append(p.weapon)
		p.weapon = id
		return true
	p.bag.append(id)
	return false


## Equips or unequips an owned item. Returns false if nothing changed.
static func toggle(p: Dictionary, id: String) -> bool:
	var d := def(id)
	if d.is_empty():
		return false
	if d.slot == "weapon":
		if p.weapon == id or not p.bag.has(id):
			return false
		p.bag.erase(id)
		p.bag.append(p.weapon)
		p.weapon = id
		return true
	if p.charms.has(id):
		p.charms.erase(id)
		p.bag.append(id)
		return true
	if p.charms.size() >= charm_slots(p) or not p.bag.has(id):
		return false
	p.bag.erase(id)
	p.charms.append(id)
	return true


## Picks a random item the hero does not own yet, from those with a price.
static func random_unowned(p: Dictionary, rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var pool: Array = []
	for id in ITEMS:
		if ITEMS[id].price > 0 and not owns(p, id) and not exclude.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
