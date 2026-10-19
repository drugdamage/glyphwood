## Interactive objects and arena rooms: chests, shrines, the merchant, signs,
## and arenas whose gates close until every wave (or the boss) is defeated.
extends RefCounted

const D := preload("res://scripts/data.gd")
const Items := preload("res://scripts/items.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Combat := preload("res://scripts/combat.gd")

const REACH := Vector2(30, 34)


## The prop the hero can use right now, or an empty Dictionary.
static func nearest(g) -> Dictionary:
	var p: Dictionary = g.player
	if p.dead:
		return {}
	var c := Physics.foot(p)
	var best := {}
	var best_d := 9999.0
	for pr in g.props:
		if pr.kind == "chest" and pr.open:
			continue
		if pr.kind == "shrine" and pr.used:
			continue
		var d: Vector2 = pr.pos - c
		if absf(d.x) < REACH.x and absf(d.y) < REACH.y and absf(d.x) < best_d:
			best = pr
			best_d = absf(d.x)
	return best


static func interact(g, pr: Dictionary) -> void:
	match pr.kind:
		"chest":
			open_chest(g, pr)
		"shrine":
			var p: Dictionary = g.player
			pr.used = true
			p.hp = p.max_hp
			p.flasks = p.max_flasks
			p.ink = Hero.MAX_INK
			g.sfx("shrine")
			g.toast(g.L("toast_shrine"), Color(0.55, 1.0, 0.75))
			Combat.burst(g, pr.pos - Vector2(0, 20), ["+", "*", "·"], Color(0.55, 1.0, 0.75), 30, 140.0, -80.0)
		"shop":
			if pr.stock.is_empty():
				var ex: Array = []
				for i in 3:
					var id := Items.random_unowned(g.player, g.rng, ex)
					if id != "":
						ex.append(id)
				pr.stock = ex
			g.open_shop(pr)
		"sign":
			g.read_sign(pr)


static func open_chest(g, pr: Dictionary) -> void:
	var p: Dictionary = g.player
	pr.open = true
	g.sfx("chest")
	g.shake_add(2.0)
	var at: Vector2 = pr.pos - Vector2(0, 14)
	Combat.burst(g, at, ["*", "·", "+"], Color(1.0, 0.85, 0.4), 20, 130.0, -80.0)
	var id := Items.random_unowned(p, g.rng) if g.rng.randf() < 0.6 else ""
	if id != "":
		var equipped := Items.give(p, id)
		Hero.refresh(p)
		g.sfx("item", -2.0)
		g.item_found(id, equipped)
	else:
		Combat.drop_shards(g, at, g.rng.randi_range(18, 30))
		if g.rng.randf() < 0.5:
			g.pickups.append({"kind": "heart", "pos": at})


# ---------------------------------------------------------------- arenas

static func update_arenas(g) -> void:
	var p: Dictionary = g.player
	if p.dead:
		return
	var pc := Physics.center(p)
	for ar in g.lv.arenas:
		match ar.state:
			"idle":
				if ar.rect.has_point(pc):
					ar.state = "active"
					ar.alive = []
					_gates(g, ar, true)
					if ar.boss:
						g.boss_started()
					_spawn_wave(g, ar)
			"active":
				var any := false
				for e in g.enemies:
					if ar.alive.has(e.id):
						any = true
						break
				if not any:
					ar.wave += 1
					if ar.wave < ar.waves.size():
						_spawn_wave(g, ar)
					else:
						ar.state = "done"
						_gates(g, ar, false)
						if not ar.boss:
							var r: Dictionary = ar.room
							var x: int = r.x0 + D.ROOM_W / 2
							g.props.append({"kind": "chest", "pos": Vector2((x + 0.5) * D.TILE, (r.y0 + D.EDGE_FLOOR) * D.TILE),
								"open": false})
							g.toast(g.L("toast_arena"), Color(1.0, 0.85, 0.4))
							g.sfx("item", -4.0)


static func _gates(g, ar: Dictionary, close: bool) -> void:
	for t in ar.gates:
		g.lv.set_t(t.x, t.y, Level.GATE if close else Level.AIR)
	g.sfx("gate")
	g.shake_add(4.0)
	ar.closed = close


static func _spawn_wave(g, ar: Dictionary) -> void:
	for sd in ar.waves[ar.wave]:
		var e := Foes.create(sd.kind, sd.pos, g.level_num, g.rng, sd.elite)
		if e.boss:
			e.arena = ar.rect
			e.state = "idle"
			e.t = 1.6
			g.boss = e
		g.enemies.append(e)
		ar.alive.append(e.id)
		Combat.burst(g, Physics.center(e), ["*", "+", "·", "x"], Color(0.9, 0.8, 1.0), 14, 140.0)
	g.sfx("tele", -4.0, 0.8)
