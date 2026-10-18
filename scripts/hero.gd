## Player controller: run, variable jump, coyote time, jump buffer, dash,
## wall slide and wall jump, three-hit combo, up/down slashes with pogo, healing.
extends RefCounted

const D := preload("res://scripts/data.gd")
const Physics := preload("res://scripts/physics.gd")
const Level := preload("res://scripts/level.gd")

const RUN := 150.0
const JUMP := 430.0
const GRAVITY := 1300.0
const MAX_FALL := 520.0
const WALL_FALL := 80.0
const DASH_SPEED := 390.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 0.45
const ATTACK_TIME := 0.26
const POGO := 370.0


static func create(foot: Vector2) -> Dictionary:
	var size := Vector2(12, 30)
	return {
		"pos": foot - Vector2(size.x * 0.5, size.y), "size": size, "vel": Vector2.ZERO,
		"on_floor": false, "on_wall": 0, "facing": 1,
		"coyote": 0.0, "jump_buf": 0.0, "drop_t": 0.0, "wall_lock": 0.0, "sliding": false,
		"dash_t": 0.0, "dash_cd": 0.0, "air_dash": true,
		"atk_t": 0.0, "atk_kind": "side", "atk_hit": {}, "combo": 0, "combo_t": 0.0,
		"hp": 5, "max_hp": 5, "flasks": 2, "max_flasks": 2,
		"inv": 0.0, "blink": 0.0, "hurt_t": 0.0, "heal_t": 0.0,
		"respawn_t": 0.0, "safe": foot - Vector2(size.x * 0.5, size.y),
		"anim": 0.0, "dead": false, "was_floor": false, "fall_speed": 0.0,
	}


static func update(g, p: Dictionary, dt: float) -> void:
	var held: Dictionary = g.held
	var just: Dictionary = g.just
	p.anim += dt
	for k in ["coyote", "jump_buf", "drop_t", "wall_lock", "dash_cd", "atk_t", "combo_t", "inv", "blink", "hurt_t", "heal_t"]:
		p[k] = maxf(0.0, p[k] - dt)

	if p.dead:
		p.vel.y = minf(p.vel.y + GRAVITY * dt, MAX_FALL)
		p.vel.x = move_toward(p.vel.x, 0.0, 300.0 * dt)
		Physics.move(p, g.lv, dt)
		return

	if p.respawn_t > 0.0:
		p.respawn_t -= dt
		if p.respawn_t <= 0.0:
			p.pos = p.safe
			p.vel = Vector2.ZERO
			g.burst(Physics.center(p), ["·", "*", "+"], Color(0.9, 0.95, 1.0), 10, 80.0)
		return

	# healing
	if just.heal and p.flasks > 0 and p.hp < p.max_hp and p.dash_t <= 0.0:
		p.hp = mini(p.max_hp, p.hp + 2)
		p.flasks -= 1
		p.heal_t = 0.35
		g.burst(Physics.center(p), ["+", "·", "+"], Color(0.5, 1.0, 0.6), 16, 110.0, -120.0)

	# dash
	if just.dash and p.dash_cd <= 0.0 and (p.on_floor or p.air_dash) and p.hurt_t <= 0.0:
		var dirx := int(held.right) - int(held.left)
		if dirx != 0:
			p.facing = dirx
		if p.sliding:
			p.facing = -p.facing
		p.dash_t = DASH_TIME
		p.dash_cd = DASH_COOLDOWN
		if not p.on_floor:
			p.air_dash = false
		p.inv = maxf(p.inv, DASH_TIME + 0.03)
		p.atk_t = 0.0
		g.shake = maxf(g.shake, 1.5)
		g.burst(Physics.foot(p), [".", ",", "'"], g.biome.edge, 6, 60.0)

	if p.dash_t > 0.0:
		p.dash_t = maxf(0.0, p.dash_t - dt)
		p.vel = Vector2(p.facing * DASH_SPEED, 0.0)
		Physics.move(p, g.lv, dt)
		g.add_ghost(p)
		if p.dash_t <= 0.0:
			p.vel.x *= 0.35
		_after_move(g, p)
		return

	# horizontal movement
	var dirx := int(held.right) - int(held.left)
	if p.hurt_t > 0.0:
		p.vel.x = move_toward(p.vel.x, 0.0, 500.0 * dt)
	elif p.wall_lock <= 0.0:
		var accel := 1800.0 if p.on_floor else 1150.0
		p.vel.x = move_toward(p.vel.x, dirx * RUN, accel * dt)
		if dirx != 0 and p.atk_t <= 0.0:
			p.facing = dirx

	if p.on_floor:
		p.coyote = 0.1
		p.air_dash = true
	if just.jump:
		p.jump_buf = 0.12
	if g.released.jump and p.vel.y < 0.0:
		p.vel.y *= 0.45

	var wall := Physics.wall_side(p, g.lv)
	p.sliding = not p.on_floor and wall != 0 and dirx == wall and p.vel.y > 0.0 and p.hurt_t <= 0.0

	if p.jump_buf > 0.0:
		if held.down and p.on_floor and _on_oneway(p, g.lv):
			p.drop_t = 0.22
			p.jump_buf = 0.0
			p.pos.y += 1.0
		elif p.coyote > 0.0:
			p.vel.y = -JUMP
			p.coyote = 0.0
			p.jump_buf = 0.0
			g.burst(Physics.foot(p), [".", ","], g.biome.edge, 5, 50.0)
		elif wall != 0 and not p.on_floor:
			p.vel = Vector2(-wall * 210.0, -400.0)
			p.wall_lock = 0.15
			p.facing = -wall
			p.jump_buf = 0.0
			p.air_dash = true
			g.burst(Physics.center(p) + Vector2(wall * 6, 0), ["'", ".", "`"], g.biome.edge, 5, 60.0)

	var grav := GRAVITY * (1.15 if p.vel.y > 0.0 else 1.0)
	p.vel.y = minf(p.vel.y + grav * dt, WALL_FALL if p.sliding else MAX_FALL)
	if p.sliding and int(p.anim * 20.0) % 3 == 0:
		g.burst(Physics.center(p) + Vector2(wall * 7, -6), ["'", "."], g.biome.edge, 1, 20.0)

	# attack
	if just.attack and p.atk_t <= 0.0 and p.heal_t <= 0.0:
		var kind := "side"
		if held.up:
			kind = "up"
		elif held.down and not p.on_floor:
			kind = "down"
		if kind == "side":
			p.combo = (p.combo + 1) % 3 if p.combo_t > 0.0 else 0
			p.combo_t = 0.5
		p.atk_t = ATTACK_TIME
		p.atk_kind = kind
		p.atk_hit = {}
		g.add_slash(kind, p.combo if kind == "side" else 0, p.facing)

	p.fall_speed = p.vel.y
	Physics.move(p, g.lv, dt, p.drop_t > 0.0)
	_after_move(g, p)


static func _after_move(g, p: Dictionary) -> void:
	if p.on_floor and not p.was_floor and p.fall_speed > 260.0:
		g.burst(Physics.foot(p), [".", ",", "'"], g.biome.edge, 6, 70.0)
	p.was_floor = p.on_floor
	if p.on_floor and _safe_ground(p, g.lv):
		p.safe = p.pos

	if p.atk_t > 0.0:
		var elapsed: float = ATTACK_TIME - p.atk_t
		if elapsed >= 0.02 and elapsed <= 0.14:
			g.attack_hits(p, hitbox(p))

	if p.inv <= 0.0 and Physics.touches_spikes(Physics.rect(p), g.lv):
		g.hurt_player(1, Physics.center(p).x - p.facing * 10.0, true)


static func hitbox(p: Dictionary) -> Rect2:
	var c := Physics.center(p)
	match p.atk_kind:
		"up":
			return Rect2(c.x - 17, p.pos.y - 28, 34, 32)
		"down":
			return Rect2(c.x - 17, p.pos.y + p.size.y - 6, 34, 32)
	return Rect2(c.x + (2.0 if p.facing > 0 else -34.0), p.pos.y, 32, 26)


static func _on_oneway(p: Dictionary, lv) -> bool:
	var T := D.TILE
	var ty := int(floor((p.pos.y + p.size.y + 1.0) / T))
	var l := int(floor(p.pos.x / T))
	var r := int(floor((p.pos.x + p.size.x - 0.01) / T))
	for tx in range(l, r + 1):
		if lv.at(tx, ty) == Level.SOLID:
			return false
	return true


static func _safe_ground(p: Dictionary, lv) -> bool:
	var T := D.TILE
	var ty := int(floor((p.pos.y + p.size.y + 1.0) / T))
	for tx in range(int(floor(p.pos.x / T)) - 1, int(floor((p.pos.x + p.size.x) / T)) + 2):
		var below: int = lv.at(tx, ty)
		if below == Level.SPIKES or lv.at(tx, ty - 1) == Level.SPIKES:
			return false
		if below == Level.AIR:
			return false
	return true


## Picks the sprite frame for the current state.
static func frame(p: Dictionary) -> Array:
	if p.hurt_t > 0.0:
		return D.HERO.hurt[0]
	if p.heal_t > 0.0:
		return D.HERO.heal[0]
	if p.dash_t > 0.0:
		return D.HERO.dash[0]
	if p.atk_t > ATTACK_TIME - 0.18:
		match p.atk_kind:
			"up": return D.HERO.attack_up[0]
			"down": return D.HERO.attack_down[0]
		return D.HERO.attack[0]
	if p.sliding:
		return D.HERO.wall[0]
	if not p.on_floor:
		return D.HERO.jump[0] if p.vel.y < 0.0 else D.HERO.fall[0]
	if absf(p.vel.x) > 20.0:
		return D.HERO.run[int(p.anim * 11.0) % 4]
	return D.HERO.idle[int(p.anim * 1.6) % 2]
