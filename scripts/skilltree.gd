## The skill tree screen, drawn by menu.gd. The core sits at the bottom: a
## reliquary holding the basic moves and the two stat nodes. Three branches
## climb from it like iron thorns; at the forks one side is chosen for good
## (until the skills are forgotten at a merchant).
extends RefCounted

const Skills := preload("res://scripts/skills.gd")
const Hero := preload("res://scripts/hero.gd")

const BASE_MOVES := [["move_triple", "≡"], ["move_lunge", "»"], ["move_rise", ")"], ["move_pogo", "v"], ["move_knife", "‡"]]


## One menu item per node, then the way back.
static func items(m) -> Array:
	var out: Array = []
	for id in ["vitality", "edge"]:
		out.append({"type": "skill", "id": id, "act": _learn.bind(m, id)})
	for b in Skills.BRANCHES:
		for tier in range(1, Skills.TIERS + 1):
			for id in Skills.tier_nodes(b, tier):
				out.append({"type": "skill", "id": id, "act": _learn.bind(m, id)})
	out.append(m._btn(m.game.L("m_back"), m.close))
	return out


static func _learn(m, id: String) -> void:
	var p: Dictionary = m.game.player
	var why := Skills.block_reason(p, id)
	if why != "":
		m.game.sfx("error", -6.0)
		m._message(m.game.L("sk_why_" + why))
		return
	var before: int = p.max_hp
	Skills.learn(p, id)
	Hero.refresh(p)
	p.hp = mini(p.max_hp, p.hp + maxi(0, p.max_hp - before))
	m.game.sfx("buy", -2.0, 1.2)
	m.game.save_run()


## Arrow keys move through the tree by position, not list order.
static func step(m, dir: Vector2) -> void:
	var cur: Dictionary = m.items[m.sel]
	if not cur.has("rect"):
		return
	var from: Vector2 = cur.rect.get_center()
	var best := -1
	var best_d := INF
	for i in m.items.size():
		var it: Dictionary = m.items[i]
		if i == m.sel or not it.has("rect"):
			continue
		var d: Vector2 = it.rect.get_center() - from
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var score := along + absf(d.dot(Vector2(dir.y, dir.x))) * 2.5
		if score < best_d:
			best_d = score
			best = i
	if best >= 0:
		m.sel = best
		m.game.sfx("menu_move", -10.0)


static func draw(m, vp: Vector2, accent: Color) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var u: float = m.u
	var w := minf(vp.x - 40 * u, 1180.0 * u)
	var h := minf(vp.y - 50 * u, 800.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - 40 * u - h) * 0.5, w, h)
	m._panel(r, accent)
	m._heading(r.position.y + 46 * u, g.L("m_skills"), int(30 * u))
	var pts := Skills.free_points(p)
	var pt_text: String = g.L("sk_points") % pts
	var pc := Color(1.0, 0.85, 0.4) if pts > 0 else Color(0.55, 0.58, 0.56)
	m._text(Vector2(r.end.x - 30 * u - m._w(pt_text, int(16 * u), m.bold), r.position.y + 46 * u), pt_text, int(16 * u), pc, m.bold)
	var details_h := 118.0 * u
	var core := Rect2(r.get_center().x - 230 * u, r.end.y - details_h - 128 * u, 460 * u, 104 * u)
	var top_y := r.position.y + 110 * u
	var tier_h := (core.position.y - 40 * u - top_y) / (Skills.TIERS - 1)
	var col_w := w / 3.0
	var nr := minf(22.0 * u, tier_h * 0.3)
	# where each node sits
	var pos := {}
	for bi in Skills.BRANCHES.size():
		var b: String = Skills.BRANCHES[bi]
		var cx := r.position.x + col_w * (bi + 0.5)
		for tier in range(1, Skills.TIERS + 1):
			var ids := Skills.tier_nodes(b, tier)
			var y := core.position.y - 40 * u - (tier - 1) * tier_h
			for k in ids.size():
				var dx := 0.0 if ids.size() == 1 else (k - 0.5) * minf(col_w * 0.46, 120 * u)
				pos[ids[k]] = Vector2(cx + dx, y)
	pos["vitality"] = Vector2(core.position.x + 50 * u, core.get_center().y - 10 * u)
	pos["edge"] = Vector2(core.end.x - 50 * u, core.get_center().y - 10 * u)
	# thorny stems: from the core up through each tier
	for bi in Skills.BRANCHES.size():
		var b: String = Skills.BRANCHES[bi]
		var bc: Color = Skills.BRANCH_COLORS[b]
		var root := Vector2(core.get_center().x + (bi - 1) * 120 * u, core.position.y)
		var prev: Array = [root]
		for tier in range(1, Skills.TIERS + 1):
			var cur: Array = []
			for id in Skills.tier_nodes(b, tier):
				cur.append(id)
				for q in prev:
					var a: Vector2 = q if q is Vector2 else pos[q]
					var lit: bool = Skills.rank(p, id) > 0 and (q is Vector2 or Skills.rank(p, q) > 0)
					_stem(m, a, pos[id], bc if lit else Color(0.3, 0.27, 0.27), u, lit)
			prev = cur
		# branch name above the top node
		var name: String = g.L("sk_" + b)
		var ns: int = m._fit(name, int(17 * u), col_w - 30 * u, m.bold)
		var top: Vector2 = pos[Skills.tier_nodes(b, Skills.TIERS)[0]]
		m._text(Vector2(top.x - m._w(name, ns, m.bold) * 0.5, top.y - nr - 16 * u), name, ns, bc, m.bold)
	# the core: a reliquary with the basic moves
	_reliquary(m, core, u)
	var bs := int(19 * u)
	var span := core.size.x - 200 * u
	for k in BASE_MOVES.size():
		var mx := core.position.x + 100 * u + span * (k + 0.5) / BASE_MOVES.size()
		var mc := Vector2(mx, core.get_center().y - 8 * u)
		m.draw_circle(mc, 13 * u, Color(0.1, 0.08, 0.09))
		m.draw_arc(mc, 13 * u, 0, TAU, 20, Color(0.55, 0.5, 0.45), maxf(1.0, u))
		var gl: String = BASE_MOVES[k][1]
		m._text(Vector2(mc.x - m._w(gl, bs, m.bold) * 0.5, mc.y + bs * 0.36), gl, bs, Color(0.92, 0.88, 0.8), m.bold)
	var cl: String = g.L("sk_core")
	m._text(Vector2(core.get_center().x - m._w(cl, int(12 * u)) * 0.5, core.end.y - 12 * u), cl, int(12 * u), Color(0.6, 0.58, 0.55))
	# fork marks between the two sides
	for b in Skills.BRANCHES:
		for tier in [2, 4]:
			var ids := Skills.tier_nodes(b, tier)
			var mid: Vector2 = (pos[ids[0]] + pos[ids[1]]) * 0.5
			var orr: String = g.L("sk_or")
			m._text(Vector2(mid.x - m._w(orr, int(11 * u)) * 0.5, mid.y + 4 * u), orr, int(11 * u), Color(0.55, 0.5, 0.48))
	# nodes
	for i in m.items.size():
		var it: Dictionary = m.items[i]
		if it.type != "skill":
			continue
		var c: Vector2 = pos[it.id]
		it.rect = Rect2(c - Vector2(nr, nr) * 1.3, Vector2(nr, nr) * 2.6)
		_node(m, it.id, c, nr, i == m.sel)
	# the way back
	for it in m.items:
		if it.type == "button":
			var br := Rect2(r.end.x - 170 * u, r.end.y - 48 * u, 150 * u, 34 * u)
			it.rect = br
			var on: bool = m.items[m.sel] == it
			m.draw_rect(br, Color(1, 1, 1, 0.09 if on else 0.03))
			m.draw_rect(br, Color(1.0, 0.85, 0.5, 0.6 if on else 0.2), false, maxf(1.0, u))
			var bl: String = it.label
			m._text(Vector2(br.get_center().x - m._w(bl, int(15 * u), m.bold) * 0.5, br.position.y + 23 * u), bl, int(15 * u),
				Color(0.95, 0.92, 0.85), m.bold)
	_details(m, Rect2(r.position.x + 30 * u, r.end.y - details_h, w - 220 * u, details_h - 14 * u))


static func _stem(m, a: Vector2, b: Vector2, c: Color, u: float, lit: bool) -> void:
	m.draw_line(a, b, Color(0, 0, 0, 0.6), maxf(1.0, 4.0 * u))
	m.draw_line(a, b, c, maxf(1.0, (2.2 if lit else 1.4) * u))
	# thorns along the stem
	var d := b - a
	var n := maxi(1, int(d.length() / (26.0 * u)))
	var side := Vector2(-d.y, d.x).normalized()
	for k in n:
		var q := a + d * (k + 0.5) / n
		var s := 1.0 if k % 2 == 0 else -1.0
		m.draw_colored_polygon(PackedVector2Array([q - d.normalized() * 2.5 * u, q + side * s * 6.0 * u, q + d.normalized() * 2.5 * u]), c)


## The core: a stone reliquary with a pointed lid.
static func _reliquary(m, r: Rect2, u: float) -> void:
	var iron := Color(0.45, 0.4, 0.37)
	var lid := PackedVector2Array([r.position, Vector2(r.get_center().x, r.position.y - 26 * u), Vector2(r.end.x, r.position.y)])
	m.draw_colored_polygon(lid, Color(0.06, 0.05, 0.06))
	m.draw_polyline(lid, iron, maxf(1.0, 1.4 * u))
	m.draw_rect(r, Color(0.04, 0.035, 0.04, 0.95))
	m.draw_rect(r, iron, false, maxf(1.0, 1.4 * u))
	m.draw_rect(r.grow(-5 * u), Color(0.6, 0.15, 0.12, 0.35), false, maxf(1.0, u))
	m._cross(Vector2(r.get_center().x, r.position.y - 26 * u), 6.0 * u, iron, Color(0.8, 0.2, 0.15))


## One node: a diamond for branch skills, a circle for core stats.
static func _node(m, id: String, c: Vector2, nr: float, on: bool) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var u: float = m.u
	var n: Dictionary = Skills.NODES[id]
	var bc: Color = Skills.BRANCH_COLORS[n.branch]
	var rk := Skills.rank(p, id)
	var why := Skills.block_reason(p, id)
	var learned := rk > 0
	var open := why == ""
	var fill := Color(0.07, 0.06, 0.07)
	var rim := Color(0.32, 0.3, 0.3)
	var gc := Color(0.4, 0.38, 0.38)
	if learned:
		fill = bc * 0.38
		fill.a = 1.0
		rim = bc
		gc = Color(1, 0.96, 0.9)
	elif open:
		var pulse := 0.6 + 0.4 * sin(m.t * 4.0)
		rim = Color(1.0, 0.85, 0.4).lerp(bc, 0.3) * pulse
		rim.a = 1.0
		gc = Color(0.92, 0.88, 0.8)
	var shape := PackedVector2Array()
	if n.tier == 0:
		for k in 16:
			shape.append(c + Vector2(cos(k * TAU / 16.0), sin(k * TAU / 16.0)) * nr)
	else:
		shape = PackedVector2Array([c + Vector2(0, -nr * 1.15), c + Vector2(nr * 1.15, 0), c + Vector2(0, nr * 1.15), c + Vector2(-nr * 1.15, 0)])
	if learned:
		m.draw_circle(c, nr * 1.7, Color(bc.r, bc.g, bc.b, 0.12))
	m.draw_colored_polygon(shape, fill)
	var outline := shape.duplicate()
	outline.append(shape[0])
	m.draw_polyline(outline, rim, maxf(1.0, (2.2 if on else 1.4) * u))
	if on:
		var sel := PackedVector2Array()
		for q in outline:
			sel.append(c + (q - c) * 1.35)
		m.draw_polyline(sel, Color(1.0, 0.9, 0.55, 0.9), maxf(1.0, u))
	var gl: String = n.glyph
	var fs := int(nr * 0.95)
	m._text(Vector2(c.x - m._w(gl, fs, m.bold) * 0.5, c.y + fs * 0.36), gl, fs, gc, m.bold)
	if why == "sealed":
		m.draw_line(c + Vector2(-nr, -nr) * 0.8, c + Vector2(nr, nr) * 0.8, Color(0.6, 0.1, 0.1, 0.9), maxf(1.0, 2.0 * u))
	if Skills.max_rank(id) > 1:
		var rt := "%d/%d" % [rk, Skills.max_rank(id)]
		m._text(Vector2(c.x - m._w(rt, int(11 * u)) * 0.5, c.y + nr + 13 * u), rt, int(11 * u), Color(0.7, 0.68, 0.62))


static func _details(m, r: Rect2) -> void:
	var g = m.game
	var p: Dictionary = g.player
	var u: float = m.u
	m.draw_line(Vector2(r.position.x - 6 * u, r.position.y - 8 * u), Vector2(r.end.x, r.position.y - 8 * u), Color(1, 1, 1, 0.1),
		maxf(1.0, u))
	if m.sel >= m.items.size() or m.items[m.sel].type != "skill":
		m._para(Vector2(r.position.x, r.position.y + 22 * u), g.L("sk_intro"), r.size.x, int(14 * u), Color(0.72, 0.75, 0.72))
		return
	var id: String = m.items[m.sel].id
	var n: Dictionary = Skills.NODES[id]
	var why := Skills.block_reason(p, id)
	var status := ""
	var sc := Color(0.6, 0.62, 0.6)
	match why:
		"":
			status = "[Enter] " + g.L("sk_learn")
			sc = Color(1.0, 0.85, 0.45)
		"maxed":
			status = g.L("sk_learned")
			sc = Skills.BRANCH_COLORS[n.branch]
		"sealed":
			status = g.L("sk_why_sealed")
			sc = Color(0.85, 0.35, 0.3)
		_:
			status = g.L("sk_why_" + why)
	var ss := int(14 * u)
	var sw: float = m._w(status, ss, m.bold)
	m._text(Vector2(r.end.x - sw, r.position.y + 16 * u), status, ss, sc, m.bold)
	var title: String = g.L("sk_" + id)
	if n.branch != "core":
		title += "  ·  " + g.L("sk_" + n.branch)
	var tc: Color = Skills.BRANCH_COLORS[n.branch]
	m._text_fit(Vector2(r.position.x, r.position.y + 16 * u), title, int(19 * u), r.size.x - sw - 20 * u, tc, m.bold)
	m._para(Vector2(r.position.x, r.position.y + 44 * u), g.L("sk_" + id + "_d"), r.size.x, int(14 * u), Color(0.8, 0.83, 0.8))
