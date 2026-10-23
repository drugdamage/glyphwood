## Items, equipment and the stats they give. The hero has one weapon slot, one
## throwing slot and CHARM_SLOTS charm slots (one more every fifth hero level);
## everything else found during a run sits in the bag.
## Names and descriptions are in strings_world.gd as "item_<id>" and "item_<id>_d".
extends RefCounted

const CHARM_SLOTS := 3
const START_WEAPON := "rusty_blade"
const START_THROW := "ink_knife"

## slot: "weapon", "throw" or "charm". price: shards in the shop (0 = never sold).
## Weapon stats: dmg (per hit), speed (attack rate multiplier), reach (hitbox scale),
## kind (how it looks in the hand, see renderer._draw_weapon) and class, which
## the skill branches favour: "heavy" (Bulwark), "light" (Artificer), "blade" (Shadow).
## Optional weapon traits: burn, crush (breaks shields), ink_hit (ink per hit), crit,
## chill, leech (share of max health healed per hit), execute (bonus damage to foes
## below EXECUTE_AT health) and sweep (the side cuts also reach behind the hero).
## Throwing weapons: dmg (fixed damage at hero level 1, grows with the hero's
## level, not with the melee weapon), ink (cost).
const ITEMS := {
	"rusty_blade": {"slot": "weapon", "glyph": "/", "color": Color(0.75, 0.7, 0.62), "price": 0,
		"dmg": 10, "speed": 1.0, "reach": 1.0, "kind": "sword", "class": "blade"},
	"glyph_saber": {"slot": "weapon", "glyph": "/", "color": Color(0.55, 0.95, 1.0), "price": 140,
		"dmg": 11, "speed": 1.55, "reach": 1.0, "kind": "sword", "class": "blade"},
	"greatblade": {"slot": "weapon", "glyph": "†", "color": Color(0.85, 0.85, 0.95), "price": 170,
		"dmg": 22, "speed": 0.72, "reach": 1.3, "kind": "great", "class": "heavy"},
	"hollow_spear": {"slot": "weapon", "glyph": "|", "color": Color(0.6, 0.75, 1.0), "price": 150,
		"dmg": 13, "speed": 1.0, "reach": 1.55, "kind": "spear", "class": "blade"},
	"ember_brand": {"slot": "weapon", "glyph": "/", "color": Color(1.0, 0.55, 0.25), "price": 190,
		"dmg": 13, "speed": 1.05, "reach": 1.05, "burn": true, "kind": "sword", "class": "blade"},
	"grave_maul": {"slot": "weapon", "glyph": "¶", "color": Color(0.7, 0.66, 0.6), "price": 200,
		"dmg": 27, "speed": 0.62, "reach": 1.2, "crush": true, "kind": "mace", "class": "heavy"},
	"widow_fangs": {"slot": "weapon", "glyph": "‡", "color": Color(0.75, 0.55, 0.95), "price": 160,
		"dmg": 8, "speed": 2.0, "reach": 0.78, "ink_hit": 1.5, "kind": "dagger", "class": "light"},
	"night_katana": {"slot": "weapon", "glyph": ")", "color": Color(0.9, 0.3, 0.35), "price": 230,
		"dmg": 14, "speed": 1.15, "reach": 1.12, "kind": "katana", "class": "blade"},
	"pilgrim_sword": {"slot": "weapon", "glyph": "/", "color": Color(0.82, 0.78, 0.66), "price": 150,
		"dmg": 15, "speed": 1.0, "reach": 1.12, "kind": "sword", "class": "blade"},
	"frost_brand": {"slot": "weapon", "glyph": "/", "color": Color(0.65, 0.88, 1.0), "price": 200,
		"dmg": 13, "speed": 1.05, "reach": 1.05, "chill": true, "kind": "sword", "class": "blade"},
	"bloodletter": {"slot": "weapon", "glyph": "!", "color": Color(0.9, 0.2, 0.25), "price": 210,
		"dmg": 9, "speed": 1.7, "reach": 1.08, "leech": 0.01, "kind": "rapier", "class": "blade"},
	"bone_scythe": {"slot": "weapon", "glyph": "Г", "color": Color(0.88, 0.84, 0.74), "price": 240,
		"dmg": 17, "speed": 0.85, "reach": 1.3, "sweep": true, "kind": "scythe", "class": "heavy"},
	"bell_halberd": {"slot": "weapon", "glyph": "ŧ", "color": Color(0.75, 0.7, 0.5), "price": 220,
		"dmg": 17, "speed": 0.74, "reach": 1.5, "kind": "halberd", "class": "heavy"},
	"headsman_axe": {"slot": "weapon", "glyph": "Þ", "color": Color(0.72, 0.68, 0.7), "price": 250,
		"dmg": 30, "speed": 0.58, "reach": 1.15, "execute": true, "kind": "axe", "class": "heavy"},
	"ink_knife": {"slot": "throw", "glyph": "»", "color": Color(0.65, 0.75, 1.0), "price": 0, "dmg": 14.0, "ink": 33.0},
	"bone_boomerang": {"slot": "throw", "glyph": "<", "color": Color(0.92, 0.86, 0.72), "price": 150, "dmg": 8.0, "ink": 33.0},
	"thorn_chakram": {"slot": "throw", "glyph": "✶", "color": Color(0.6, 0.95, 0.55), "price": 160, "dmg": 9.0, "ink": 33.0},
	"bile_flask": {"slot": "throw", "glyph": "ò", "color": Color(0.55, 0.9, 0.3), "price": 170, "dmg": 16.0, "ink": 49.5},
	"grave_javelin": {"slot": "throw", "glyph": "—", "color": Color(0.8, 0.74, 0.62), "price": 190, "dmg": 22.0, "ink": 49.5},
	"heart_glyph": {"slot": "charm", "glyph": "♥", "color": Color(1.0, 0.35, 0.45), "price": 110, "max_hp": 30},
	"phantom_step": {"slot": "charm", "glyph": "»", "color": Color(0.6, 0.85, 1.0), "price": 150, "dash_inv": true},
	"feather": {"slot": "charm", "glyph": "∫", "color": Color(0.95, 0.95, 0.8), "price": 160, "air_jumps": 1},
	"lodestone": {"slot": "charm", "glyph": "◊", "color": Color(0.75, 0.75, 0.85), "price": 60, "magnet": 3.0},
	"quickhand": {"slot": "charm", "glyph": "≈", "color": Color(1.0, 0.85, 0.45), "price": 120, "speed": 1.22},
	"fang": {"slot": "charm", "glyph": "v", "color": Color(1.0, 0.4, 0.4), "price": 130, "lifesteal": 0.12},
	"thorn_ring": {"slot": "charm", "glyph": "o", "color": Color(0.55, 0.9, 0.5), "price": 90, "thorns": 15},
	"lucky_coin": {"slot": "charm", "glyph": "¢", "color": Color(1.0, 0.85, 0.35), "price": 80, "shard_mult": 1.5},
	"inkwell": {"slot": "charm", "glyph": "¤", "color": Color(0.6, 0.6, 1.0), "price": 90, "ink_gain": 1.7},
	"stone_skin": {"slot": "charm", "glyph": "□", "color": Color(0.7, 0.7, 0.65), "price": 100, "inv_time": 1.6},
	"raven_quill": {"slot": "charm", "glyph": "ł", "color": Color(0.55, 0.6, 0.8), "price": 120, "run": 1.12},
	"iron_shroud": {"slot": "charm", "glyph": "Ω", "color": Color(0.62, 0.62, 0.7), "price": 140, "armor": 0.85},
	"blood_rosary": {"slot": "charm", "glyph": "†", "color": Color(0.85, 0.12, 0.15), "price": 120, "rage": 1.4},
	"black_candle": {"slot": "charm", "glyph": "ı", "color": Color(0.45, 0.4, 0.5), "price": 110, "crit_burn": true},
	"funeral_bell": {"slot": "charm", "glyph": "Δ", "color": Color(0.85, 0.75, 0.5), "price": 150, "toll": 1},
	"penitent_chain": {"slot": "charm", "glyph": "§", "color": Color(0.7, 0.6, 0.55), "price": 100, "chain": true},
	"saints_finger": {"slot": "charm", "glyph": "ƒ", "color": Color(0.95, 0.9, 0.75), "price": 110, "ink_cost": 0.75},
	"wraith_lantern": {"slot": "charm", "glyph": "ö", "color": Color(0.6, 0.95, 0.85), "price": 90, "orbs": 2.0},
	"ember_heart": {"slot": "charm", "glyph": "*", "color": Color(1.0, 0.5, 0.2), "price": 0, "dmg_mult": 1.25},
	"moon_lens": {"slot": "charm", "glyph": "(", "color": Color(0.75, 0.85, 1.0), "price": 0, "crit": 0.2},
	"root_crown": {"slot": "charm", "glyph": "w", "color": Color(0.5, 0.9, 0.5), "price": 0, "max_hp": 20, "regen": 1.8},
	"gallows_knot": {"slot": "charm", "glyph": "∞", "color": Color(0.75, 0.65, 0.45), "price": 0, "air_jumps": 1, "run": 1.06},
	"tide_pearl": {"slot": "charm", "glyph": "◦", "color": Color(0.55, 0.75, 1.0), "price": 0, "regen": 1.5, "boss_regen": true},
	"frost_crown": {"slot": "charm", "glyph": "♔", "color": Color(0.7, 0.9, 1.0), "price": 0, "chill": true, "dmg_mult": 1.1},
}

## Charms dropped by bosses (never in shops or chests).
const BOSS_DROPS := {"warden": "root_crown", "wraith": "moon_lens", "colossus": "ember_heart", "hangman": "gallows_knot",
	"abbess": "tide_pearl", "frost_king": "frost_crown"}

## Every SLOT_EVERY hero levels add a charm slot, up to MAX_CHARMS in all.
const SLOT_EVERY := 5
const MAX_CHARMS := 8
## Weapons with execute deal EXECUTE_MULT damage to foes below this share of health.
const EXECUTE_AT := 0.3
const EXECUTE_MULT := 1.6


static func charm_slots(p: Dictionary) -> int:
	return mini(MAX_CHARMS, CHARM_SLOTS + int(p.get("xp_level", 1) / SLOT_EVERY))


## True when reaching this hero level opens a new charm slot.
static func slot_level(level: int) -> bool:
	return level % SLOT_EVERY == 0 and CHARM_SLOTS + int(level / SLOT_EVERY) <= MAX_CHARMS


## Shop services that are not items: mend (full health), three upgrades that
## get more expensive each time they are bought, and forgetting learned skills.
static func service_price(p: Dictionary, id: String, level_num: int) -> int:
	match id:
		"mend":
			return 8 + 2 * level_num
		"vigor":
			return int(50.0 * pow(1.4, p.up_hp))
		"whet":
			return int(60.0 * pow(1.4, p.up_dmg))
		"haste":
			return int(70.0 * pow(1.45, p.get("up_spd", 0)))
		"forget":
			return 25 + 4 * level_num
	return 0


## Haste can be bought this many times (+5% running speed each).
const HASTE_MAX := 6


## What the merchant pays for an item from the bag.
static func sell_price(id: String) -> int:
	var d := def(id)
	if d.is_empty() or id == START_WEAPON or id == START_THROW:
		return 4
	if d.price <= 0:
		return 140
	return maxi(10, int(d.price * 0.4))


static func def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


## Combined stats from the equipped weapon, throwing weapon and charms.
static func stats(p: Dictionary) -> Dictionary:
	var w: Dictionary = def(p.weapon)
	var th: Dictionary = def(p.get("throw", START_THROW))
	var st := {
		"dmg": float(w.get("dmg", 10)), "speed": float(w.get("speed", 1.0)), "reach": float(w.get("reach", 1.0)),
		"burn": w.get("burn", false), "crush": w.get("crush", false), "ink_hit": float(w.get("ink_hit", 1.0)),
		"kind": w.get("kind", "sword"), "class": w.get("class", "blade"), "leech": float(w.get("leech", 0.0)),
		"execute": w.get("execute", false), "sweep": w.get("sweep", false),
		"throw_base": float(th.get("dmg", 14.0)), "throw_mult": 1.0, "throw_ink": float(th.get("ink", 33.0)),
		"max_hp": 0, "hp_mult": 1.0, "regen": 1.0, "dash_inv": false, "air_jumps": 0,
		"magnet": 1.0, "lifesteal": 0.0, "thorns": 0, "shard_mult": 1.0, "ink_gain": 1.0, "inv_time": 1.0,
		"dmg_mult": 1.0, "crit": float(w.get("crit", 0.0)), "crit_mult": 2.0, "run": 1.0, "armor": 1.0, "rage": 1.0,
		"crit_burn": false, "toll": 0, "dash_cd": 1.0, "chain": false, "ink_cost": 1.0, "orbs": 1.0, "boss_regen": false,
		"chill": w.get("chill", false),
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
		st.throw_mult *= float(c.get("dmg_mult", 1.0))
		st.crit += float(c.get("crit", 0.0))
		st.run *= float(c.get("run", 1.0))
		st.armor *= float(c.get("armor", 1.0))
		st.rage = maxf(st.rage, float(c.get("rage", 1.0)))
		st.toll += int(c.get("toll", 0))
		st.ink_cost *= float(c.get("ink_cost", 1.0))
		st.orbs = maxf(st.orbs, float(c.get("orbs", 1.0)))
		st.air_jumps += int(c.get("air_jumps", 0))
		for flag in ["dash_inv", "crit_burn", "chain", "boss_regen", "chill"]:
			if c.get(flag, false):
				st[flag] = true
	return st


static func owns(p: Dictionary, id: String) -> bool:
	return p.weapon == id or p.get("throw", "") == id or p.charms.has(id) or p.bag.has(id)


## Adds an item to the hero. Charms go straight into a free slot, weapons into
## the bag (or replace the starting one). Returns true if it was auto-equipped.
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
	if d.slot == "throw" and p.throw == START_THROW:
		p.bag.append(p.throw)
		p.throw = id
		return true
	p.bag.append(id)
	return false


## Equips or unequips an owned item. Returns false if nothing changed.
static func toggle(p: Dictionary, id: String) -> bool:
	var d := def(id)
	if d.is_empty():
		return false
	if d.slot == "weapon" or d.slot == "throw":
		var key: String = d.slot
		if p[key] == id or not p.bag.has(id):
			return false
		p.bag.erase(id)
		p.bag.append(p[key])
		p[key] = id
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


## Sells an item from the bag; returns the shards paid, or 0.
static func sell(p: Dictionary, id: String) -> int:
	if not p.bag.has(id):
		return 0
	p.bag.erase(id)
	var price := sell_price(id)
	p.shards += price
	return price


## Picks a random item the hero does not own yet, from those with a price.
static func random_unowned(p: Dictionary, rng: RandomNumberGenerator, exclude: Array = []) -> String:
	var pool: Array = []
	for id in ITEMS:
		if ITEMS[id].price > 0 and not owns(p, id) and not exclude.has(id):
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
