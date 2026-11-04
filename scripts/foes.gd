## Enemy behaviour.
##   crawler  walks back and forth, turns at walls and ledges, hurries when it sees you
##   hopper   leaps toward the player
##   bat      hovers, then chases the player when close
##   spitter  stands still and fires glyph projectiles at the player
##   knight   patrols; when the player is near it telegraphs with "!" and lunges
##   shield   advances slowly and blocks hits from the front; strike from above or behind
##   wisp     drifts through walls toward the player
##   archer   keeps its distance and lobs arrows
##   bomber   runs at the player, lights its fuse and explodes
##   toad     bog toad: leaps like a ghoul and spits bile in an arc
##   hanged   hangs from the ceiling on a rope and drops on whoever passes below
##   choir    a floating choir skull that sings slow fans of bell notes
##   penitent flagellant: winds up, then whirls at the player with its scourge
##   wight    frost wight: keeps its distance and throws shards that chill
## Bosses are handled in boss.gd.
extends RefCounted

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const SpriteCache := preload("res://scripts/sprite_cache.gd")
const Physics := preload("res://scripts/physics.gd")
const Boss := preload("res://scripts/boss.gd")

const GRAVITY := 1300.0

static var _next_id := 0
## Enemy health and speed multipliers of the current world's difficulty (set by main.gd).
static var hp_mult := 1.0
static var speed_mult := 1.0
## Burn damage per tick: a base plus a share of the hero's blow, so fire keeps up with depth.
const BURN_BASE := 3.0
const BURN_SHARE := 0.15


static func create(kind: String, foot: Vector2, level_num: int, rng: RandomNumberGenerator, elite: bool = false) -> Dictionary:
	var def: Dictionary = D.ENEMIES[kind]
	var size: Vector2 = def.size
	var boss := D.BOSSES.has(kind)
	var scale := 1.0 + 0.16 * D.depth(level_num)
	if boss:
		scale = 1.0 + 0.2 * D.depth(level_num)
	var hp := int(ceil(def.hp * scale * (2.0 if elite else 1.0) * hp_mult))
	_next_id += 1
	return {
		"id": _next_id, "kind": kind, "pos": foot - Vector2(size.x * 0.5, size.y), "size": size,
		"vel": Vector2.ZERO, "on_floor": false, "on_wall": 0, "boss": boss, "elite": elite,
		"hp": hp, "max_hp": hp, "dir": -1 if rng.randf() < 0.5 else 1,
		"flash": 0.0, "stun": 0.0, "state": "idle", "t": rng.randf_range(0.5, 1.5), "t2": 0.0,
		"anim": rng.randf() * 3.0, "home": foot - Vector2(0, size.y * 0.5), "aggro": false,
		"burn": 0.0, "thorn_t": 0.0, "parried": 0.0, "phase": 1, "fly": def.fly, "chill": 0.0,
	}


static func frame(e: Dictionary) -> Variant:
	var def: Dictionary = SpriteCache.foe_def(e.kind)
	var anim := "move"
	match e.kind:
		"knight":
			if e.state == "tele" or e.state == "lunge":
				anim = e.state
		"spitter":
			anim = "charge" if e.state == "charge" else "idle"
		"hopper":
			anim = "idle" if e.on_floor else "jump"
		"shield":
			anim = "guard" if e.state == "guard" else "move"
		"archer":
			anim = "aim" if e.state == "aim" else "move"
		"toad":
			anim = "idle" if e.on_floor else "jump"
		"hanged":
			anim = "hang" if e.state == "hang" else "move"
		"choir":
			anim = "sing" if e.state == "sing" else "move"
		"penitent":
			anim = "whirl" if e.state in ["tele", "whirl"] else "move"
		"wight":
			anim = "aim" if e.state == "aim" else "move"
		"hangman":
			anim = "raise" if e.state in ["raise", "hook", "crouch"] else "move"
		"abbess":
			anim = "cast" if e.state in ["hymn", "light", "tele"] else "move"
		"frost_king":
			anim = "raise" if e.state in ["raise", "breath"] else "move"
		"warden":
			anim = "crouch" if e.state in ["crouch", "spores"] else "move"
		"wraith":
			anim = "cast" if e.state in ["ring", "tele"] else "move"
		"colossus":
			anim = "raise" if e.state in ["raise", "slam"] else "move"
	var frames: Array = def.get(anim, def.get("move", def.get("idle")))
	var speed := 8.0 if e.fly else 5.0
	if e.kind not in ["hopper", "toad"] and absf(e.vel.x) < 1.0 and not e.fly and frames.size() > 1:
		return frames[0]
	return frames[int(e.anim * speed) % frames.size()]


static func update(g, e: Dictionary, dt: float) -> void:
	# a chilled foe (Frost Crown) moves and thinks at a slower pace
	if e.chill > 0.0:
		e.chill -= dt
		dt *= 0.75 if e.boss else 0.55
	e.anim += dt
	e.flash = maxf(0.0, e.flash - dt)
	e.stun = maxf(0.0, e.stun - dt)
	e.thorn_t = maxf(0.0, e.thorn_t - dt)
	e.parried = maxf(0.0, e.get("parried", 0.0) - dt)
	if e.burn > 0.0:
		e.burn -= dt
		e.t2 += dt
		if e.t2 >= 0.5:
			e.t2 = 0.0
			var pst: Dictionary = g.player.st
			g.hurt_enemy(e, BURN_BASE + BURN_SHARE * pst.dmg * pst.dmg_mult, Vector2.ZERO, false)
			if e.hp <= 0:
				return
	if e.boss:
		Boss.update(g, e, dt)
		return
	var p: Dictionary = g.player
	var to_p: Vector2 = Physics.center(p) - Physics.center(e)
	var speed: float = D.ENEMIES[e.kind].speed * (1.15 if e.elite else 1.0) * speed_mult
	var lv = g.lv
	var sees: bool = not p.dead and absf(to_p.x) < 220.0 and absf(to_p.y) < 70.0

	match e.kind:
		"crawler":
			var sp := speed * (1.7 if sees and signf(to_p.x) == e.dir else 1.0)
			_ground(e, lv, dt, sp)

		"hopper":
			e.t -= dt
			if e.on_floor:
				e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
				if e.t <= 0.0 and to_p.length() < 230.0 and not p.dead and e.stun <= 0.0:
					e.dir = 1 if to_p.x > 0.0 else -1
					e.vel = Vector2(e.dir * speed * g.rng.randf_range(0.8, 1.2), -330.0)
					e.t = g.rng.randf_range(0.9, 1.5)
			e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
			Physics.move(e, lv, dt)

		"bat":
			e.t += dt
			if not e.aggro and to_p.length() < 150.0 and not p.dead:
				e.aggro = true
			var desired: Vector2
			if e.aggro and not p.dead:
				desired = to_p.normalized() * speed + Vector2(0, sin(e.t * 7.0) * 60.0)
			else:
				desired = (e.home - Physics.center(e)) * 1.5 + Vector2(sin(e.t * 1.3) * 25.0, cos(e.t * 1.9) * 18.0)
			_fly(e, lv, dt, desired, true)

		"wisp":
			e.t += dt
			if not e.aggro and to_p.length() < 200.0 and not p.dead:
				e.aggro = true
			var want := Vector2(sin(e.t) * 20.0, cos(e.t * 1.3) * 15.0)
			if e.aggro and not p.dead:
				want = to_p.normalized() * speed + Vector2(0, sin(e.t * 3.0) * 30.0)
			if e.stun > 0.0:
				e.vel = e.vel.move_toward(Vector2.ZERO, 400.0 * dt)
			else:
				e.vel = e.vel.move_toward(want, 120.0 * dt)
			e.dir = 1 if e.vel.x >= 0.0 else -1
			e.pos += e.vel * dt

		"spitter":
			e.t -= dt
			e.dir = 1 if to_p.x > 0.0 else -1
			if e.state == "idle" and e.t <= 0.0 and to_p.length() < 260.0 and not p.dead:
				e.state = "charge"
				e.t = 0.5
			elif e.state == "charge" and e.t <= 0.0:
				var from: Vector2 = Physics.center(e) + Vector2(0, -6)
				g.fire(from, to_p.normalized() * 165.0, "enemy", 1)
				g.sfx("fire", -6.0)
				e.state = "idle"
				e.t = 1.9
			_settle(e, lv, dt)

		"knight":
			_knight(g, e, lv, dt, to_p, speed)

		"toad":
			e.t -= dt
			if e.on_floor:
				e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
				if e.t <= 0.0 and to_p.length() < 260.0 and not p.dead and e.stun <= 0.0:
					e.dir = 1 if to_p.x > 0.0 else -1
					if g.rng.randf() < 0.45:
						_shoot_arc(g, e, Physics.center(p), "bile")
						e.t = 1.4
					else:
						e.vel = Vector2(e.dir * speed * g.rng.randf_range(0.8, 1.2), -300.0)
						e.t = g.rng.randf_range(0.8, 1.3)
			e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
			Physics.move(e, lv, dt)

		"hanged":
			_hanged(g, e, lv, dt, to_p, speed)

		"choir":
			e.t -= dt
			if not e.aggro and to_p.length() < 220.0 and not p.dead:
				e.aggro = true
			var bob := Vector2(sin(e.anim * 1.7) * 18.0, cos(e.anim * 2.3) * 12.0)
			var goal: Vector2 = e.home + bob
			if e.aggro and not p.dead:
				goal = Physics.center(p) + Vector2(-signf(to_p.x) * 110.0, -70.0) + bob
			_fly(e, lv, dt, (goal - Physics.center(e)).limit_length(speed * 2.0), true)
			if e.aggro and e.t <= 0.0 and e.state != "sing":
				e.state = "sing"
				e.t = 0.6
				g.sfx("tele", -10.0, 1.6)
			elif e.state == "sing" and e.t <= 0.0:
				var aim := to_p.angle()
				for k in 3:
					var a := aim + (k - 1) * 0.3
					g.fire(Physics.center(e), Vector2(cos(a), sin(a)) * 110.0, "enemy", 1, 0.0, "bell")
				g.sfx("bell", -12.0, 1.8)
				e.state = "idle"
				e.t = 2.4

		"penitent":
			e.t -= dt
			match e.state:
				"tele":
					e.vel.x = 0.0
					if e.t <= 0.0:
						e.state = "whirl"
						e.t = 0.8
				"whirl":
					e.vel.x = e.dir * 230.0
					if not Physics.ground_ahead(e, lv, e.dir) or e.on_wall != 0:
						e.vel.x = 0.0
					if e.t <= 0.0:
						e.state = "rest"
						e.t = 1.0
				"rest":
					e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
					if e.t <= 0.0:
						e.state = "idle"
				_:
					if sees and absf(to_p.x) < 130.0 and e.t <= 0.0 and e.on_floor:
						e.state = "tele"
						e.t = 0.45
						e.dir = 1 if to_p.x > 0.0 else -1
						g.sfx("tele", -6.0, 0.8)
					elif e.stun <= 0.0:
						e.vel.x = e.dir * speed
						if e.on_wall != 0 or (e.on_floor and not Physics.ground_ahead(e, lv, e.dir)):
							e.dir = -e.dir
			if e.stun > 0.0:
				e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
			e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
			Physics.move(e, lv, dt)

		"wight":
			e.t -= dt
			if sees and e.on_floor:
				e.dir = 1 if to_p.x > 0.0 else -1
				if e.state != "aim" and absf(to_p.x) < 70.0 and Physics.ground_ahead(e, lv, -e.dir):
					e.vel.x = -e.dir * speed
				elif e.state != "aim" and e.t <= 0.0:
					e.state = "aim"
					e.t = 0.6
					e.vel.x = 0.0
				elif e.state != "aim":
					e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
				if e.state == "aim" and e.t <= 0.0:
					var from: Vector2 = Physics.center(e) + Vector2(e.dir * 8.0, -6.0)
					g.fire(from, (Physics.center(p) - from).normalized() * 190.0, "enemy", 1, 0.0, "frost")
					g.sfx("throw", -8.0, 1.4)
					e.state = "idle"
					e.t = 2.0
				e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
				Physics.move(e, lv, dt)
			else:
				if e.state == "aim":
					e.state = "idle"
				_ground(e, lv, dt, speed * 0.6)

		"shield":
			e.t -= dt
			if sees:
				e.aggro = true
			if e.aggro and not p.dead:
				var face := 1 if to_p.x > 0.0 else -1
				if e.state == "turn":
					if e.t <= 0.0:
						e.dir = face
						e.state = "idle"
				elif face != e.dir:
					e.state = "turn"
					e.t = 0.55
				else:
					e.state = "guard" if absf(to_p.x) < 40.0 else "idle"
				var sp2: float = 0.0 if (e.state == "turn" or absf(to_p.x) < 20.0) else speed * 1.2
				_ground(e, lv, dt, sp2, false)
			else:
				_ground(e, lv, dt, speed)


		"archer":
			e.t -= dt
			if sees and e.on_floor:
				e.dir = 1 if to_p.x > 0.0 else -1
				if e.state != "aim" and absf(to_p.x) < 80.0 and Physics.ground_ahead(e, lv, -e.dir):
					e.vel.x = -e.dir * speed
				elif e.state != "aim" and e.t <= 0.0:
					e.state = "aim"
					e.t = 0.7
					e.vel.x = 0.0
				elif e.state != "aim":
					e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
				if e.state == "aim" and e.t <= 0.0:
					_shoot_arc(g, e, Physics.center(p))
					e.state = "idle"
					e.t = 1.7
				e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
				Physics.move(e, lv, dt)
			else:
				if e.state == "aim":
					e.state = "idle"
				_ground(e, lv, dt, speed * 0.6)

		"bomber":
			e.t -= dt
			if e.state == "fuse":
				e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
				if int(e.t * 12.0) % 2 == 0:
					e.flash = 0.05
				if e.t <= 0.0:
					g.explode(Physics.center(e), 56.0, true)
					e.hp = 0
					g.remove_enemy(e)
					return
				e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
				Physics.move(e, lv, dt)
			elif sees:
				e.dir = 1 if to_p.x > 0.0 else -1
				if to_p.length() < 30.0:
					e.state = "fuse"
					e.t = 0.6
					g.sfx("tele", -4.0, 0.7)
				_ground(e, lv, dt, speed * 1.5, false)
			else:
				_ground(e, lv, dt, speed * 0.5)


## Walks along the ground, turning at walls and ledges.
static func _ground(e: Dictionary, lv, dt: float, speed: float, turn: bool = true) -> void:
	if e.stun <= 0.0:
		e.vel.x = e.dir * speed
		if not turn and e.on_floor and not Physics.ground_ahead(e, lv, e.dir):
			e.vel.x = 0.0
	else:
		e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
	e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
	Physics.move(e, lv, dt)
	if turn and e.stun <= 0.0 and (e.on_wall != 0 or (e.on_floor and not Physics.ground_ahead(e, lv, e.dir))):
		e.dir = -e.dir


static func _settle(e: Dictionary, lv, dt: float) -> void:
	e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
	e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
	Physics.move(e, lv, dt)


static func _fly(e: Dictionary, lv, dt: float, desired: Vector2, collide: bool) -> void:
	if e.stun > 0.0:
		e.vel = e.vel.move_toward(Vector2.ZERO, 500.0 * dt)
	else:
		e.vel = e.vel.move_toward(desired, 300.0 * dt)
	e.dir = 1 if e.vel.x >= 0.0 else -1
	if collide:
		Physics.move(e, lv, dt, true, false)
	else:
		e.pos += e.vel * dt


static func _knight(g, e: Dictionary, lv, dt: float, to_p: Vector2, speed: float) -> void:
	var p: Dictionary = g.player
	e.t -= dt
	match e.state:
		"idle":
			if e.stun <= 0.0:
				e.vel.x = e.dir * speed
			if e.on_wall != 0 or (e.on_floor and not Physics.ground_ahead(e, lv, e.dir)):
				e.dir = -e.dir
			if absf(to_p.x) < 140.0 and absf(to_p.y) < 50.0 and e.on_floor and not p.dead and e.t <= 0.0:
				e.state = "tele"
				e.t = 0.45
				e.dir = 1 if to_p.x > 0.0 else -1
				g.sfx("tele", -6.0)
		"tele":
			e.vel.x = 0.0
			if e.t <= 0.0:
				e.state = "lunge"
				e.t = 0.32
		"lunge":
			e.vel.x = e.dir * 290.0
			if not Physics.ground_ahead(e, lv, e.dir) or e.on_wall != 0:
				e.vel.x = 0.0
				e.t = 0.0
			if e.t <= 0.0:
				e.state = "rest"
				e.t = 0.6
		"rest":
			e.vel.x = move_toward(e.vel.x, 0.0, 900.0 * dt)
			if e.t <= 0.0:
				e.state = "idle"
				e.t = 0.8
	if e.stun > 0.0:
		e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
	e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
	Physics.move(e, lv, dt)


## Hangs on a rope until someone walks below, drops, then hunts on foot.
static func _hanged(g, e: Dictionary, lv, dt: float, to_p: Vector2, speed: float) -> void:
	if e.state == "idle":
		# find the ceiling above the spawn point and string it up there
		var tx := int(floor(Physics.center(e).x / D.TILE))
		var ty := int(floor(e.pos.y / D.TILE))
		var top := -1
		for k in range(1, 9):
			if lv.solid(tx, ty - k):
				top = ty - k
				break
		if top < 0:
			e.state = "walk"
		else:
			e.rope_y = (top + 1) * D.TILE
			e.pos.y = e.rope_y + 18.0
			e.state = "hang"
		return
	if e.state == "hang":
		e.vel = Vector2.ZERO
		e.pos.x += sin(e.anim * 1.4) * 4.0 * dt
		if (absf(to_p.x) < 46.0 and to_p.y > 0.0 and to_p.y < 190.0 and not g.player.dead) or e.flash > 0.0:
			e.state = "walk"
			e.aggro = true
			g.sfx("tele", -6.0, 0.6)
		return
	if e.aggro and e.on_floor and e.stun <= 0.0:
		e.dir = 1 if to_p.x > 0.0 else -1
	_ground(e, lv, dt, speed * (1.5 if e.aggro else 1.0), not e.aggro)


## Fires an arrow on a ballistic arc that lands near the target.
static func _shoot_arc(g, e: Dictionary, target: Vector2, kind: String = "arrow") -> void:
	var from: Vector2 = Physics.center(e) + Vector2(e.dir * 8.0, -6.0)
	var grav := 500.0
	var d := target - from
	var tt := clampf(absf(d.x) / 230.0, 0.35, 1.3)
	var v := Vector2(d.x / tt, d.y / tt - 0.5 * grav * tt)
	g.fire(from, v, "enemy", 1, grav, kind)
	g.sfx("throw" if kind == "arrow" else "splash", -8.0, 0.7)


## True if a hit from this direction is blocked by the shield.
static func blocks(e: Dictionary, hit_from_x: float, kind: String) -> bool:
	if e.kind != "shield" or e.stun > 0.0 or e.state == "turn":
		return false
	if kind == "up" or kind == "down":
		return false
	var side := 1 if hit_from_x > Physics.center(e).x else -1
	return side == e.dir
