## Merchant service for the hero's owned melee weapons.
extends RefCounted

const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")


static func candidates(p: Dictionary) -> Array:
	var out: Array = []
	for id in Items.ITEMS:
		if id != Items.START_WEAPON and Items.def(id).get("slot", "") == "weapon" and Items.owns(p, id) \
				and Items.weapon_hone_level(p, id) < Items.WEAPON_HONE_MAX:
			out.append(id)
	return out


static func menu_items(m) -> Array:
	var out: Array = []
	var p: Dictionary = m.game.player
	for id in candidates(p):
		var lvl := Items.weapon_hone_level(p, id)
		var old_damage: int = int(Items.def(id).dmg + Items.WEAPON_HONE_DAMAGE * lvl)
		out.append({"type": "buy", "id": id, "price": Items.weapon_hone_price(p, id),
			"note": m.game.L("hone_note") % [old_damage, old_damage + int(Items.WEAPON_HONE_DAMAGE), lvl + 1,
				Items.WEAPON_HONE_MAX], "act": buy.bind(m, id)})
	out.append(m._btn(m.game.L("m_back"), m.close))
	return out


static func buy(m, id: String) -> void:
	if not Items.hone_weapon(m.game.player, id):
		m.game.sfx("error", -6.0)
		m._message(m.game.L("shop_poor"))
		return
	Hero.refresh(m.game.player)
	m.game.sfx("buy")
	m._message(m.game.L("hone_done") % m._item_name(id))
	m.game.save_run()
