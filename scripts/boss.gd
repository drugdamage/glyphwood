## Boss behaviour. Each biome ends with one; below half health they enter a
## faster second phase.
##   warden    Moss Warden: walks, leaps and sends shockwaves along the floor, spits spores
##   wraith    Bell Wraith: floats, fires rings of orbs, dives at the player, summons wisps
##   colossus  Ember Colossus: charges into walls, slams fire pillars, rains embers
extends RefCounted

const D := preload("res://scripts/data.gd")
const Physics := preload("res://scripts/physics.gd")

const GRAVITY := 1300.0


static func update(g, e: Dictionary, dt: float) -> void:
	e.t -= dt
	if e.phase == 1 and e.hp < e.max_hp * 0.5:
		e.phase = 2
		e.state = "enrage"
		e.t = 1.0
		e.vel = Vector2.ZERO
		g.sfx("roar")
		g.shake_add(10.0)
		if e.kind == "wraith":
			for side in [-1, 1]:
				g.spawn_enemy("wisp", Physics.center(e) + Vector2(side * 60, 0))
	if e.get("stagger", 0.0) > 0.0:
		e.stagger -= dt
		e.flash = 0.04 if int(e.stagger * 10.0) % 2 == 0 else 0.0
		if e.fly:
			e.vel = e.vel.move_toward(Vector2(0, 30.0), 400.0 * dt)
			e.pos += e.vel * dt
		else:
			e.vel.x = 0.0
			_fall(e, g.lv, dt)
		return
	match e.kind:
		"warden":
			_warden(g, e, dt)
		"wraith":
			_wraith(g, e, dt)
		"colossus":
			_colossus(g, e, dt)


static func _face(g, e: Dictionary) -> float:
	var dx: float = Physics.center(g.player).x - Physics.center(e).x
	e.dir = 1 if dx > 0.0 else -1
	return dx


static func _fall(e: Dictionary, lv, dt: float) -> void:
	e.vel.y = minf(e.vel.y + GRAVITY * dt, 700.0)
	Physics.move(e, lv, dt)


# ---------------------------------------------------------------- warden

static func _warden(g, e: Dictionary, dt: float) -> void:
	var lv = g.lv
	var fast := 1.35 if e.phase == 2 else 1.0
	match e.state:
		"idle", "enrage":
			e.vel.x = move_toward(e.vel.x, 0.0, 800.0 * dt)
			if e.t <= 0.0:
				e.state = "walk"
				e.t = g.rng.randf_range(1.0, 1.8) / fast
		"walk":
			var dx := _face(g, e)
			e.vel.x = e.dir * D.ENEMIES.warden.speed * fast if absf(dx) > 30.0 else 0.0
			if e.t <= 0.0:
				var r: float = g.rng.randf()
				e.state = "crouch" if r < 0.6 else "spores"
				e.t = 0.55 / fast
				e.vel.x = 0.0
				g.sfx("tele", -2.0, 0.6)
		"crouch":
			e.vel.x = 0.0
			if e.t <= 0.0:
				var dx2 := _face(g, e)
				e.vel = Vector2(clampf(dx2 * 1.4, -360.0, 360.0), -560.0)
				e.state = "leap"
				e.t2 = 1.0 if e.phase == 2 else 0.0
		"leap":
			if e.on_floor and e.vel.y >= 0.0:
				_land_wave(g, e)
				if e.t2 > 0.0:
					e.t2 = 0.0
					e.state = "crouch"
					e.t = 0.3
				else:
					e.state = "idle"
					e.t = 0.8 / fast
		"spores":
			e.vel.x = 0.0
			if e.t <= 0.0:
				var n := 5 if e.phase == 2 else 3
				var from: Vector2 = Physics.center(e) + Vector2(e.dir * 20, -16)
				var dx3: float = Physics.center(g.player).x - from.x
				for i in n:
					var vx: float = dx3 * g.rng.randf_range(0.7, 1.3) / 1.1
					g.fire(from, Vector2(vx, -380.0 + i * 25.0), "enemy", 1, 600.0, "spore")
				g.sfx("fire", -2.0, 0.6)
				e.state = "idle"
				e.t = 1.0 / fast
	_fall(e, lv, dt)


static func _land_wave(g, e: Dictionary) -> void:
	g.sfx("slam")
	g.shake_add(9.0)
	var foot := Physics.foot(e)
	for side in [-1, 1]:
		g.fire(foot + Vector2(side * 30, -6), Vector2(side * 230, 0), "enemy", 1, 0.0, "wave")
	g.burst(foot, [".", ",", "'", "*"], g.biome.edge, 24, 160.0, -60.0)


# ---------------------------------------------------------------- wraith

static func _wraith(g, e: Dictionary, dt: float) -> void:
	var p: Dictionary = g.player
	var c := Physics.center(e)
	var arena: Rect2 = e.arena
	var fast := 1.3 if e.phase == 2 else 1.0
	e.t2 -= dt
	match e.state:
		"idle", "enrage":
			e.vel = e.vel.move_toward(Vector2.ZERO, 300.0 * dt)
			if e.t <= 0.0:
				e.state = "drift"
				e.t = g.rng.randf_range(1.8, 2.6)
		"drift":
			var target := Vector2(Physics.center(p).x + sin(e.anim) * 80.0, arena.position.y + 70.0)
			e.vel = e.vel.move_toward((target - c).limit_length(D.ENEMIES.wraith.speed * fast), 260.0 * dt)
			_face(g, e)
			if e.t2 <= 0.0:
				e.t2 = 1.2 / fast
				g.fire(c + Vector2(0, 14), (Physics.center(p) - c).normalized() * 150.0, "enemy", 1, 0.0, "orb")
				g.sfx("fire", -8.0, 1.3)
			if e.t <= 0.0:
				e.state = "ring" if g.rng.randf() < 0.5 else "tele"
				e.t = 0.7 / fast
				e.target = Physics.center(p)
				g.sfx("tele", -2.0, 0.8)
		"ring":
			e.vel = e.vel.move_toward(Vector2.ZERO, 600.0 * dt)
			if e.t <= 0.0:
				var n := 14 if e.phase == 2 else 10
				var off: float = g.rng.randf() * TAU
				for i in n:
					var a := off + TAU * i / n
					g.fire(c, Vector2(cos(a), sin(a)) * 130.0, "enemy", 1, 0.0, "orb")
				g.sfx("fire", 0.0, 0.7)
				e.state = "idle"
				e.t = 0.9 / fast
		"tele":
			e.vel = e.vel.move_toward(Vector2.ZERO, 600.0 * dt)
			if e.t <= 0.0:
				e.state = "dive"
				e.t = 0.75
				e.vel = (e.target - c).normalized() * 430.0 * fast
		"dive":
			if e.t <= 0.0 or (c.y > arena.end.y - 50.0 and e.vel.y > 0.0):
				e.state = "rise"
				e.t = 0.8
				g.shake_add(4.0)
		"rise":
			e.vel = e.vel.move_toward(Vector2(0, -160), 900.0 * dt)
			if e.t <= 0.0:
				e.state = "idle"
				e.t = 0.4
	e.pos += e.vel * dt
	e.pos.x = clampf(e.pos.x, arena.position.x, arena.end.x - e.size.x)
	e.pos.y = clampf(e.pos.y, arena.position.y, arena.end.y - e.size.y - 16.0)


# ---------------------------------------------------------------- colossus

static func _colossus(g, e: Dictionary, dt: float) -> void:
	var lv = g.lv
	var fast := 1.3 if e.phase == 2 else 1.0
	match e.state:
		"idle", "enrage":
			e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
			if e.t <= 0.0:
				e.state = "walk"
				e.t = g.rng.randf_range(1.0, 1.6) / fast
		"walk":
			var dx := _face(g, e)
			e.vel.x = e.dir * D.ENEMIES.colossus.speed * fast if absf(dx) > 40.0 else 0.0
			if e.t <= 0.0:
				var r: float = g.rng.randf()
				e.vel.x = 0.0
				if r < 0.4:
					e.state = "tele"
					e.t = 0.6 / fast
					g.sfx("tele", -2.0, 0.5)
				elif r < 0.75:
					e.state = "raise"
					e.t = 0.7 / fast
				else:
					e.state = "rain"
					e.t = 0.5
		"tele":
			_face(g, e)
			e.vel.x = 0.0
			e.flash = 0.03 if int(e.t * 14.0) % 2 == 0 else 0.0
			if e.t <= 0.0:
				e.state = "charge"
				e.t = 2.0
				g.sfx("roar", -4.0, 1.3)
		"charge":
			e.vel.x = e.dir * 320.0 * fast
			if e.on_wall != 0 or e.t <= 0.0:
				e.state = "stunned"
				e.t = 1.3
				e.vel.x = -e.dir * 80.0
				g.sfx("slam")
				g.shake_add(12.0)
				for i in 5:
					var x: float = g.rng.randf_range(e.arena.position.x + 20.0, e.arena.end.x - 20.0)
					g.fire(Vector2(x, e.arena.position.y + 4.0), Vector2(0, 40), "enemy", 1, 500.0, "rock", i * 0.15)
		"stunned":
			e.vel.x = move_toward(e.vel.x, 0.0, 400.0 * dt)
			if e.t <= 0.0:
				e.state = "idle"
				e.t = 0.4
		"raise":
			e.vel.x = 0.0
			if e.t <= 0.0:
				e.state = "slam"
				e.t = 0.6
				g.sfx("slam")
				g.shake_add(8.0)
				var px: float = Physics.center(g.player).x
				var n := 5 if e.phase == 2 else 3
				for i in n:
					var x2: float = px + (i - (n - 1) * 0.5) * 70.0 + g.rng.randf_range(-12.0, 12.0)
					x2 = clampf(x2, e.arena.position.x + 10.0, e.arena.end.x - 10.0)
					g.add_pillar(x2, Physics.foot(e).y)
		"slam":
			if e.t <= 0.0:
				e.state = "idle"
				e.t = 0.6 / fast
		"rain":
			e.vel.x = 0.0
			if e.t <= 0.0:
				var n2 := 12 if e.phase == 2 else 8
				for i in n2:
					var x3: float = g.rng.randf_range(e.arena.position.x + 16.0, e.arena.end.x - 16.0)
					g.fire(Vector2(x3, e.arena.position.y + 4.0), Vector2(0, 60), "enemy", 1, 380.0, "ember", i * 0.14)
				g.sfx("roar", -8.0, 1.6)
				e.state = "idle"
				e.t = 1.4 / fast
	_fall(e, lv, dt)
