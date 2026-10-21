## The skill tree. Every hero level gives one skill point. The core in the
## middle holds the basic moves (always known) and two stat nodes with several
## ranks; three branches grow out of it:
##   bulwark    heavy weapons and toughness
##   alchemist  daggers, thrown weapons and ink
##   shade      mobility and blades
## Each branch is seven tiers deep. Tiers 2, 4 and 6 fork: learning one side
## seals the other until the skills are forgotten at a merchant.
## Names and descriptions are in strings_more.gd as "sk_<id>" and "sk_<id>_d".
extends RefCounted

## rank: how many times a node can be learned. tier 0 is the core.
const NODES := {
	"vitality": {"branch": "core", "tier": 0, "rank": 8, "glyph": "♥"},
	"edge": {"branch": "core", "tier": 0, "rank": 8, "glyph": "/"},
	"iron_hide": {"branch": "bulwark", "tier": 1, "glyph": "Ω"},
	"quake": {"branch": "bulwark", "tier": 2, "fork": "a", "glyph": "v"},
	"shoulder": {"branch": "bulwark", "tier": 2, "fork": "b", "glyph": "»"},
	"heavy_mastery": {"branch": "bulwark", "tier": 3, "glyph": "¶"},
	"last_stand": {"branch": "bulwark", "tier": 4, "fork": "a", "glyph": "†"},
	"vengeance": {"branch": "bulwark", "tier": 4, "fork": "b", "glyph": "*"},
	"juggernaut": {"branch": "bulwark", "tier": 5, "glyph": "^"},
	"bastion": {"branch": "bulwark", "tier": 6, "fork": "a", "glyph": "#"},
	"rend": {"branch": "bulwark", "tier": 6, "fork": "b", "glyph": "%"},
	"titan": {"branch": "bulwark", "tier": 7, "glyph": "M"},
	"inkwell": {"branch": "alchemist", "tier": 1, "glyph": "¤"},
	"twin_throw": {"branch": "alchemist", "tier": 2, "fork": "a", "glyph": "‡"},
	"ricochet": {"branch": "alchemist", "tier": 2, "fork": "b", "glyph": "<"},
	"light_mastery": {"branch": "alchemist", "tier": 3, "glyph": "‡"},
	"hex": {"branch": "alchemist", "tier": 4, "fork": "a", "glyph": "ö"},
	"siphon": {"branch": "alchemist", "tier": 4, "fork": "b", "glyph": "ò"},
	"blade_storm": {"branch": "alchemist", "tier": 5, "glyph": "»"},
	"venom": {"branch": "alchemist", "tier": 6, "fork": "a", "glyph": "@"},
	"quicksilver": {"branch": "alchemist", "tier": 6, "fork": "b", "glyph": "≈"},
	"philosopher": {"branch": "alchemist", "tier": 7, "glyph": "◊"},
	"fleet": {"branch": "shade", "tier": 1, "glyph": "ł"},
	"phantom": {"branch": "shade", "tier": 2, "fork": "a", "glyph": "~"},
	"wind": {"branch": "shade", "tier": 2, "fork": "b", "glyph": "∫"},
	"blade_mastery": {"branch": "shade", "tier": 3, "glyph": ")"},
	"iaido": {"branch": "shade", "tier": 4, "fork": "a", "glyph": "!"},
	"long_lunge": {"branch": "shade", "tier": 4, "fork": "b", "glyph": "="},
	"reaper": {"branch": "shade", "tier": 5, "glyph": "√"},
	"shadowstep": {"branch": "shade", "tier": 6, "fork": "a", "glyph": "«"},
	"hemorrhage": {"branch": "shade", "tier": 6, "fork": "b", "glyph": "x"},
	"death_dance": {"branch": "shade", "tier": 7, "glyph": "&"},
}

const BRANCHES := ["bulwark", "alchemist", "shade"]
const BRANCH_COLORS := {
	"core": Color(0.85, 0.8, 0.7), "bulwark": Color(0.85, 0.3, 0.25), "alchemist": Color(0.55, 0.5, 0.95),
	"shade": Color(0.45, 0.85, 0.75),
}
const TIERS := 7


static func total_points(p: Dictionary) -> int:
	return maxi(0, int(p.get("xp_level", 1)) - 1)


static func spent(p: Dictionary) -> int:
	var n := 0
	for id in p.get("skills", {}):
		n += int(p.skills[id])
	return n


static func free_points(p: Dictionary) -> int:
	return total_points(p) - spent(p)


static func rank(p: Dictionary, id: String) -> int:
	return int(p.get("skills", {}).get(id, 0))


static func max_rank(id: String) -> int:
	return int(NODES[id].get("rank", 1))


## Node ids of one branch tier, in fork order (a, b).
static func tier_nodes(branch: String, tier: int) -> Array:
	var out: Array = []
	for id in NODES:
		if NODES[id].branch == branch and NODES[id].tier == tier:
			out.append(id)
	return out


## The other side of a fork, or "".
static func rival(id: String) -> String:
	var n: Dictionary = NODES[id]
	if not n.has("fork"):
		return ""
	for other in tier_nodes(n.branch, n.tier):
		if other != id:
			return other
	return ""


## Why a node cannot be learned right now: "" (it can), "maxed", "points",
## "locked" (the tier below is missing) or "sealed" (the other side of the fork).
static func block_reason(p: Dictionary, id: String) -> String:
	var n: Dictionary = NODES[id]
	if rank(p, id) >= max_rank(id):
		return "maxed"
	var r := rival(id)
	if r != "" and rank(p, r) > 0:
		return "sealed"
	if n.tier > 1:
		var below := false
		for other in tier_nodes(n.branch, n.tier - 1):
			below = below or rank(p, other) > 0
		if not below:
			return "locked"
	if free_points(p) <= 0:
		return "points"
	return ""


static func learn(p: Dictionary, id: String) -> bool:
	if block_reason(p, id) != "":
		return false
	if not p.has("skills"):
		p.skills = {}
	p.skills[id] = rank(p, id) + 1
	return true


static func forget_all(p: Dictionary) -> void:
	p.skills = {}


## Folds learned skills into the stats from Items.stats().
static func apply(p: Dictionary, st: Dictionary) -> void:
	var cls: String = st.get("class", "blade")
	st.max_hp += 8 * rank(p, "vitality")
	st.dmg_mult *= 1.0 + 0.03 * rank(p, "edge")
	if rank(p, "iron_hide") > 0:
		st.armor *= 0.88
	if rank(p, "heavy_mastery") > 0 and cls == "heavy":
		st.dmg_mult *= 1.25
		st.speed *= 1.12
	if rank(p, "inkwell") > 0:
		st.ink_gain *= 1.4
	if rank(p, "light_mastery") > 0:
		st.throw_mult *= 1.25
		if cls == "light":
			st.speed *= 1.18
			st.crit += 0.1
	if rank(p, "fleet") > 0:
		st.run *= 1.1
	if rank(p, "phantom") > 0:
		st.dash_inv = true
		st.dash_cd *= 0.7
	if rank(p, "wind") > 0:
		st.air_jumps += 1
	if rank(p, "blade_mastery") > 0 and cls == "blade":
		st.dmg_mult *= 1.15
		st.crit += 0.1
	if rank(p, "bastion") > 0:
		st.armor *= 0.88
		st.hp_mult *= 1.1
	if rank(p, "titan") > 0:
		st.armor *= 0.9
		if cls == "heavy":
			st.dmg_mult *= 1.15
			st.reach *= 1.1
	if rank(p, "quicksilver") > 0:
		st.ink_cost *= 0.8
	if rank(p, "philosopher") > 0:
		st.throw_mult *= 1.15
	if rank(p, "shadowstep") > 0:
		st.dash_cd *= 0.75
		st.crit += 0.05
	if rank(p, "hemorrhage") > 0:
		st.crit_mult = 2.3
		st.crit_burn = true
	for id in ["quake", "shoulder", "last_stand", "vengeance", "juggernaut", "twin_throw", "ricochet", "hex", "siphon",
			"blade_storm", "iaido", "long_lunge", "reaper", "rend", "venom", "philosopher", "death_dance"]:
		st[id] = rank(p, id) > 0
