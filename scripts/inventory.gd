## The inventory screen, drawn by menu.gd: the hero in a gothic niche with
## the armour slots (head, body, legs) on one side and the weapons (in hand,
## on the back, thrown) on the other, the charms beside them and the bag as a
## grid of pictures. Under them the selected item is described with what can
## be done to it: equip it, carry it as the second weapon or reforge armour.
extends RefCounted

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const IconArt := preload("res://scripts/icon_art.gd")
const WeaponArt := preload("res://scripts/weapon_art.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")

const LABEL := Color(0.6, 0.66, 0.63)
const DIM := Color(0.4, 0.43, 0.42)
const GOLD := Color(1.0, 0.85, 0.5)

## Clickable action hints of the details panel: [rect, callable].
static var _buttons: Array = []
static var _frames := {}


## One menu item per slot (equipped items first, then the bag).
static func items(m) -> Array:
	var p: Dictionary = m.game.player
	var out: Array = []
	out.append(_slot(p.weapon, "weapon"))
	out.append(_slot(p.get("weapon2", ""), "weapon2"))
	out.append(_slot(p.throw, "throw"))
	for part in Items.PARTS:
		out.append(_slot(Items.worn(p, part), part))
	for i in Items.charm_slots(p):
		out.append(_slot(p.charms[i] if i < p.charms.size() else "", "charm"))
	for id in p.bag:
		out.append(_slot(id, "bag"))
	for it in out:
		if it.type == "item":
			it.act = _equip.bind(m, it.id, it.group)
	return out


static func _slot(id: String, group: String) -> Dictionary:
	return {"type": "item" if id != "" else "slot", "id": id, "group": group}


## Enter: a bag item is equipped (a weapon into the hand), an equipped one
## goes back into the bag; on the weapon in hand it swaps with the second one.
static func _equip(m, id: String, group: String) -> void:
	var p: Dictionary = m.game.player
	var ok := false
	if group == "weapon":
		ok = Items.swap_weapons(p)
	elif group != "throw":
		ok = Items.toggle(p, id)
	_after(m, ok)
	if not ok and Items.def(id).slot == "charm":
		m._message(m.game.L("inv_full"))


## The swap key on a bag weapon makes it the second weapon; on either weapon
## slot it swaps them.
static func second(m) -> void:
	var it := _selected(m)
	if it.is_empty():
		return
	var p: Dictionary = m.game.player
	if it.group == "bag":
		_after(m, Items.equip_second(p, it.id))
	elif it.group in ["weapon", "weapon2"]:
		_after(m, Items.swap_weapons(p))


## The throw key on a piece of armour reforges it for shards.
static func reforge(m) -> void:
	var it := _selected(m)
	if it.is_empty() or Items.def(it.id).get("slot", "") != "armor":
		return
	var p: Dictionary = m.game.player
	var lvl := Items.upgrade_level(p, it.id)
	if lvl >= Items.UPGRADE_MAX:
		m.game.sfx("error", -6.0)
		m._message(m.game.L("inv_reforged_max"))
		return
	if not Items.upgrade(p, it.id):
		m.game.sfx("error", -6.0)
		m._message(m.game.L("shop_poor"))
		return
	Hero.refresh(p)
	m.game.sfx("buy", -2.0, 0.8)
	m.game.sfx("clink", -6.0, 0.9)
	m._message(m.game.L("inv_reforge_done") % [m._item_name(it.id), lvl + 1, Items.UPGRADE_MAX])
	m.game.save_run()


static func _after(m, ok: bool) -> void:
	if ok:
		Hero.refresh(m.game.player)
		m.game.sfx("menu_ok")
	else:
		m.game.sfx("error", -6.0)


static func _selected(m) -> Dictionary:
	if m.sel >= m.items.size() or m.items[m.sel].type != "item":
		return {}
	return m.items[m.sel]


## A click on one of the action hints; true when it was used.
static func click(pos: Vector2) -> bool:
	for b in _buttons:
		if b[0].has_point(pos):
			b[1].call()
			return true
	return false


# ---------------------------------------------------------------- drawing

static func draw(m, vp: Vector2, accent: Color) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var u: float = m.u
	var w := minf(vp.x - 40 * u, 1140.0 * u)
	var h := minf(vp.y - 60 * u, 740.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - 30 * u - h) * 0.5, w, h)
	m._panel(r, accent)
	m._heading(r.position.y + 46 * u, g.L("m_inventory"), int(30 * u))
	var top := r.position.y + 84 * u
	var bottom := r.end.y - 168 * u
	var doll := Rect2(r.position.x + 24 * u, top, w * 0.37, bottom - top)
	var cx := doll.end.x + 18 * u
	var cw := w * 0.27
	var bx := cx + cw + 22 * u
	var bw := r.end.x - 24 * u - bx
	_draw_doll(m, p, doll)
	var sz := minf(66.0 * u, (doll.size.y - 70 * u) / 3.0)
	var charm_rows: Array = []
	var bag_i := 0
	var charm_i := 0
	var cell := 60.0 * u
	var per_row := maxi(1, int(bw / cell))
	var row_h := minf(46.0 * u, (bottom - top - 26 * u) / maxf(1.0, Items.charm_slots(p)))
	for i in m.items.size():
		var it: Dictionary = m.items[i]
		var on: bool = i == m.sel
		var rect: Rect2
		match it.group:
			"weapon", "weapon2", "throw", "head", "body", "legs":
				var k: int = ["head", "body", "legs", "weapon", "weapon2", "throw"].find(it.group)
				var x: float = doll.position.x if k < 3 else doll.end.x - sz
				rect = Rect2(x, doll.position.y + 22 * u + (k % 3) * (sz + 24 * u), sz, sz)
				_draw_slot(m, p, it, rect, on)
			"charm":
				rect = Rect2(cx, top + 22 * u + charm_i * row_h, cw, row_h)
				charm_i += 1
				charm_rows.append([it, rect, on])
			_:
				rect = Rect2(bx + (bag_i % per_row) * cell, top + 22 * u + int(bag_i / per_row) * cell, cell - 6 * u, cell - 6 * u)
				bag_i += 1
				m._draw_icon(rect, it.id, Items.def(it.id).color, on)
				if on:
					m.draw_rect(rect.grow(2 * u), Color(1.0, 0.85, 0.5, 0.8), false, maxf(1.0, u * 1.5))
		it.rect = rect
	var fs := int(13 * u)
	m._text(Vector2(cx, top + 12 * u), (g.L("inv_charms") + "  %d/%d" % [p.charms.size(), Items.charm_slots(p)]).to_upper(), fs, LABEL,
		m.bold)
	m._text(Vector2(bx, top + 12 * u), g.L("inv_bag").to_upper(), fs, LABEL, m.bold)
	for cr in charm_rows:
		_draw_charm_row(m, cr[0], cr[1], cr[2])
	if p.bag.is_empty():
		m._text(Vector2(bx + 4 * u, top + 50 * u), g.L("inv_empty"), int(16 * u), DIM)
	_draw_details(m, p, r, r.end.y - 154 * u)


## The hero standing in a pointed niche, dressed in the armour worn, with
## the weapon in hand and the second one across the back.
static func _draw_doll(m, p: Dictionary, area: Rect2) -> void:
	var u: float = m.u
	var c := area.get_center()
	# a lancet niche: two arcs, each centred on the other side's springing point
	var nw := minf(area.size.x * 0.4, area.size.y * 0.42)
	var nh := minf(area.size.y * 0.9, nw * 2.3)
	var x0 := c.x - nw * 0.5
	var x1 := c.x + nw * 0.5
	var yb := area.position.y + (area.size.y - nh) * 0.5 + nw * 0.866
	var bottom := yb + nh - nw * 0.866
	var arch := PackedVector2Array([Vector2(x0, bottom)])
	for k in 9:
		var f := deg_to_rad(60.0 * k / 8.0)
		arch.append(Vector2(x1 - nw * cos(f), yb - nw * sin(f)))
	for k in range(7, -1, -1):
		var f := deg_to_rad(60.0 * k / 8.0)
		arch.append(Vector2(x0 + nw * cos(f), yb - nw * sin(f)))
	arch.append(Vector2(x1, bottom))
	m.draw_colored_polygon(arch, Color(0.06, 0.04, 0.05, 0.9))
	var edge := arch.duplicate()
	edge.append(arch[0])
	m.draw_polyline(edge, Color(0.4, 0.35, 0.33), maxf(1.0, 1.4 * u), true)
	var inner := PackedVector2Array()
	for q in edge:
		inner.append(c + (q - c) * 0.94 + Vector2(0, 2 * u))
	m.draw_polyline(inner, Color(0.6, 0.1, 0.1, 0.35), maxf(1.0, u), true)
	var foot := Vector2(c.x, bottom - 12 * u)
	for k in 5:
		m.draw_circle(foot + Vector2(0, -nh * 0.3), nw * (0.5 - k * 0.07), Color(0.9, 0.55, 0.3, 0.025))
	m.draw_line(Vector2(x0 + 8 * u, foot.y + 2 * u), Vector2(x1 - 8 * u, foot.y + 2 * u), Color(0.45, 0.38, 0.35), maxf(1.0, 1.5 * u))
	# the hero is about 30 world units tall and a pole arm held upright reaches
	# about 50 above the feet: all of it has to fit under the arch
	var ds := nh * 0.84 / 50.0
	var bold: Font = m.bold
	var adv_ratio := bold.get_char_size("M".unicode_at(0), 100).x / 100.0
	var sc: float = S.HERO.scale
	var size := maxi(4, int(D.GW * ds / adv_ratio * 1.3 * sc))
	var fr: Dictionary = S.HERO.idle[int(m.t * 1.6) % 2]
	var key := fr.hash()
	if not _frames.has(key):
		_frames[key] = SpriteCache.compile(fr, {}, S.HERO.a)
	var cs: Array = _frames[key]
	var gw := bold.get_char_size("M".unicode_at(0), size).x
	var org := foot + Vector2(-gw * 0.5, size * 0.36)
	var step := Vector2(D.GW * sc * ds, D.GH * sc * ds)
	var pal := Hero.palette(p)
	var w2: String = p.get("weapon2", "")
	if w2 != "":
		var d2: Dictionary = Items.def(w2)
		WeaponArt.draw(m, d2.get("kind", "sword"), foot + Vector2(-3.0, -9.0) * ds, -2.05, 1.0, ds * 0.85, d2.color * 0.7, 1.0)
	var dx: PackedFloat32Array = cs[0]
	var dy: PackedFloat32Array = cs[1]
	var chars: PackedStringArray = cs[2]
	var pidx: PackedInt32Array = cs[4]
	for k in chars.size():
		var at := org + Vector2(dx[k] * step.x, -dy[k] * step.y)
		var col: Color = pal[mini(pidx[k], pal.size() - 1)]
		m.draw_char(bold, at + Vector2(1.5, 1.5) * u, chars[k], size, Color(0, 0, 0, 0.75))
		m.draw_char(bold, at, chars[k], size, col)
	var wd: Dictionary = Items.def(p.weapon)
	var kind: String = wd.get("kind", "sword")
	var a: float = WeaponArt.REST.get(kind, 1.05) + sin(m.t * 1.8) * 0.04
	var hand := foot + (Vector2(4.0, -15.0) + Vector2(cos(a), sin(a)) * 4.5) * ds
	WeaponArt.draw(m, kind, hand, a, 1.0, ds, wd.color, p.st.reach)
	if kind == "dagger":
		WeaponArt.draw(m, kind, foot + Vector2(-3.0, -13.0) * ds, a + 2.4, 1.0, ds, wd.color * 0.8, p.st.reach)
	var armor := int(round((1.0 - p.st.armor) * 100.0))
	var at_text: String = "%s %d%%" % [m.game.L("stat_armor"), armor]
	var afs := int(14 * u)
	m._text(Vector2(c.x - m._w(at_text, afs, bold) * 0.5, bottom + 20 * u), at_text, afs, Color(0.75, 0.78, 0.82), bold)


## One slot beside the hero: the item's picture (or a faint outline when
## empty), its caption, and the reforge marks on armour.
static func _draw_slot(m, p: Dictionary, it: Dictionary, rect: Rect2, on: bool) -> void:
	var u: float = m.u
	var g = m.game
	var caption: String = g.L({"weapon": "inv_weapon", "weapon2": "inv_weapon2", "throw": "inv_throw"}.get(it.group, "part_" + it.group))
	var cs: int = m._fit(caption, int(11 * u), rect.size.x * 1.6)
	var cap_x: float = rect.get_center().x - m._w(caption, cs) * 0.5
	m._text(Vector2(cap_x, rect.position.y - 6 * u), caption, cs, LABEL)
	if it.type == "slot":
		m._draw_icon(rect, "", Color(0.3, 0.32, 0.3))
		var ghost: String = {"head": "iron_sallet", "body": "chain_hauberk", "legs": "iron_greaves"}.get(it.group, "")
		if ghost != "":
			IconArt.draw(m, ghost, rect.grow(-6 * u), Color(0.5, 0.5, 0.55), 0.14)
		return
	var col: Color = Items.def(it.id).color
	m._draw_icon(rect, it.id, col if it.group != "weapon2" else col.darkened(0.15), on)
	if on:
		m.draw_rect(rect.grow(2 * u), Color(1.0, 0.85, 0.5, 0.85), false, maxf(1.0, u * 1.5))
	if it.group in Items.PARTS:
		var lvl := Items.upgrade_level(p, it.id)
		for k in Items.UPGRADE_MAX:
			var dc := Vector2(rect.position.x + rect.size.x * (0.3 + 0.2 * k), rect.end.y - 6 * u)
			var dia := PackedVector2Array([dc + Vector2(0, -3) * u, dc + Vector2(3, 0) * u, dc + Vector2(0, 3) * u, dc + Vector2(-3, 0) * u])
			m.draw_colored_polygon(dia, Color(1.0, 0.78, 0.35) if k < lvl else Color(0.2, 0.18, 0.16))


static func _draw_charm_row(m, it: Dictionary, rect: Rect2, on: bool) -> void:
	var u: float = m.u
	var ih := rect.size.y - 8 * u
	m.draw_rect(rect.grow(-2 * u), Color(1, 1, 1, 0.09 if on else 0.03))
	if on:
		m.draw_rect(rect.grow(-2 * u), Color(1.0, 0.85, 0.5, 0.6), false, maxf(1.0, u))
		m.draw_rect(Rect2(rect.position + Vector2(2, 2) * u, Vector2(4 * u, rect.size.y - 4 * u)), Color(0.6, 0.06, 0.08))
	var icon := Rect2(rect.position + Vector2(8, 4) * u, Vector2(ih, ih))
	var fs := int(15 * u)
	var tx := icon.end.x + 10 * u
	var tw := rect.end.x - tx - 6 * u
	if it.type == "slot":
		m._draw_icon(icon, "", Color(0.3, 0.32, 0.3))
		m._text_fit(Vector2(tx, rect.position.y + rect.size.y * 0.62), m.game.L("inv_empty"), fs, tw, DIM)
		return
	m._draw_icon(icon, it.id, Items.def(it.id).color, on)
	m._text_fit(Vector2(tx, rect.position.y + rect.size.y * 0.62), m._item_name(it.id), fs, tw,
		Color(1, 0.96, 0.88) if on else Color(0.8, 0.84, 0.82), m.bold if on else m.font)


## Name, description, numbers and actions of the selected item, then the
## hero's totals along the bottom edge.
static func _draw_details(m, p: Dictionary, r: Rect2, dy: float) -> void:
	var u: float = m.u
	var g = m.game
	_buttons = []
	var lx := r.position.x + 30 * u
	var w := r.size.x - 60 * u
	m.draw_line(Vector2(r.position.x + 24 * u, dy - 10 * u), Vector2(r.end.x - 24 * u, dy - 10 * u), Color(1, 1, 1, 0.1), maxf(1.0, u))
	var it := _selected(m)
	if not it.is_empty():
		var id: String = it.id
		var d: Dictionary = Items.def(id)
		var hints := _actions(m, p, it)
		var hx := r.end.x - 30 * u
		var hfs := int(14 * u)
		for k in range(hints.size() - 1, -1, -1):
			var txt: String = hints[k][0]
			var hw: float = m._w(txt, hfs, m.bold)
			hx -= hw
			m._text(Vector2(hx, dy + 14 * u), txt, hfs, GOLD if hints[k][1].is_valid() else DIM, m.bold)
			if hints[k][1].is_valid():
				_buttons.append([Rect2(hx - 4 * u, dy - 2 * u, hw + 8 * u, 24 * u), hints[k][1]])
			hx -= 18 * u
		m._text_fit(Vector2(lx, dy + 14 * u), m._item_name(id), int(20 * u), hx - lx, d.color, m.bold)
		var dh: float = m._para(Vector2(lx, dy + 42 * u), g.L("item_" + id + "_d"), w, int(15 * u), Color(0.8, 0.84, 0.82))
		m._text_fit(Vector2(lx, dy + 46 * u + dh), _numbers(m, p, id), int(14 * u), w, Color(0.65, 0.72, 0.68))
	var st: Dictionary = p.st
	var summary := "%s    %s %d/%d    %s %d    %s ×%.2f    %s %d%%    %s %d%%    ◆ %d" % [
		g.L("lv") % p.xp_level, g.L("stat_hp"), p.hp, p.max_hp, g.L("stat_dmg"), int(st.dmg * st.dmg_mult),
		g.L("stat_speed"), st.speed, g.L("stat_crit"), int(st.crit * 100.0), g.L("stat_armor"), int(round((1.0 - st.armor) * 100.0)),
		p.shards]
	m._text_fit(Vector2(lx, r.end.y - 26 * u), summary, int(14 * u), w, Color(0.7, 0.76, 0.73))


## [label, callable] for each thing the selected item can do (an invalid
## callable greys the label out, e.g. armour that is fully reforged).
static func _actions(m, p: Dictionary, it: Dictionary) -> Array:
	var g = m.game
	var d: Dictionary = Items.def(it.id)
	var out: Array = []
	var enter := "[Enter] "
	match it.group:
		"weapon":
			if p.get("weapon2", "") != "":
				out.append([enter + g.L("a_swap"), _equip.bind(m, it.id, it.group)])
		"weapon2", "head", "body", "legs", "charm":
			out.append([enter + g.L("inv_unequip"), _equip.bind(m, it.id, it.group)])
		"bag":
			out.append([enter + g.L("inv_equip"), _equip.bind(m, it.id, it.group)])
			if d.slot == "weapon":
				out.append([g.key("swap") + " " + g.L("inv_second"), second.bind(m)])
	if d.get("slot", "") == "armor":
		var lvl := Items.upgrade_level(p, it.id)
		if lvl >= Items.UPGRADE_MAX:
			out.append([g.L("inv_reforged_max"), Callable()])
		else:
			out.append(["%s %s ◆ %d" % [g.key("throw"), g.L("inv_reforge"), Items.upgrade_price(it.id, lvl)], reforge.bind(m)])
	return out


## The numbers of an item: weapon damage, speed and reach; thrown damage and
## ink; armour protection, weight and reforging.
static func _numbers(m, p: Dictionary, id: String) -> String:
	var g = m.game
	var d: Dictionary = Items.def(id)
	match d.slot:
		"weapon":
			return "%s %d   %s ×%.2f   %s ×%.2f   %s" % [g.L("stat_dmg"), d.dmg, g.L("stat_speed"), d.speed, g.L("stat_reach"), d.reach,
				g.L("class_" + d.class)]
		"throw":
			var tdmg: float = d.dmg * p.st.throw_dmg / p.st.throw_base
			return "%s %d   %s %d" % [g.L("stat_dmg"), int(round(tdmg)), g.L("ink"), int(d.ink * p.st.ink_cost)]
		"armor":
			var lvl := Items.upgrade_level(p, id)
			var parts: Array = ["%s −%d%%" % [g.L("stat_armor"), int(round((1.0 - Items.armor_factor(p, id)) * 100.0))]]
			var hp: int = int(d.get("max_hp", 0)) + Items.UPGRADE_HP * lvl
			if hp > 0:
				parts.append("%s +%d" % [g.L("stat_hp"), hp])
			if d.has("run"):
				parts.append("%s %+d%%" % [g.L("stat_run"), int(round((d.run - 1.0) * 100.0))])
			if d.has("dash_cd"):
				parts.append("%s %+d%%" % [g.L("stat_dash"), int(round((d.dash_cd - 1.0) * 100.0))])
			parts.append(g.L("inv_reforged") % [lvl, Items.UPGRADE_MAX])
			return "   ".join(PackedStringArray(parts))
	return ""
