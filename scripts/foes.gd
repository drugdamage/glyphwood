## Enemy behaviour.
##   crawler  walks back and forth, turns at walls and ledges
##   bat      hovers, then chases the player when close
##   knight   patrols; when the player is near it telegraphs with "!" and lunges
##   spitter  stands still and fires glyph projectiles at the player
extends RefCounted

const D := preload("res://scripts/data.gd")
const Physics := preload("res://scripts/physics.gd")

const GRAVITY := 1300.0

static var _next_id := 0


static func create(kind: String, foot: Vector2, level_num: int, rng: RandomNumberGenerator) -> Dictionary:
	var def: Dictionary = D.ENEMIES[kind]
	var size: Vector2 = def.size
	var hp := int(ceil(def.hp * (1.0 + 0.3 * (level_num - 1))))
	_next_id += 1
	return {
		"id": _next_id, "kind": kind, "pos": foot - Vector2(size.x * 0.5, size.y), "size": size,
		"vel": Vector2.ZERO, "on_floor": false, "on_wall": 0,
		"hp": hp, "max_hp": hp, "dir": -1 if rng.randf() < 0.5 else 1,
		"flash": 0.0, "stun": 0.0, "state": "idle", "t": rng.randf_range(0.5, 1.5),
		"anim": rng.randf() * 3.0, "home": foot - Vector2(0, size.y * 0.5), "aggro": false,
	}


static func frame(e: Dictionary) -> Array:
	var def: Dictionary = D.ENEMIES[e.kind]
	if e.kind == "knight" and e.state == "lunge":
		return def.lunge[0]
	if e.kind == "spitter" and e.state == "charge":
		return def.charge[0]
	var frames: Array = def.frames
	var speed := 8.0 if e.kind == "bat" else 5.0
	return frames[int(e.anim * speed) % frames.size()]


static func update(g, e: Dictionary, dt: float) -> void:
	e.anim += dt
	e.flash = maxf(0.0, e.flash - dt)
	e.stun = maxf(0.0, e.stun - dt)
	var p: Dictionary = g.player
	var to_p: Vector2 = Physics.center(p) - Physics.center(e)
	var speed: float = D.ENEMIES[e.kind].speed
	var lv = g.lv

	match e.kind:
		"crawler":
			if e.stun <= 0.0:
				e.vel.x = e.dir * speed
			else:
				e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
			e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
			Physics.move(e, lv, dt)
			if e.stun <= 0.0 and (e.on_wall != 0 or (e.on_floor and not Physics.ground_ahead(e, lv, e.dir))):
				e.dir = -e.dir

		"bat":
			e.t += dt
			if not e.aggro and to_p.length() < 150.0 and not p.dead:
				e.aggro = true
			var desired: Vector2
			if e.aggro and not p.dead:
				desired = to_p.normalized() * speed + Vector2(0, sin(e.t * 7.0) * 60.0)
			else:
				desired = (e.home - Physics.center(e)) * 1.5 + Vector2(sin(e.t * 1.3) * 25.0, cos(e.t * 1.9) * 18.0)
			if e.stun > 0.0:
				e.vel = e.vel.move_toward(Vector2.ZERO, 500.0 * dt)
			else:
				e.vel = e.vel.move_toward(desired, 300.0 * dt)
			e.dir = 1 if e.vel.x >= 0.0 else -1
			Physics.move(e, lv, dt, true, false)

		"knight":
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

		"spitter":
			e.t -= dt
			e.dir = 1 if to_p.x > 0.0 else -1
			if e.state == "idle" and e.t <= 0.0 and to_p.length() < 250.0 and not p.dead:
				e.state = "charge"
				e.t = 0.5
			elif e.state == "charge" and e.t <= 0.0:
				var from: Vector2 = Physics.center(e) + Vector2(0, -4)
				g.fire(from, to_p.normalized() * 165.0)
				e.state = "idle"
				e.t = 1.9
			e.vel.x = move_toward(e.vel.x, 0.0, 600.0 * dt)
			e.vel.y = minf(e.vel.y + GRAVITY * dt, 500.0)
			Physics.move(e, lv, dt)
