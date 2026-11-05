## Merchant service: move one armour reinforcement to another owned piece.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")


static func candidates(p: Dictionary) -> Array:
	var owned: Array = []
	for id in Items.ITEMS:
		if Items.def(id).get("slot", "") == "armor" and Items.owns(p, id):
			owned.append(id)
	var out: Array = []
	for source in owned:
		if Items.upgrade_level(p, source) == 0:
			continue
		for target in owned:
			if target == source or Items.def(target).part != Items.def(source).part:
				continue
			if Items.upgrade_level(p, target) < Items.UPGRADE_MAX:
				out.append({"source": source, "target": target, "price": price(p, target)})
	return out


static func price(p: Dictionary, target: String) -> int:
	return maxi(15, int(Items.upgrade_price(target, Items.upgrade_level(p, target)) * 0.35))


static func transfer(p: Dictionary, source: String, target: String) -> bool:
	if source == target or not Items.owns(p, source) or not Items.owns(p, target):
		return false
	var a: Dictionary = Items.def(source)
	var b: Dictionary = Items.def(target)
	if a.get("slot", "") != "armor" or b.get("slot", "") != "armor" or a.part != b.part:
		return false
	var src := Items.upgrade_level(p, source)
	var dst := Items.upgrade_level(p, target)
	var cost := price(p, target)
	if src <= 0 or dst >= Items.UPGRADE_MAX or p.shards < cost:
		return false
	p.shards -= cost
	p.armor_up[source] = src - 1
	p.armor_up[target] = dst + 1
	Hero.refresh(p)
	return true


static func menu_items(m) -> Array:
	var out: Array = []
	var p: Dictionary = m.game.player
	for c in candidates(p):
		var source: String = c.source
		var target: String = c.target
		out.append({"type": "buy", "id": target, "price": c.price,
			"label": m._item_name(source) + " → " + m._item_name(target),
			"note": "%d/%d → %d/%d" % [Items.upgrade_level(p, source), Items.UPGRADE_MAX,
				Items.upgrade_level(p, target) + 1, Items.UPGRADE_MAX],
			"act": buy.bind(m, source, target)})
	if out.is_empty():
		out.append(m._btn(m.game.L("forge_empty"), m.close))
	else:
		out.append(m._btn(m.game.L("m_back"), m.close))
	return out


static func buy(m, source: String, target: String) -> void:
	if not transfer(m.game.player, source, target):
		m.game.sfx("error", -6.0)
		m._message(m.game.L("shop_poor"))
		return
	m.game.sfx("buy")
	m._message(m.game.L("forge_done") % m._item_name(target))
	m.game.save_run()
