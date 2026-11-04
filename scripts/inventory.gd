## The inventory screen, drawn by menu.gd: the hero in a gothic niche with
## its numbers under it, then rows of slots without captions (armour; the
## weapon belt and the thrown weapon; the charms) and the bag as a grid of
## pictures. The item under the cursor or selected is described in a box
## beside it. Items are dragged with the mouse onto a slot or into the bag.
extends RefCounted

const S := preload("res://scripts/sprites.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const IconArt := preload("res://scripts/icon_art.gd")
const WeaponArt := preload("res://scripts/weapon_art.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")

const LABEL := Color(0.6, 0.66, 0.63)
const DIM := Color(0.4, 0.43, 0.42)
const GOLD := Color(1.0, 0.85, 0.5)
const CHARMS_PER_ROW := 4

## The bag's rect on screen (a drop target) and how far it is scrolled.
static var _bag_rect := Rect2()
static var _bag_scroll := 0


## One menu item per slot (equipped items first, then the bag).
static func items(m) -> Array:
	var p: Dictionary = m.game.player
	var out: Array = []
	for i in Items.BELT_SLOTS:
		var it := _slot(p.belt[i], "belt")
		it.slot = i
		out.append(it)
	out.append(_slot(p.throw, "throw"))
	for part in Items.PARTS:
		out.append(_slot(Items.worn(p, part), part))
	for i in Items.charm_slots(p):
		out.append(_slot(p.charms[i] if i < p.charms.size() else "", "charm"))
	for id in p.bag:
		out.append(_slot(id, "bag"))
	for k in out.size():
		out[k].key = k
	for it in out:
		if it.type == "item":
			it.act = _equip.bind(m, it.id, it.group)
	return out


static func _slot(id: String, group: String) -> Dictionary:
	return {"type": "item" if id != "" else "slot", "id": id, "group": group}


## Enter: a bag item is equipped (a weapon into the hand), an equipped one
## goes back into the bag; the weapon in hand stays.
static func _equip(m, id: String, group: String) -> void:
	var p: Dictionary = m.game.player
	var ok := Items.toggle(p, id)
	_after(m, ok)
	if not ok and Items.def(id).slot == "charm":
		m._message(m.game.L("inv_full"))
	elif not ok and group == "belt":
		m._message(m.game.L("inv_last_weapon"))


## A belt key (1, 2, 3) on a weapon in the bag or on the belt puts it into
## that slot.
static func to_slot(m, i: int) -> void:
	var it := _selected(m)
	if it.is_empty() or Items.def(it.id).get("slot", "") != "weapon":
		return
	_after(m, Items.to_slot(m.game.player, it.id, i))
	if it.group == "belt":
		# the belt slots are the first items: the selection follows the weapon
		m.sel = i


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


## Drops item [it] (dragged from its slot) at [pos]: onto a slot that takes
## it, or into the bag.
static func drop(m, it: Dictionary, pos: Vector2) -> void:
	var p: Dictionary = m.game.player
	var d: Dictionary = Items.def(it.id)
	var target := {}
	for t in m.items:
		if t.has("rect") and (t.rect as Rect2).grow(4 * m.u).has_point(pos):
			target = t
			break
	if target.is_empty() and _bag_rect.has_point(pos):
		target = {"group": "bag"}
	if target.is_empty() or target.get("id", "") == it.id:
		return
	var ok := false
	match target.group:
		"belt":
			ok = Items.to_slot(p, it.id, target.slot)
		"bag":
			if it.group != "bag":
				ok = Items.toggle(p, it.id)
				if not ok and it.group == "belt":
					m._message(m.game.L("inv_last_weapon"))
		"throw":
			ok = it.group == "bag" and d.slot == "throw" and Items.toggle(p, it.id)
		"charm":
			ok = it.group == "bag" and d.slot == "charm" and Items.toggle(p, it.id)
		_:
			ok = it.group == "bag" and d.slot == "armor" and d.part == target.group and Items.toggle(p, it.id)
	_after(m, ok)


## Scrolls the bag by [rows] when [pos] is over it; true when it was.
static func scroll(pos: Vector2, rows: int) -> bool:
	if not _bag_rect.has_point(pos):
		return false
	_bag_scroll = maxi(0, _bag_scroll + rows)
	return true


# ---------------------------------------------------------------- drawing

static func draw(m, vp: Vector2, accent: Color) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var u: float = m.u
	var sz := 46.0 * u
	var gap := 10.0 * u
	var hero_w := 180.0 * u
	# the belt and the thrown weapon a little apart: the widest row
	var mid_w := (Items.BELT_SLOTS + 1) * sz + Items.BELT_SLOTS * gap + 14 * u
	var row_gap := 24.0 * u
	var charm_n := Items.charm_slots(p)
	var charm_rows := ceili(charm_n / float(CHARMS_PER_ROW))
	var bag_cols := 5
	var bag_w := bag_cols * (sz + 6 * u)
	var w := minf(vp.x - 40 * u, 64 * u + hero_w + mid_w + bag_w + 60 * u)
	var h := minf(vp.y - 60 * u, 400.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	m._panel(r, accent)
	var inner := r.grow(-32 * u)
	var hero := Rect2(inner.position, Vector2(hero_w, inner.size.y))
	var bag := Rect2(inner.end.x - bag_w, inner.position.y, bag_w, inner.size.y)
	var mid_x := hero.end.x + (bag.position.x - hero.end.x - mid_w) * 0.5
	_draw_doll(m, p, hero)
	# rows of slots in the middle: armour, the belt, the charms
	var nrows := 2 + charm_rows
	var row_y := inner.get_center().y - (nrows * sz + (nrows - 1) * row_gap) * 0.5
	var row_w := func(n: int) -> float: return n * sz + (n - 1) * gap
	var charm_i := 0
	var bag_i := 0
	var per_row := bag_cols
	var cell := sz + 6 * u
	var bag_top := bag.position.y + 26 * u
	var vis_rows := maxi(1, int((bag.end.y - bag_top) / cell))
	var bag_rows := ceili(float(p.bag.size()) / per_row)
	# keep the selected bag item in view
	if m.sel < m.items.size() and m.items[m.sel].group == "bag":
		var srow := int((m.sel - (m.items.size() - p.bag.size())) / per_row)
		_bag_scroll = clampi(_bag_scroll, srow - vis_rows + 1, srow)
	_bag_scroll = clampi(_bag_scroll, 0, maxi(0, bag_rows - vis_rows))
	_bag_rect = Rect2(bag.position.x, bag_top, bag.size.x, vis_rows * cell)
	var tip_it := {}
	var tip_rect := Rect2()
	for i in m.items.size():
		var it: Dictionary = m.items[i]
		var on: bool = i == m.sel
		var rect := Rect2()
		match it.group:
			"head", "body", "legs":
				var x0: float = mid_x + (mid_w - row_w.call(3)) * 0.5
				rect = Rect2(x0 + ["head", "body", "legs"].find(it.group) * (sz + gap), row_y, sz, sz)
			"belt":
				rect = Rect2(mid_x + it.slot * (sz + gap), row_y + sz + row_gap, sz, sz)
			"throw":
				rect = Rect2(mid_x + Items.BELT_SLOTS * (sz + gap) + 14 * u, row_y + sz + row_gap, sz, sz)
			"charm":
				var cr := int(charm_i / CHARMS_PER_ROW)
				var n := mini(CHARMS_PER_ROW, charm_n - cr * CHARMS_PER_ROW)
				var x0: float = mid_x + (mid_w - row_w.call(n)) * 0.5
				rect = Rect2(x0 + (charm_i % CHARMS_PER_ROW) * (sz + gap), row_y + (2 + cr) * (sz + row_gap), sz, sz)
				charm_i += 1
			_:
				var row := int(bag_i / per_row) - _bag_scroll
				if row >= 0 and row < vis_rows:
					rect = Rect2(bag.position.x + (bag_i % per_row) * cell, bag_top + row * cell, sz, sz)
				bag_i += 1
		it.rect = rect
		if rect.size == Vector2.ZERO:
			continue
		var dragged: bool = m.dragging_item().get("key", -1) == it.key
		_draw_slot(m, p, it, rect, on and not dragged, dragged)
		if on and it.type == "item" and not dragged:
			tip_it = it
			tip_rect = rect
			# beside the middle column, not over the other slots
			if it.group != "bag" and g.ctl.device != "mouse":
				tip_rect.position.x = mid_x + mid_w - sz
	m._text(Vector2(bag.position.x, bag.position.y + 12 * u), g.L("inv_bag").to_upper(), int(13 * u), LABEL, m.bold)
	if p.bag.is_empty():
		m._text(Vector2(bag.position.x + 4 * u, bag_top + 30 * u), g.L("inv_empty"), int(15 * u), DIM)
	elif bag_rows > vis_rows:
		# a thin bar shows how far the bag is scrolled
		var bh := _bag_rect.size.y
		var th := bh * vis_rows / bag_rows
		var bx := bag.end.x + 6 * u
		m.draw_rect(Rect2(bx, bag_top, 2 * u, bh), Color(1, 1, 1, 0.08))
		m.draw_rect(Rect2(bx, bag_top + (bh - th) * _bag_scroll / (bag_rows - vis_rows), 2 * u, th), Color(1.0, 0.85, 0.5, 0.5))
	var held: Dictionary = m.dragging_item()
	if not held.is_empty():
		m._draw_icon(Rect2(m._mouse - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), held.id, Items.def(held.id).color, true)
	elif not tip_it.is_empty() and (g.ctl.device != "mouse" or tip_rect.grow(2 * u).has_point(m._mouse)):
		_draw_tip(m, p, tip_it, tip_rect, vp)


## The hero standing in a pointed niche, dressed in the armour worn, with
## the weapon in hand, and the hero's numbers under it.
static func _draw_doll(m, p: Dictionary, area: Rect2) -> void:
	var u: float = m.u
	var g = m.game
	var stats_h := 64.0 * u
	var c := Vector2(area.get_center().x, area.position.y + (area.size.y - stats_h) * 0.5)
	var nw := minf(area.size.x * 0.62, (area.size.y - stats_h) * 0.42)
	var nh := minf(area.size.y - stats_h, nw * 2.3)
	var x0 := c.x - nw * 0.5
	var x1 := c.x + nw * 0.5
	var yb := c.y - nh * 0.5 + nw * 0.866
	var bottom := yb + nh - nw * 0.866
	# a lancet niche: two arcs, each centred on the other side's springing point
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
	var foot := Vector2(c.x, bottom - 8 * u)
	for k in 5:
		m.draw_circle(foot + Vector2(0, -nh * 0.3), nw * (0.5 - k * 0.07), Color(0.9, 0.55, 0.3, 0.025))
	# the hero is about 30 world units tall and a pole arm held upright reaches
	# about 50 above the feet: all of it has to fit under the arch
	# (a whole number of screen pixels to a texel keeps the pixels square)
	var ds := maxf(1.0, floorf(nh * 0.84 / 50.0))
	var fr: Array = Hero.compose("idle", int(m.t * 1.6) % 2, Items.worn(p, "head"), Items.worn(p, "body"))
	var pal := Hero.palette(p)
	var tex := SpriteCache.tex(fr, pal)
	var size := Vector2(tex.get_size()) * ds
	var org := (foot - Vector2(size.x * 0.5, size.y - ds)).round()
	m.draw_texture_rect(tex, Rect2(org, size), false)
	WeaponArt.draw_held(m, org + Vector2(size.x * 0.5, size.y - ds), ds, p, S.HERO_SHOULDER.idle[int(m.t * 1.6) % 2], 1, pal[0],
		Color(1, 1, 1), true)
	var st: Dictionary = p.st
	var lines := [
		[g.L("lv") % p.xp_level + "    ◆ %d" % p.shards, GOLD],
		["%s %d/%d" % [g.L("stat_hp"), p.hp, p.max_hp], Color(0.9, 0.5, 0.48)],
		["%s %d  ·  %s %d%%" % [g.L("stat_dmg"), int(st.dmg * st.dmg_mult), g.L("stat_armor"), int(round((1.0 - st.armor) * 100.0))],
			Color(0.75, 0.78, 0.8)],
	]
	var fs := int(13 * u)
	for k in lines.size():
		var txt: String = lines[k][0]
		var ts: int = m._fit(txt, fs, area.size.x)
		m._text(Vector2(c.x - m._w(txt, ts) * 0.5, bottom + 20 * u + k * 19 * u), txt, ts, lines[k][1])


## One slot: the item's picture (or a faint outline when empty), the reforge
## marks on armour and a mark under the weapon in hand.
static func _draw_slot(m, p: Dictionary, it: Dictionary, rect: Rect2, on: bool, dragged: bool) -> void:
	var u: float = m.u
	if it.type == "slot" or dragged:
		m._draw_icon(rect, "", Color(0.3, 0.32, 0.3))
		var ghost: String = {"head": "iron_sallet", "body": "chain_hauberk", "legs": "iron_greaves", "belt": "rusty_blade",
			"throw": "ink_knife", "charm": "lucky_coin"}.get(it.group, "") if not dragged else it.id
		if ghost != "":
			IconArt.draw(m, ghost, rect.grow(-6 * u), Color(0.5, 0.5, 0.55), 0.12)
		return
	var col: Color = Items.def(it.id).color
	m._draw_icon(rect, it.id, col if it.group != "belt" or it.id == p.weapon else col.darkened(0.25), on)
	if on:
		m.draw_rect(rect.grow(2 * u), Color(1.0, 0.85, 0.5, 0.85), false, maxf(1.0, u * 1.5))
	if it.group == "belt" and it.id == p.weapon:
		m.draw_rect(Rect2(rect.position.x + 6 * u, rect.end.y + 4 * u, rect.size.x - 12 * u, 2 * u), GOLD)
	if it.group in Items.PARTS:
		var lvl := Items.upgrade_level(p, it.id)
		for k in Items.UPGRADE_MAX:
			var dc := Vector2(rect.position.x + rect.size.x * (0.3 + 0.2 * k), rect.end.y - 6 * u)
			var dia := PackedVector2Array([dc + Vector2(0, -3) * u, dc + Vector2(3, 0) * u, dc + Vector2(0, 3) * u, dc + Vector2(-3, 0) * u])
			m.draw_colored_polygon(dia, Color(1.0, 0.78, 0.35) if k < lvl else Color(0.2, 0.18, 0.16))


## The box beside a slot: the item's name, numbers, description and what
## can be done to it.
static func _draw_tip(m, p: Dictionary, it: Dictionary, at: Rect2, vp: Vector2) -> void:
	var u: float = m.u
	var g = m.game
	var d: Dictionary = Items.def(it.id)
	var w := minf(320.0 * u, vp.x - 20 * u)
	var pad := 12.0 * u
	var fs := int(13 * u)
	var nums := numbers(m, p, it.id)
	var desc: String = g.L("item_" + it.id + "_d")
	var acts := _actions(m, p, it)
	var h: float = pad * 2 + 30 * u + m._para_h(desc, w - pad * 2, fs) + 6 * u
	if nums != "":
		h += m._para_h(nums, w - pad * 2, fs) + 4 * u
	if acts != "":
		h += m._para_h(acts, w - pad * 2, int(12 * u)) + 6 * u
	var x := at.end.x + 12 * u
	if x + w > vp.x - 10 * u:
		x = at.position.x - 12 * u - w
	var r := Rect2(Vector2(clampf(x, 10 * u, vp.x - 10 * u - w), clampf(at.position.y, 10 * u, vp.y - 10 * u - h)), Vector2(w, h))
	m.draw_rect(r, Color(0.03, 0.025, 0.035, 0.96))
	m.draw_rect(r, Color(d.color.r, d.color.g, d.color.b, 0.5), false, maxf(1.0, u))
	var y := r.position.y + pad + 14 * u
	m._text_fit(Vector2(r.position.x + pad, y), m._item_name(it.id), int(16 * u), w - pad * 2, d.color, m.bold)
	y += 20 * u
	if nums != "":
		y += m._para(Vector2(r.position.x + pad, y), nums, w - pad * 2, fs, Color(0.95, 0.88, 0.7)) + 4 * u
	y += m._para(Vector2(r.position.x + pad, y), desc, w - pad * 2, fs, Color(0.7, 0.74, 0.72)) + 6 * u
	if acts != "":
		m._para(Vector2(r.position.x + pad, y), acts, w - pad * 2, int(12 * u), Color(0.55, 0.6, 0.58))


## What can be done to the item, as one line of hints, e.g. "LMB equip ·
## 1/2/3 to slot · F reforge ◆ 120".
static func _actions(m, p: Dictionary, it: Dictionary) -> String:
	var g = m.game
	var d: Dictionary = Items.def(it.id)
	var out: Array = []
	var ok: String = g.L("mouse_left") if g.ctl.device == "mouse" else ("Enter" if g.ctl.device != "pad" else g.key("jump"))
	if it.group == "bag":
		out.append("%s %s" % [ok, g.L("inv_equip").to_lower()])
	else:
		out.append("%s %s" % [ok, g.L("inv_unequip").to_lower()])
	if d.slot == "armor":
		var lvl := Items.upgrade_level(p, it.id)
		if lvl < Items.UPGRADE_MAX:
			# what one more reinforcing gives, so the price means something
			var cut := 1.0 - float(d.get("armor", 1.0))
			var gain: String = g.L("inv_reforge_gain") % [maxi(1, roundi(cut * Items.UPGRADE_STEP * 100.0)), Items.UPGRADE_HP]
			out.append("%s %s: %s  ◆ %d" % [g.key("throw"), g.L("inv_reforge").to_lower(), gain, Items.upgrade_price(it.id, lvl)])
	return "  ·  ".join(PackedStringArray(out))


## The numbers of an item: weapon damage, speed and reach; thrown damage and
## ink; armour protection, weight and reforging.
static func numbers(m, p: Dictionary, id: String) -> String:
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
			var parts: Array = ["%s +%d%%" % [g.L("stat_armor"), int(round((1.0 - Items.armor_factor(p, id)) * 100.0))]]
			var hp: int = int(d.get("max_hp", 0)) + Items.UPGRADE_HP * lvl
			if hp > 0:
				parts.append("%s +%d" % [g.L("stat_hp"), hp])
			if d.has("run"):
				parts.append("%s %+d%%" % [g.L("stat_run"), int(round((d.run - 1.0) * 100.0))])
			if d.has("dash_cd"):
				parts.append("%s %+d%%" % [g.L("stat_dash"), int(round((d.dash_cd - 1.0) * 100.0))])
			if lvl > 0:
				parts.append(g.L("inv_reforged") % [lvl, Items.UPGRADE_MAX])
			return "   ".join(PackedStringArray(parts))
	return ""
