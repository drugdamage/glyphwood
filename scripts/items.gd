## Items, equipment and the stats they give. The hero carries up to
## BELT_SLOTS weapons on a belt (number keys take one in hand, the swap key
## the next), one throwing slot, three armour
## pieces (head, body, legs) that can be reforged for shards, and CHARM_SLOTS
## charm slots (one more every fifth hero level); everything else found during
## a run sits in the bag.
## Names and descriptions are in strings_world.gd as "item_<id>" and "item_<id>_d".
extends RefCounted

const CHARM_SLOTS := 3
const BELT_SLOTS := 3
const START_WEAPON := "rusty_blade"
const START_THROW := "ink_knife"

## slot: "weapon", "throw", "armor" or "charm". price: shards in the shop (0 = never sold).
## Weapon stats: dmg (per hit), speed (attack rate multiplier), reach (hitbox scale),
## kind (how it looks in the hand, see renderer._draw_weapon) and class, which
## the skill branches favour: "heavy" (Bulwark), "light" (Artificer), "blade" (Shadow).
## Optional weapon traits: burn, crush (breaks shields), ink_hit (ink per hit), crit,
## chill, leech (share of max health healed per hit), execute (bonus damage to foes
## below EXECUTE_AT health) and sweep (the side cuts also reach behind the hero).
## Throwing weapons: dmg (fixed damage at hero level 1, grows with the hero's
## level, not with the melee weapon), ink (cost).
## Armour: part ("head", "body" or "legs"), armor (share of damage still taken;
## reforging cuts the rest), and what it weighs: run (speed) and dash_cd. The
## colour also dyes that part of the hero.
const ITEMS := {
	"rusty_blade": {"slot": "weapon", "glyph": "/", "color": Color(0.75, 0.7, 0.62), "price": 0,
		"dmg": 10, "speed": 1.0, "reach": 1.0, "kind": "sword", "class": "blade"},
	"glyph_saber": {"slot": "weapon", "glyph": "/", "color": Color(0.55, 0.95, 1.0), "price": 140,
		"dmg": 9, "speed": 1.55, "reach": 1.0, "kind": "sword", "class": "blade"},
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
		"dmg": 15, "speed": 1.15, "reach": 1.12, "kind": "katana", "class": "blade"},
	"pilgrim_sword": {"slot": "weapon", "glyph": "/", "color": Color(0.82, 0.78, 0.66), "price": 150,
		"dmg": 15, "speed": 1.0, "reach": 1.12, "kind": "sword", "class": "blade"},
	"frost_brand": {"slot": "weapon", "glyph": "/", "color": Color(0.65, 0.88, 1.0), "price": 200,
		"dmg": 13, "speed": 1.05, "reach": 1.05, "chill": true, "kind": "sword", "class": "blade"},
	"bloodletter": {"slot": "weapon", "glyph": "!", "color": Color(0.9, 0.2, 0.25), "price": 210,
		"dmg": 9, "speed": 1.7, "reach": 1.08, "leech": 0.01, "kind": "rapier", "class": "blade"},
	"bone_scythe": {"slot": "weapon", "glyph": "Г", "color": Color(0.88, 0.84, 0.74), "price": 240,
		"dmg": 17, "speed": 0.85, "reach": 1.3, "sweep": true, "kind": "scythe", "class": "heavy"},
	"bell_halberd": {"slot": "weapon", "glyph": "ŧ", "color": Color(0.75, 0.7, 0.5), "price": 220,
		"dmg": 19, "speed": 0.74, "reach": 1.5, "kind": "halberd", "class": "heavy"},
	"headsman_axe": {"slot": "weapon", "glyph": "Þ", "color": Color(0.72, 0.68, 0.7), "price": 250,
		"dmg": 30, "speed": 0.58, "reach": 1.15, "execute": true, "kind": "axe", "class": "heavy"},
	"ink_knife": {"slot": "throw", "glyph": "»", "color": Color(0.65, 0.75, 1.0), "price": 0, "dmg": 14.0, "ink": 33.0},
	"bone_boomerang": {"slot": "throw", "glyph": "<", "color": Color(0.92, 0.86, 0.72), "price": 150, "dmg": 8.0, "ink": 33.0},
	"thorn_chakram": {"slot": "throw", "glyph": "✶", "color": Color(0.6, 0.95, 0.55), "price": 160, "dmg": 9.0, "ink": 33.0},
	"bile_flask": {"slot": "throw", "glyph": "ò", "color": Color(0.55, 0.9, 0.3), "price": 170, "dmg": 16.0, "ink": 49.5},
	"grave_javelin": {"slot": "throw", "glyph": "—", "color": Color(0.8, 0.74, 0.62), "price": 190, "dmg": 22.0, "ink": 49.5},
	"pilgrim_hood": {"slot": "armor", "part": "head", "glyph": "∩", "color": Color(0.6, 0.48, 0.4), "price": 80, "armor": 0.96,
		"ink_gain": 1.1},
	"iron_sallet": {"slot": "armor", "part": "head", "glyph": "n", "color": Color(0.66, 0.66, 0.72), "price": 150, "armor": 0.92,
		"max_hp": 8, "run": 0.98},
	"plague_mask": {"slot": "armor", "part": "head", "glyph": "v", "color": Color(0.86, 0.8, 0.64), "price": 170, "armor": 0.95,
		"crit": 0.04},
	"gambeson": {"slot": "armor", "part": "body", "glyph": "#", "color": Color(0.55, 0.42, 0.36), "price": 90, "armor": 0.93},
	"chain_hauberk": {"slot": "armor", "part": "body", "glyph": "8", "color": Color(0.6, 0.62, 0.68), "price": 170, "armor": 0.87,
		"run": 0.97},
	"cathedral_plate": {"slot": "armor", "part": "body", "glyph": "Ж", "color": Color(0.78, 0.78, 0.86), "price": 260, "armor": 0.82,
		"max_hp": 15, "run": 0.92, "dash_cd": 1.12},
	"wanderer_boots": {"slot": "armor", "part": "legs", "glyph": "L", "color": Color(0.5, 0.38, 0.32), "price": 90, "armor": 0.97,
		"run": 1.04},
	"iron_greaves": {"slot": "armor", "part": "legs", "glyph": "Л", "color": Color(0.62, 0.62, 0.68), "price": 150, "armor": 0.92,
		"run": 0.97},
	"thorned_sabatons": {"slot": "armor", "part": "legs", "glyph": "Ψ", "color": Color(0.6, 0.52, 0.46), "price": 160, "armor": 0.94,
		"thorns": 10},
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

## The three armour parts, top to bottom.
const PARTS := ["head", "body", "legs"]
## Armour can be reforged UPGRADE_MAX times; each time cuts the damage it
## lets through by UPGRADE_STEP of its own protection and adds UPGRADE_HP health.
const UPGRADE_MAX := 3
const UPGRADE_STEP := 0.12
const UPGRADE_HP := 4

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


## What the merchant pays for an item from the bag (half of what was spent
## reforging it comes back too).
static func sell_price(id: String, p: Dictionary = {}) -> int:
	var d := def(id)
	if d.is_empty() or id == START_WEAPON or id == START_THROW:
		return 4
	if d.price <= 0:
		return 140
	var back := 0
	for k in upgrade_level(p, id):
		back += upgrade_price(id, k) / 2
	return maxi(10, int(d.price * 0.4)) + back


## How many times a piece of armour was reforged.
static func upgrade_level(p: Dictionary, id: String) -> int:
	return int(p.get("armor_up", {}).get(id, 0))


## Shards to reforge a piece of armour from level [lvl] to the next.
static func upgrade_price(id: String, lvl: int) -> int:
	return int(def(id).get("price", 100) * 0.6 * (lvl + 1))


## Reforges an armour piece if the hero can pay; returns false otherwise.
static func upgrade(p: Dictionary, id: String) -> bool:
	var lvl := upgrade_level(p, id)
	var price := upgrade_price(id, lvl)
	if def(id).get("slot", "") != "armor" or lvl >= UPGRADE_MAX or p.shards < price:
		return false
	p.shards -= price
	if not p.has("armor_up"):
		p.armor_up = {}
	p.armor_up[id] = lvl + 1
	return true


## Share of damage a piece of armour lets through, after reforging.
static func armor_factor(p: Dictionary, id: String) -> float:
	var cut := 1.0 - float(def(id).get("armor", 1.0))
	return 1.0 - cut * (1.0 + UPGRADE_STEP * upgrade_level(p, id))


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
		"chill": w.get("chill", false), "parry_mult": 1.0,
	}
	for part in PARTS:
		var aid: String = p.get("armor", {}).get(part, "")
		if aid == "":
			continue
		var a: Dictionary = def(aid)
		st.armor *= armor_factor(p, aid)
		st.max_hp += int(a.get("max_hp", 0)) + UPGRADE_HP * upgrade_level(p, aid)
		st.run *= float(a.get("run", 1.0))
		st.dash_cd *= float(a.get("dash_cd", 1.0))
		st.ink_gain *= float(a.get("ink_gain", 1.0))
		st.crit += float(a.get("crit", 0.0))
		st.thorns += int(a.get("thorns", 0))
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
	return p.weapon == id or p.belt.has(id) or p.get("throw", "") == id or p.charms.has(id) or p.bag.has(id) \
		or p.get("armor", {}).values().has(id)


## Makes the belt whole: BELT_SLOTS entries with the weapon in hand in the
## chosen slot. Runs saved before the belt carried a second weapon in
## [old_second]; it goes into the next slot.
static func fix_belt(p: Dictionary, old_second: String = "") -> void:
	var belt: Array = p.get("belt", [])
	belt.resize(BELT_SLOTS)
	for i in BELT_SLOTS:
		if not belt[i] is String:
			belt[i] = ""
	if old_second != "" and not belt.has(old_second):
		var free := belt.find("", 1)
		if free > 0:
			belt[free] = old_second
	var slot := clampi(int(p.get("wslot", 0)), 0, BELT_SLOTS - 1)
	if belt[slot] != p.weapon:
		slot = belt.find(p.weapon)
		if slot < 0:
			slot = maxi(0, belt.find(""))
			belt[slot] = p.weapon
	p.belt = belt
	p.wslot = slot


## Takes the weapon of belt slot [i] in hand; false if it is empty or held.
static func select_weapon(p: Dictionary, i: int) -> bool:
	if i < 0 or i >= BELT_SLOTS or i == p.wslot or p.belt[i] == "":
		return false
	p.wslot = i
	p.weapon = p.belt[i]
	return true


## Takes the next weapon on the belt in hand; false if there is no other.
static func next_weapon(p: Dictionary) -> bool:
	for k in range(1, BELT_SLOTS):
		if select_weapon(p, (p.wslot + k) % BELT_SLOTS):
			return true
	return false


## Number of weapons on the belt.
static func belt_count(p: Dictionary) -> int:
	return BELT_SLOTS - p.belt.count("")


## The armour piece worn on [part], or "".
static func worn(p: Dictionary, part: String) -> String:
	return p.get("armor", {}).get(part, "")


## Adds an item to the hero. Charms and armour go straight into a free slot,
## weapons replace the starting one or fill the empty second slot, anything
## else goes into the bag. Returns true if it was auto-equipped.
static func give(p: Dictionary, id: String) -> bool:
	var d := def(id)
	if d.is_empty() or owns(p, id):
		return false
	if d.slot == "charm" and p.charms.size() < charm_slots(p):
		p.charms.append(id)
		return true
	if d.slot == "armor" and worn(p, d.part) == "":
		p.armor[d.part] = id
		return true
	if d.slot == "weapon" and p.weapon == START_WEAPON:
		p.bag.append(p.weapon)
		p.weapon = id
		p.belt[p.wslot] = id
		return true
	if d.slot == "weapon" and p.belt.has(""):
		p.belt[p.belt.find("")] = id
		return true
	if d.slot == "throw" and (p.throw == START_THROW or p.throw == ""):
		if p.throw != "":
			p.bag.append(p.throw)
		p.throw = id
		return true
	p.bag.append(id)
	return false


## Equips or unequips an owned item. Returns false if nothing changed.
## A weapon from the bag goes into the hand; one on the belt but not in hand
## goes back into the bag.
static func toggle(p: Dictionary, id: String) -> bool:
	var d := def(id)
	if d.is_empty():
		return false
	if d.slot == "armor":
		if worn(p, d.part) == id:
			p.armor[d.part] = ""
			p.bag.append(id)
			return true
		if not p.bag.has(id):
			return false
		p.bag.erase(id)
		if worn(p, d.part) != "":
			p.bag.append(worn(p, d.part))
		p.armor[d.part] = id
		return true
	if d.slot == "weapon" and p.belt.has(id):
		var at: int = p.belt.find(id)
		if p.weapon == id:
			# the hand takes another weapon from the belt; the last one stays
			var other := -1
			for i in BELT_SLOTS:
				if i != at and p.belt[i] != "":
					other = i
					break
			if other < 0:
				return false
			p.wslot = other
			p.weapon = p.belt[other]
		p.belt[at] = ""
		p.bag.append(id)
		return true
	if d.slot == "weapon":
		# into an empty slot of the belt if there is one, else into the hand
		var free: int = p.belt.find("")
		return to_slot(p, id, free if free >= 0 else p.wslot)
	if d.slot == "throw":
		if p.throw == id:
			p.throw = ""
			p.bag.append(id)
			return true
		if not p.bag.has(id):
			return false
		p.bag.erase(id)
		if p.throw != "":
			p.bag.append(p.throw)
		p.throw = id
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


## Puts weapon [id] (from the bag or another belt slot) into belt slot [i].
## What was there goes back into the bag, or trades places with it on the belt.
static func to_slot(p: Dictionary, id: String, i: int) -> bool:
	if def(id).get("slot", "") != "weapon" or i < 0 or i >= BELT_SLOTS or p.belt[i] == id:
		return false
	var old: String = p.belt[i]
	var from: int = p.belt.find(id)
	if from >= 0:
		p.belt[from] = old
	elif p.bag.has(id):
		p.bag.erase(id)
		if old != "":
			p.bag.append(old)
	else:
		return false
	p.belt[i] = id
	if p.belt[p.wslot] == "":
		p.wslot = i
	p.weapon = p.belt[p.wslot]
	return true


## Sells an item from the bag; returns the shards paid, or 0.
static func sell(p: Dictionary, id: String) -> int:
	if not p.bag.has(id):
		return 0
	var price := sell_price(id, p)
	p.bag.erase(id)
	if p.has("armor_up"):
		p.armor_up.erase(id)
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
