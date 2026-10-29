## Player controller: run, variable jump, coyote time, jump buffer, dash,
## wall slide and wall jump, air jumps (charms, skills), swimming, thrown
## weapons and the moves: Triple Cut (attack x3), Dash Lunge (attack during a
## dash), Rising Crescent (up + attack on the ground) and the pogo down-slash,
## plus the moves learned in the skill tree (skills.gd).
## Health slowly comes back once the hero has not been hit for a while.
## Experience from kills raises the hero's level for good (until a new game).
## The dash only makes the hero invulnerable with the Phantom Step charm.
extends RefCounted

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const G := preload("res://scripts/gear_sprites.gd")
const Items := preload("res://scripts/items.gd")
const Physics := preload("res://scripts/physics.gd")
const Level := preload("res://scripts/level.gd")
const Skills := preload("res://scripts/skills.gd")

const RUN := 150.0
const JUMP := 430.0
const GRAVITY := 1300.0
const MAX_FALL := 520.0
const WALL_FALL := 80.0
const DASH_SPEED := 400.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.9
const ATTACK_TIME := 0.26
## How long an attack press waits for the current swing to end.
const ATTACK_BUFFER := 0.15
## Pause after the third cut of Triple Cut before the next swing (shorter for
## faster weapons), so the combo has a rhythm instead of an endless chain.
const COMBO_REST := 0.22
const POGO := 370.0
const MAX_INK := 99.0
const KNIFE_SPEED := 460.0
## Speed of swimming up while jump (or up) is held, of diving while down is,
## and of drifting up to the surface otherwise.
const SWIM_UP := 140.0
const SWIM_DOWN := 120.0
const SWIM_FLOAT := 45.0
## Running speed in water, and how slowly the hero speeds up and stops there.
const SWIM_RUN := 0.5
const SWIM_ACCEL := 520.0
## A jump out of the water is this much of a jump on land: enough to climb
## onto the bank, not to soar.
const SWIM_LEAP := 0.78
## Seconds after a dash during which Iaido makes the next hit a sure crit.
const IAIDO_TIME := 0.6
## Running speed bought at the merchant (Haste), per purchase.
const HASTE_STEP := 0.05
const LUNGE_SPEED := 430.0
const LUNGE_TIME := 0.17
## Seconds without taking damage before health starts to come back.
const REGEN_DELAY := 4.0
## Share of max health regained per second while regenerating.
const REGEN_RATE := 0.05
const BASE_HP := 100
const HP_PER_LEVEL := 6
const DMG_PER_LEVEL := 0.04
## Thrown weapons have their own damage, which grows this much per hero level.
const THROW_PER_LEVEL := 0.06
const BASE_CRIT := 0.08
## Shortest time between two free throws of Blade Storm and two Juggernaut waves.
const STORM_COOLDOWN := 2.5
const WAVE_COOLDOWN := 1.5
## The number keys take a weapon from the belt in hand, the swap key the next
## one: the new weapon
## takes SWAP_DRAW seconds to draw (no attacks meanwhile, the combo starts
## over), and the next swap waits SWAP_COOLDOWN.
const SWAP_DRAW := 0.25
const SWAP_COOLDOWN := 0.6
## Guard (the block key): it lasts at most GUARD_MAX seconds and the hero
## walks slowly behind it. A hit from the front in the first PARRY_TIME
## seconds is parried (no damage, the attacker reels); a later one is blocked
## for CHIP of its damage and breaks the guard. Then GUARD_COOLDOWN passes
## before the next guard (PARRY_COOLDOWN after a parry).
const GUARD_MAX := 1.2
const PARRY_TIME := 0.15
const CHIP := 0.35
const GUARD_COOLDOWN := 0.9
const PARRY_COOLDOWN := 0.35
const GUARD_RUN := 0.35
## The least share of a blow that still gets through all armour, charms and
## skills (Last Stand comes on top).
const ARMOR_FLOOR := 0.5
## Seconds of extra damage after a kill with Dance of Death, and how much.
const DANCE_TIME := 2.0
const DANCE_DMG := 1.2
## Aegis: a ward of WARD_SHARE of max health soaks up blows before health
## does (after armour). It fills again, even mid-fight, once no blow has
## landed for WARD_DELAY seconds, at WARD_RATE of the ward per second.
const WARD_SHARE := 0.2
const WARD_DELAY := 3.0
const WARD_RATE := 0.35


## Per-frame countdowns in the hero record (seconds, stopping at zero).
const TIMERS := ["coyote", "jump_buf", "atk_buf", "rest_t", "leap_t", "wet_t", "drop_t", "wall_lock", "dash_cd", "atk_t", "combo_t", "inv",
	"blink", "hurt_t", "heal_t", "throw_t", "guard_cd", "swap_cd", "draw_t", "dash_end", "iaido_t", "haste_t", "chill_t", "storm_t",
	"wave_t", "dance_t"]


## A fresh hero for a new run.
static func create() -> Dictionary:
	var p := {
		"hp": BASE_HP, "base_hp": BASE_HP, "max_hp": BASE_HP, "ink": 0.0, "shards": 0,
		"weapon": Items.START_WEAPON, "belt": [Items.START_WEAPON, "", ""], "wslot": 0, "throw": Items.START_THROW,
		"charms": [], "bag": [], "st": {},
		"armor": {"head": "", "body": "", "legs": ""}, "armor_up": {},
		"xp": 0, "xp_level": 1, "up_hp": 0, "up_dmg": 0, "up_spd": 0, "skills": {},
	}
	refresh(p)
	place(p, Vector2.ZERO)
	return p


## Recomputes stats after equipment, level or upgrade changes.
static func refresh(p: Dictionary) -> void:
	p.st = Items.stats(p)
	Skills.apply(p, p.st)
	p.st.run *= 1.0 + HASTE_STEP * p.get("up_spd", 0)
	p.st.dmg_mult *= (1.0 + DMG_PER_LEVEL * (p.xp_level - 1)) * (1.0 + 0.05 * p.up_dmg)
	p.st.crit += BASE_CRIT
	p.st.throw_dmg = p.st.throw_base * p.st.throw_mult * (1.0 + THROW_PER_LEVEL * (p.xp_level - 1)) * (1.0 + 0.05 * p.up_dmg)
	# armour, charms and skills together never take off more than half a blow
	p.st.armor = maxf(p.st.armor, ARMOR_FLOOR)
	p.max_hp = int((p.base_hp + HP_PER_LEVEL * (p.xp_level - 1) + 10 * p.up_hp + p.st.max_hp) * p.st.hp_mult)
	p.hp = mini(p.hp, p.max_hp)
	p.st.ward_max = p.max_hp * WARD_SHARE if p.st.aegis else 0.0
	p.ward = minf(p.get("ward", 0.0), p.st.ward_max)


## Experience needed to go from this level to the next.
static func xp_need(level: int) -> int:
	return int(45.0 * pow(level, 1.6))


## Resets position and per-level state.
static func place(p: Dictionary, foot: Vector2) -> void:
	var size := Vector2(12, 28)
	p.merge({
		"pos": foot - Vector2(size.x * 0.5, size.y), "size": size, "vel": Vector2.ZERO,
		"on_floor": false, "on_wall": 0, "facing": 1,
		"coyote": 0.0, "jump_buf": 0.0, "atk_buf": 0.0, "rest_t": 0.0, "leap_t": 0.0, "wet_t": 0.0, "drop_t": 0.0, "wall_lock": 0.0,
		"sliding": false, "air_jumps": 0,
		"dash_t": 0.0, "dash_cd": 0.0, "air_dash": true,
		"guard": false, "guard_t": 0.0, "guard_cd": 0.0, "parry_t": 0.0, "swap_cd": 0.0, "draw_t": 0.0,
		"ward": p.st.get("ward_max", 0.0), "ward_t": 0.0,
		"atk_t": 0.0, "atk_len": ATTACK_TIME, "atk_kind": "side", "atk_hit": {}, "combo": 0, "combo_t": 0.0,
		"throw_t": 0.0, "inv": 0.0, "blink": 0.0, "hurt_t": 0.0, "heal_t": 0.0,
		"respawn_t": 0.0, "safe": foot - Vector2(size.x * 0.5, size.y), "swim": false,
		"anim": 0.0, "dead": false, "was_floor": false, "fall_speed": 0.0, "step_t": 0.0,
		"calm": 0.0, "fighting": false, "regen": 0.0, "dash_end": 0.0, "lunge_t": 0.0, "slam": false, "dash_hit": {}, "iaido_t": 0.0,
		"haste_t": 0.0, "toll_n": 0, "chill_t": 0.0, "storm_t": 0.0, "wave_t": 0.0, "dance_t": 0.0,
	}, true)


static func update(g, p: Dictionary, dt: float) -> void:
	var held: Dictionary = g.ctl.held
	var just: Dictionary = g.ctl.just
	var st: Dictionary = p.st
	p.anim += dt
	for k in TIMERS:
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
	if p.swim:
		# a moment after bobbing out of the water still counts as swimming for a jump
		p.wet_t = 0.15
	if p.swim != was_swim and absf(p.vel.y) > 120.0:
		g.sfx("splash", -6.0)
		g.burst(Physics.center(p), ["~", "'", "."], g.biome.water, 8, 90.0, -80.0)

	# health comes back only out of combat: not in a boss fight or a closed
	# arena, nor with an angry foe close by (the Tide Pearl heals anyway)
	p.calm += dt
	p.fighting = g.in_combat()
	if p.fighting and not st.boss_regen:
		p.calm = 0.0
	if p.calm > REGEN_DELAY and p.hp < p.max_hp:
		p.regen += p.max_hp * REGEN_RATE * st.regen * g.diff().regen * dt
		if p.regen >= 1.0:
			var n := int(p.regen)
			p.hp = mini(p.max_hp, p.hp + n)
			p.regen -= n
			if int(p.anim * 6.0) % 3 == 0:
				g.burst(Physics.center(p) + Vector2(randf_range(-6, 6), 4), ["+", "·"], Color(0.55, 1.0, 0.6), 1, 20.0, -50.0)
	p.ward_t += dt
	if p.ward_t > WARD_DELAY and p.ward < st.ward_max:
		p.ward = minf(st.ward_max, p.ward + st.ward_max * WARD_RATE * dt)

	# Dash Lunge: attacking during (or right after) a dash turns it into a piercing thrust
	if just.attack and (p.dash_t > 0.0 or p.dash_end > 0.0) and p.atk_t <= 0.0 and p.lunge_t <= 0.0:
		p.dash_t = 0.0
		p.dash_end = 0.0
		p.lunge_t = LUNGE_TIME * (1.6 if st.long_lunge else 1.0)
		p.inv = maxf(p.inv, p.lunge_t)
		_start_attack(g, p, "lunge")
		g.shake_add(2.5)
	if p.lunge_t > 0.0:
		p.lunge_t = maxf(0.0, p.lunge_t - dt)
		p.vel = Vector2(p.facing * LUNGE_SPEED, 0.0)
		Physics.move(p, g.lv, dt)
		g.add_ghost(p)
		# the long lunge cuts twice: once on the way, once at the end
		if st.long_lunge and p.lunge_t < LUNGE_TIME * 0.6 and not p.atk_hit.has("second"):
			p.atk_hit = {"second": true}
		if p.lunge_t <= 0.0:
			p.vel.x *= 0.3
		_after_move(g, p)
		return

	# dash
	if just.dash and p.dash_cd <= 0.0 and (p.on_floor or p.air_dash or p.swim) and p.hurt_t <= 0.0:
		var dirx := int(held.right) - int(held.left)
		if dirx == 0 and g.aiming_with_mouse():
			dirx = 1 if g.aim_vector(p).x >= 0.0 else -1
		if dirx != 0:
			p.facing = dirx
		if p.sliding:
			p.facing = -p.facing
		drop_guard(p)
		p.dash_t = DASH_TIME
		p.dash_cd = DASH_COOLDOWN * st.dash_cd
		p.dash_hit = {}
		p.slam = false
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
		if st.shoulder:
			g.dash_hits(p)
		if p.dash_t <= 0.0:
			p.vel.x *= 0.35
			p.dash_end = 0.2
			if st.iaido:
				p.iaido_t = IAIDO_TIME
		_after_move(g, p)
		return

	_update_guard(g, p, dt)
	var pick := -1
	for i in Items.BELT_SLOTS:
		if just["slot%d" % (i + 1)]:
			pick = i
	var ready: bool = p.swap_cd <= 0.0 and p.atk_t <= 0.0 and not p.guard
	if ready and ((pick >= 0 and Items.select_weapon(p, pick)) or (pick < 0 and just.swap and Items.next_weapon(p))):
		refresh(p)
		p.swap_cd = SWAP_COOLDOWN
		p.draw_t = SWAP_DRAW
		p.combo = 0
		p.combo_t = 0.0
		g.sfx("swing", -8.0, 0.6)
		g.sfx("clink", -12.0, 1.2)
		g.popups.append({"pos": Physics.center(p) + Vector2(0, -24), "text": g.L("item_" + p.weapon), "color": Items.def(p.weapon).color,
			"life": 0.8, "big": false})

	# horizontal movement
	var dirx := int(held.right) - int(held.left)
	var run_speed: float = RUN * st.run * (SWIM_RUN if p.swim else 1.0) * (1.25 if p.haste_t > 0.0 else 1.0) \
		* (0.6 if p.chill_t > 0.0 else 1.0)
	if p.guard:
		run_speed *= GUARD_RUN
	if p.hurt_t > 0.0:
		p.vel.x = move_toward(p.vel.x, 0.0, 500.0 * dt)
	elif p.wall_lock <= 0.0:
		var accel := SWIM_ACCEL if p.swim else (1800.0 if p.on_floor else 1150.0)
		p.vel.x = move_toward(p.vel.x, dirx * run_speed, accel * dt)
		if dirx != 0 and p.atk_t <= 0.0 and p.throw_t <= 0.0 and not p.guard:
			p.facing = dirx

	if p.on_floor:
		p.coyote = 0.1
		p.air_dash = true
		p.air_jumps = st.air_jumps
		if absf(p.vel.x) > 40.0:
			p.step_t -= dt
			if p.step_t <= 0.0:
				p.step_t = 0.27
				g.sfx("step", -14.0, 1.0, 0.2)
	if just.jump:
		p.jump_buf = 0.12
		drop_guard(p)
	if g.ctl.released.jump and p.vel.y < 0.0 and not p.swim and p.leap_t <= 0.0:
		p.vel.y *= 0.45

	var wall := Physics.wall_side(p, g.lv)
	p.sliding = not p.on_floor and not p.swim and wall != 0 and dirx == wall and p.vel.y > 0.0 and p.hurt_t <= 0.0

	if p.jump_buf > 0.0:
		if held.down and p.on_floor and _on_oneway(p, g.lv):
			p.drop_t = 0.22
			p.jump_buf = 0.0
			p.pos.y += 1.0
		elif p.swim or p.wet_t > 0.0:
			# at the surface a jump leaps out onto the bank; deeper down it is a stroke
			if not p.swim or _at_surface(p, g.lv):
				p.vel.y = -JUMP * SWIM_LEAP
				p.leap_t = 0.25
				g.burst(Physics.center(p), ["~", "'", "."], g.biome.water, 8, 90.0, -80.0)
			else:
				p.vel.y = minf(p.vel.y, -SWIM_UP * 1.6)
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
		# water holds the hero up: jump (or up) swims upward, down dives, and
		# otherwise the hero drifts up and floats with the head out
		var want := -SWIM_FLOAT
		if held.down:
			want = SWIM_DOWN
		elif held.jump or held.up:
			want = -SWIM_UP
		if want < 0.0 and _at_surface(p, g.lv):
			want = 0.0
		p.vel.y = move_toward(p.vel.y, want, 600.0 * dt)
	else:
		var grav := GRAVITY * (1.15 if p.vel.y > 0.0 else 1.0)
		p.vel.y = minf(p.vel.y + grav * dt, WALL_FALL if p.sliding else MAX_FALL)
	if p.sliding and g.rng.randf() < 20.0 * dt:
		g.burst(Physics.center(p) + Vector2(wall * 7, -6), ["'", "."], g.biome.edge, 1, 20.0)

	# attack: every swing needs its own press; a press just before a swing
	# ends is kept for the next one
	if just.attack:
		p.atk_buf = ATTACK_BUFFER
	if p.atk_buf > 0.0 and p.atk_t <= 0.0 and p.rest_t <= 0.0 and p.draw_t <= 0.0 and not p.guard:
		p.atk_buf = 0.0
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
		# only the up key launches the hero: a mouse aimed high just cuts upwards
		if kind == "up" and p.on_floor and held.up:
			kind = "rise"
		_start_attack(g, p, kind)
	# Quake: a down-cut in the air becomes a dive that shakes the ground on landing
	if p.slam:
		p.vel.x = move_toward(p.vel.x, 0.0, 600.0 * dt)
		p.vel.y = maxf(p.vel.y, MAX_FALL)
		g.add_ghost(p)
		if p.swim or p.sliding:
			p.slam = false

	# thrown weapon
	if just.throw and p.throw_t <= 0.0 and not p.guard and p.throw != "":
		var cost: float = st.throw_ink * st.ink_cost
		if p.ink >= cost:
			p.ink -= cost
			p.throw_t = 0.3
			var dir := Vector2(p.facing, 0)
			if g.aiming_with_mouse():
				dir = g.aim_vector(p)
				p.facing = 1 if dir.x >= 0.0 else -1
			elif held.up:
				dir = Vector2(0, -1)
			g.throw_weapon(p, dir)
		else:
			g.sfx("error", -8.0)
			g.flash_ink()

	p.fall_speed = p.vel.y
	Physics.move(p, g.lv, dt, p.drop_t > 0.0)
	_after_move(g, p)


## Raises the guard on a press of the block key, keeps it while the key is
## held (up to GUARD_MAX) and lowers it when let go.
static func _update_guard(g, p: Dictionary, dt: float) -> void:
	var ctl = g.ctl
	if p.guard:
		p.guard_t += dt
		p.parry_t = maxf(0.0, p.parry_t - dt)
		if not ctl.held.block or p.guard_t >= GUARD_MAX or p.hurt_t > 0.0 or p.swim:
			drop_guard(p)
		return
	if ctl.just.block and p.guard_cd <= 0.0 and p.atk_t <= 0.0 and p.hurt_t <= 0.0 and not p.swim:
		if g.aiming_with_mouse():
			p.facing = 1 if g.aim_vector(p).x >= 0.0 else -1
		p.guard = true
		p.guard_t = 0.0
		p.parry_t = PARRY_TIME * p.st.parry_mult
		p.slam = false
		g.sfx("clink", -10.0, 0.7)


## Lowers the guard (if up) and starts its cooldown.
static func drop_guard(p: Dictionary, cooldown: float = GUARD_COOLDOWN) -> void:
	if not p.guard:
		return
	p.guard = false
	p.parry_t = 0.0
	p.guard_cd = maxf(p.guard_cd, cooldown)


## True when a blow coming from [src_x] meets the raised guard.
static func guards_against(p: Dictionary, src_x: float) -> bool:
	if not p.guard:
		return false
	var dx := src_x - Physics.center(p).x
	return absf(dx) < 3.0 or signf(dx) == p.facing


static func _start_attack(g, p: Dictionary, kind: String) -> void:
	var st: Dictionary = p.st
	if kind == "side":
		p.combo = (p.combo + 1) % 3 if p.combo_t > 0.0 else 0
		p.combo_t = 0.55
		# each cut steps forward a little; the finisher lunges
		if p.on_floor:
			p.vel.x += p.facing * (190.0 if p.combo == 2 else 60.0)
		if p.combo == 2:
			p.rest_t = ATTACK_TIME / st.speed + COMBO_REST / st.speed
			if st.juggernaut and p.on_floor and p.wave_t <= 0.0:
				p.wave_t = WAVE_COOLDOWN
				g.ground_wave(p)
			if st.blade_storm and p.storm_t <= 0.0 and p.throw != "":
				p.storm_t = STORM_COOLDOWN
				g.throw_weapon(p, Vector2(p.facing, 0), true)
	if kind == "down" and st.quake and not p.on_floor:
		p.slam = true
		g.sfx("dash", -6.0, 0.6)
	p.atk_len = ATTACK_TIME / st.speed
	match kind:
		"lunge":
			p.atk_len = LUNGE_TIME + 0.06
		"rise":
			p.atk_len = 0.3 / st.speed
			p.vel.y = -330.0
			p.on_floor = false
			p.coyote = 0.0
	p.atk_t = p.atk_len
	p.atk_kind = kind
	p.atk_hit = {}
	g.add_slash(kind, p.combo if kind == "side" else 0, p.facing, st.reach)
	var pitch := 1.2
	if kind == "side":
		pitch = [1.0, 1.12, 0.8][p.combo]
	elif kind == "lunge":
		pitch = 0.7
	elif kind == "rise":
		pitch = 0.9
	g.sfx("swing", -3.0 if kind != "lunge" else 0.0, pitch)
	if kind == "lunge" or (kind == "side" and p.combo == 2) or kind == "rise":
		g.sfx("dash", -8.0, 0.8)


static func _after_move(g, p: Dictionary) -> void:
	if p.slam and p.on_floor:
		p.slam = false
		g.quake(p)
	elif p.on_floor and not p.was_floor and p.fall_speed > 260.0:
		g.burst(Physics.foot(p), [".", ",", "'"], g.biome.edge, 6, 70.0)
		g.sfx("land", -6.0)
	p.was_floor = p.on_floor
	if p.on_floor and _safe_ground(p, g.lv):
		p.safe = p.pos

	if p.atk_t > 0.0:
		var elapsed: float = p.atk_len - p.atk_t
		var active: float = 0.9 if p.atk_kind == "lunge" else 0.55
		if elapsed >= 0.02 and elapsed <= p.atk_len * active:
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
		"rise":
			return Rect2(c.x - 22 + p.facing * 8, p.pos.y - 30 * reach, 44, 30 * reach + p.size.y)
		"lunge":
			var lw := 46.0 * reach
			return Rect2(c.x + (-8.0 if p.facing > 0 else 8.0 - lw), p.pos.y + 2, lw, 24)
	var wdt := (38.0 if p.combo == 2 else 32.0) * reach
	# a sweeping weapon (the scythe) also reaches a little behind the hero
	var back := wdt * 0.45 if p.st.sweep else 0.0
	return Rect2(c.x + (2.0 - back if p.facing > 0 else -2.0 - wdt), p.pos.y - 2, wdt + back, 30)


## True when the hero's head is out of the water (or about to break the surface).
static func _at_surface(p: Dictionary, lv) -> bool:
	var T := D.TILE
	var tx := int(floor((p.pos.x + p.size.x * 0.5) / T))
	return lv.at(tx, int(floor((p.pos.y - 4.0) / T))) != Level.WATER


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


## The hero's palette dyed by the armour worn: the helmet colours the head,
## the body piece the torso and arms, the leg piece the legs.
static func palette(p: Dictionary) -> Array:
	var pal: Array = S.HERO_PAL.duplicate()
	var armor: Dictionary = p.get("armor", {})
	for pair in [["head", 1], ["body", 0], ["legs", 4]]:
		var id: String = armor.get(pair[0], "")
		if id != "":
			pal[pair[1]] = dye(pair[0], Items.def(id).color)
	return pal


## The colour armour of colour [c] has on the hero when worn as [part]: the
## item colours are bright, the hero is drawn in the dark tones of the night.
static func dye(part: String, c: Color) -> Color:
	return c.darkened({"head": 0.42, "body": 0.48, "legs": 0.55}.get(part, 0.42))


## Picks the sprite frame for the current state, dressed in the armour worn.
static func frame(p: Dictionary) -> Array:
	var pk := pick(p)
	return compose(pk[0], pk[1], Items.worn(p, "head"), Items.worn(p, "body"))


static var _frames := {}


## Frame [i] of animation [anim] with helmet [head] and body armour [body]
## laid over it ("" for none: the horned helm and the bare tabard).
static func compose(anim: String, i: int, head: String, body: String) -> Array:
	var key := "%s|%d|%s|%s" % [anim, i, head, body]
	if _frames.has(key):
		return _frames[key]
	var rows: Array = S.HERO[anim][i]
	var pt: Array = S.HERO_PARTS[anim][i]
	# the healing hand is held before the chest
	if G.BODIES.has(body) and anim != "heal":
		rows = _stamp(rows, G.BODIES[body], pt[1])
	rows = _stamp(rows, G.HEADS.get(head, G.HEADS.helm), pt[0])
	_frames[key] = rows
	return rows


## [rows] with the solid pixels of [over] laid on them, its corner at [at].
static func _stamp(rows: Array, over: Array, at: Vector2i) -> Array:
	var out := rows.duplicate()
	for j in over.size():
		var y := at.y + j
		if y < 0 or y >= out.size():
			continue
		var line: String = out[y]
		var src: String = over[j]
		for k in src.length():
			var x := at.x + k
			if src[k] != "." and x >= 0 and x < line.length():
				line = line.substr(0, x) + src[k] + line.substr(x + 1)
		out[y] = line
	return out


## Where the arm hangs from in the frame drawn now (world units from the feet,
## facing right).
static func shoulder(p: Dictionary) -> Vector2i:
	var pk := pick(p)
	return S.HERO_SHOULDER[pk[0]][pk[1]]


## The animation and frame index the hero is drawn with now.
static func pick(p: Dictionary) -> Array:
	if p.hurt_t > 0.0:
		return ["hurt", 0]
	if p.heal_t > 0.0:
		return ["heal", 0]
	if p.dash_t > 0.0 or p.lunge_t > 0.0:
		return ["dash", 0]
	if p.guard or p.throw_t > 0.15:
		return ["throw", 0]
	if p.atk_t > p.atk_len - 0.18:
		match p.atk_kind:
			"up", "rise": return ["attack_up", 0]
			"down": return ["attack_down", 0]
		return ["attack", 0]
	if p.sliding:
		return ["wall", 0]
	if not p.on_floor:
		return ["jump", 0] if p.vel.y < 0.0 else ["fall", 0]
	if absf(p.vel.x) > 20.0:
		return ["run", int(p.anim * 11.0) % 4]
	return ["idle", int(p.anim * 1.6) % 2]
