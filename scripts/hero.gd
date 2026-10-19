## Player controller: run, variable jump, coyote time, jump buffer, dash,
## wall slide and wall jump, double jump (Feather charm), swimming, three-hit
## combo, up/down slashes with pogo, ink knives and healing flasks.
## The dash only makes the hero invulnerable with the Phantom Step charm.
extends RefCounted

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const Items := preload("res://scripts/items.gd")
const Physics := preload("res://scripts/physics.gd")
const Level := preload("res://scripts/level.gd")

const RUN := 150.0
const JUMP := 430.0
const GRAVITY := 1300.0
const MAX_FALL := 520.0
const WALL_FALL := 80.0
const DASH_SPEED := 400.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.55
const ATTACK_TIME := 0.26
const POGO := 370.0
const MAX_INK := 99.0
const KNIFE_COST := 33.0
const KNIFE_SPEED := 460.0


## A fresh hero for a new run.
static func create() -> Dictionary:
	var p := {
		"hp": 5, "base_hp": 5, "max_hp": 5, "flasks": 2, "base_flasks": 2, "max_flasks": 2,
		"ink": 0.0, "shards": 0, "weapon": Items.START_WEAPON, "charms": [], "bag": [], "st": {},
	}
	refresh(p)
	place(p, Vector2.ZERO)
	return p


## Recomputes stats after equipment changes.
static func refresh(p: Dictionary) -> void:
	p.st = Items.stats(p)
	p.max_hp = p.base_hp + p.st.max_hp
	p.max_flasks = p.base_flasks + p.st.flasks
	p.hp = mini(p.hp, p.max_hp)
	p.flasks = mini(p.flasks, p.max_flasks)


## Resets position and per-level state.
static func place(p: Dictionary, foot: Vector2) -> void:
	var size := Vector2(12, 28)
	p.merge({
		"pos": foot - Vector2(size.x * 0.5, size.y), "size": size, "vel": Vector2.ZERO,
		"on_floor": false, "on_wall": 0, "facing": 1,
		"coyote": 0.0, "jump_buf": 0.0, "drop_t": 0.0, "wall_lock": 0.0, "sliding": false, "air_jumps": 0,
		"dash_t": 0.0, "dash_cd": 0.0, "air_dash": true,
		"atk_t": 0.0, "atk_len": ATTACK_TIME, "atk_kind": "side", "atk_hit": {}, "combo": 0, "combo_t": 0.0,
		"throw_t": 0.0, "inv": 0.0, "blink": 0.0, "hurt_t": 0.0, "heal_t": 0.0,
		"respawn_t": 0.0, "safe": foot - Vector2(size.x * 0.5, size.y), "swim": false,
		"anim": 0.0, "dead": false, "was_floor": false, "fall_speed": 0.0, "step_t": 0.0,
	}, true)


static func update(g, p: Dictionary, dt: float) -> void:
	var held: Dictionary = g.ctl.held
	var just: Dictionary = g.ctl.just
	var st: Dictionary = p.st
	p.anim += dt
	for k in ["coyote", "jump_buf", "drop_t", "wall_lock", "dash_cd", "atk_t", "combo_t", "inv", "blink", "hurt_t", "heal_t", "throw_t"]:
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

	var was_swim: bool = p.swim
	p.swim = Physics.in_water(p, g.lv)
	if p.swim != was_swim and absf(p.vel.y) > 120.0:
		g.sfx("splash", -6.0)
		g.burst(Physics.center(p), ["~", "'", "."], g.biome.water, 8, 90.0, -80.0)

	# healing
	if just.heal:
		if p.flasks > 0 and p.hp < p.max_hp and p.dash_t <= 0.0:
			p.hp = mini(p.max_hp, p.hp + 2)
			p.flasks -= 1
			p.heal_t = 0.35
			g.sfx("heal")
			g.burst(Physics.center(p), ["+", "·", "+"], Color(0.5, 1.0, 0.6), 16, 110.0, -120.0)
		else:
			g.sfx("error", -8.0)

	# dash
	if just.dash and p.dash_cd <= 0.0 and (p.on_floor or p.air_dash or p.swim) and p.hurt_t <= 0.0:
		var dirx := int(held.right) - int(held.left)
		if dirx == 0 and g.aiming_with_mouse():
			dirx = 1 if g.aim_vector(p).x >= 0.0 else -1
		if dirx != 0:
			p.facing = dirx
		if p.sliding:
			p.facing = -p.facing
		p.dash_t = DASH_TIME
		p.dash_cd = DASH_COOLDOWN
		if not p.on_floor:
			p.air_dash = false
		if st.dash_inv:
			p.inv = maxf(p.inv, DASH_TIME + 0.05)
		p.atk_t = 0.0
		g.shake_add(1.5)
		g.sfx("dash")
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
	var run_speed := RUN * (0.7 if p.swim else 1.0)
	if p.hurt_t > 0.0:
		p.vel.x = move_toward(p.vel.x, 0.0, 500.0 * dt)
	elif p.wall_lock <= 0.0:
		var accel := 1800.0 if p.on_floor else 1150.0
		p.vel.x = move_toward(p.vel.x, dirx * run_speed, accel * dt)
		if dirx != 0 and p.atk_t <= 0.0 and p.throw_t <= 0.0:
			p.facing = dirx

	if p.on_floor:
		p.coyote = 0.1
		p.air_dash = true
		p.air_jumps = 1 if st.double_jump else 0
		if absf(p.vel.x) > 40.0:
			p.step_t -= dt
			if p.step_t <= 0.0:
				p.step_t = 0.27
				g.sfx("step", -14.0, 1.0, 0.2)
	if just.jump:
		p.jump_buf = 0.12
	if g.ctl.released.jump and p.vel.y < 0.0 and not p.swim:
		p.vel.y *= 0.45

	var wall := Physics.wall_side(p, g.lv)
	p.sliding = not p.on_floor and not p.swim and wall != 0 and dirx == wall and p.vel.y > 0.0 and p.hurt_t <= 0.0

	if p.jump_buf > 0.0:
		if held.down and p.on_floor and _on_oneway(p, g.lv):
			p.drop_t = 0.22
			p.jump_buf = 0.0
			p.pos.y += 1.0
		elif p.swim:
			p.vel.y = -JUMP * 0.62
			p.jump_buf = 0.0
			g.sfx("splash", -14.0, 1.4)
		elif p.coyote > 0.0:
			p.vel.y = -JUMP
			p.coyote = 0.0
			p.jump_buf = 0.0
			g.sfx("jump", -6.0)
			g.burst(Physics.foot(p), [".", ","], g.biome.edge, 5, 50.0)
		elif wall != 0 and not p.on_floor:
			if dirx == wall:
				# holding into the wall: climb up it instead of kicking away
				p.vel = Vector2(-wall * 60.0, -400.0)
				p.wall_lock = 0.05
			else:
				p.vel = Vector2(-wall * 230.0, -390.0)
				p.wall_lock = 0.1
				p.facing = -wall
			p.jump_buf = 0.0
			p.air_dash = true
			g.sfx("wall", -4.0)
			g.burst(Physics.center(p) + Vector2(wall * 6, 0), ["'", ".", "`"], g.biome.edge, 5, 60.0)
		elif p.air_jumps > 0:
			p.air_jumps -= 1
			p.vel.y = -JUMP * 0.9
			p.jump_buf = 0.0
			g.sfx("jump", -4.0, 1.3)
			g.burst(Physics.foot(p), ["~", "'", "`"], Color(0.95, 0.95, 0.8), 8, 70.0)

	if p.swim:
		p.vel.y = move_toward(p.vel.y, 70.0, 900.0 * dt)
		p.vel.y = minf(p.vel.y + 220.0 * dt, 110.0)
	else:
		var grav := GRAVITY * (1.15 if p.vel.y > 0.0 else 1.0)
		p.vel.y = minf(p.vel.y + grav * dt, WALL_FALL if p.sliding else MAX_FALL)
	if p.sliding and int(p.anim * 20.0) % 3 == 0:
		g.burst(Physics.center(p) + Vector2(wall * 7, -6), ["'", "."], g.biome.edge, 1, 20.0)

	# attack
	if just.attack and p.atk_t <= 0.0 and p.heal_t <= 0.0:
		var kind := "side"
		if g.aiming_with_mouse():
			var a: Vector2 = g.aim_vector(p)
			if a.y < -0.6:
				kind = "up"
			elif a.y > 0.6 and not p.on_floor:
				kind = "down"
			else:
				p.facing = 1 if a.x >= 0.0 else -1
		elif held.up:
			kind = "up"
		elif held.down and not p.on_floor:
			kind = "down"
		if kind == "side":
			p.combo = (p.combo + 1) % 3 if p.combo_t > 0.0 else 0
			p.combo_t = 0.5
		p.atk_len = ATTACK_TIME / st.speed
		p.atk_t = p.atk_len
		p.atk_kind = kind
		p.atk_hit = {}
		g.add_slash(kind, p.combo if kind == "side" else 0, p.facing, st.reach)
		g.sfx("swing", -3.0, [1.0, 1.12, 0.85][p.combo] if kind == "side" else 1.2)

	# ink knife
	if just.throw and p.throw_t <= 0.0:
		if p.ink >= KNIFE_COST:
			p.ink -= KNIFE_COST
			p.throw_t = 0.3
			var dir := Vector2(p.facing, 0)
			if g.aiming_with_mouse():
				dir = g.aim_vector(p)
				p.facing = 1 if dir.x >= 0.0 else -1
			elif held.up:
				dir = Vector2(0, -1)
			var from := Physics.center(p) + Vector2(p.facing * 6.0, -4.0)
			g.fire(from, dir * KNIFE_SPEED, "hero", st.dmg * 1.2 * st.dmg_mult)
			g.sfx("throw")
		else:
			g.sfx("error", -8.0)
			g.flash_ink()

	p.fall_speed = p.vel.y
	Physics.move(p, g.lv, dt, p.drop_t > 0.0)
	_after_move(g, p)


static func _after_move(g, p: Dictionary) -> void:
	if p.on_floor and not p.was_floor and p.fall_speed > 260.0:
		g.burst(Physics.foot(p), [".", ",", "'"], g.biome.edge, 6, 70.0)
		g.sfx("land", -6.0)
	p.was_floor = p.on_floor
	if p.on_floor and _safe_ground(p, g.lv):
		p.safe = p.pos

	if p.atk_t > 0.0:
		var elapsed: float = p.atk_len - p.atk_t
		if elapsed >= 0.02 and elapsed <= p.atk_len * 0.55:
			g.attack_hits(p, hitbox(p))

	if Physics.touches_spikes(Physics.rect(p), g.lv):
		g.hurt_player(1, Physics.center(p).x - p.facing * 10.0, true)


static func hitbox(p: Dictionary) -> Rect2:
	var c := Physics.center(p)
	var reach: float = p.st.reach
	match p.atk_kind:
		"up":
			return Rect2(c.x - 17, p.pos.y - 28 * reach, 34, 32 * reach)
		"down":
			return Rect2(c.x - 17, p.pos.y + p.size.y - 6, 34, 32 * reach)
	var wdt := 32.0 * reach
	return Rect2(c.x + (2.0 if p.facing > 0 else -2.0 - wdt), p.pos.y - 2, wdt, 30)


static func _on_oneway(p: Dictionary, lv) -> bool:
	var T := D.TILE
	var ty := int(floor((p.pos.y + p.size.y + 1.0) / T))
	var l := int(floor(p.pos.x / T))
	var r := int(floor((p.pos.x + p.size.x - 0.01) / T))
	for tx in range(l, r + 1):
		if lv.solid(tx, ty):
			return false
	return true


static func _safe_ground(p: Dictionary, lv) -> bool:
	var T := D.TILE
	var ty := int(floor((p.pos.y + p.size.y + 1.0) / T))
	for tx in range(int(floor(p.pos.x / T)) - 1, int(floor((p.pos.x + p.size.x) / T)) + 2):
		var below: int = lv.at(tx, ty)
		if lv.is_hazard(below) or lv.is_hazard(lv.at(tx, ty - 1)) or below == Level.CRACKED:
			return false
		if below == Level.AIR or below == Level.WATER:
			return false
	return true


## Picks the sprite frame for the current state.
static func frame(p: Dictionary) -> Dictionary:
	var hs: Dictionary = S.HERO
	if p.hurt_t > 0.0:
		return hs.hurt[0]
	if p.heal_t > 0.0:
		return hs.heal[0]
	if p.dash_t > 0.0:
		return hs.dash[0]
	if p.throw_t > 0.15:
		return hs.throw[0]
	if p.atk_t > p.atk_len - 0.18:
		match p.atk_kind:
			"up": return hs.attack_up[0]
			"down": return hs.attack_down[0]
		return hs.attack[0]
	if p.sliding:
		return hs.wall[0]
	if not p.on_floor:
		return hs.jump[0] if p.vel.y < 0.0 else hs.fall[0]
	if absf(p.vel.x) > 20.0:
		return hs.run[int(p.anim * 11.0) % 4]
	return hs.idle[int(p.anim * 1.6) % 2]
