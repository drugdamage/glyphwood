## Combat rules and short-lived world objects: melee hits, projectiles, fire
## pillars, explosions, breakable walls, shard drops, pickups, particles and
## damage numbers. Static functions that act on the game (g), like Hero and Foes.
extends RefCounted

const D := preload("res://scripts/data.gd")
const S := preload("res://scripts/sprites.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Items := preload("res://scripts/items.gd")

const INK_PER_HIT := 11.0
## How long a staggered boss stands dazed, and how much more damage it takes meanwhile.
const STAGGER_TIME := 1.8
const STAGGER_DMG := 1.5

const SHOT_LOOK := {
	"orb": ["o", Color(0.7, 0.85, 1.0)], "arrow": ["-", Color(0.9, 0.8, 0.6)], "spore": ["@", Color(0.6, 1.0, 0.4)],
	"wave": ["^", Color(0.7, 1.0, 0.5)], "rock": ["o", Color(0.7, 0.55, 0.45)], "ember": ["*", Color(1.0, 0.55, 0.2)],
	"knife": ["»", Color(0.65, 0.75, 1.0)], "shot": ["*", Color(1.0, 0.55, 0.4)],
	"boomerang": ["<", Color(0.92, 0.86, 0.72)], "chakram": ["✶", Color(0.6, 0.95, 0.55)], "flask": ["ò", Color(0.55, 0.9, 0.3)],
	"javelin": ["—", Color(0.8, 0.74, 0.62)],
	"hwave": ["^", Color(1.0, 0.8, 0.55)], "frost": ["*", Color(0.7, 0.9, 1.0)], "bell": ["o", Color(0.95, 0.8, 0.45)],
	"bile": ["@", Color(0.55, 0.8, 0.3)], "hook": ["J", Color(0.72, 0.72, 0.78)], "noose": ["O", Color(0.7, 0.62, 0.45)],
}
## Thrown weapon item -> projectile kind.
const THROW_KIND := {"ink_knife": "knife", "bone_boomerang": "boomerang", "thorn_chakram": "chakram", "bile_flask": "flask",
	"grave_javelin": "javelin"}
## Every TOLL_EVERY melee hit rings the Funeral Bell for triple damage.
const TOLL_EVERY := 5
## Blade Storm's free throw deals this share of a normal throw.
const STORM_DMG := 0.6
## Ink Siphon gives back per hit of a thrown weapon, and at most per throw.
const SIPHON_INK := 8.0
const SIPHON_MAX := 16.0
## Rend: the Triple Cut finisher hits this much harder and sets foes bleeding.
const REND_DMG := 1.3
## Philosopher's Stone: ink back per kill.
const STONE_INK := 10.0
## Burning foes take this much more damage with Venom Glass.
const VENOM_DMG := 1.25


# ---------------------------------------------------------------- melee

static func attack_hits(g, p: Dictionary, box: Rect2) -> void:
	var hit_any := false
	var blocked := false
	var kdir := Vector2(p.facing, 0)
	if p.atk_kind == "up":
		kdir = Vector2(0, -1)
	elif p.atk_kind == "down":
		kdir = Vector2(0, 1)
	var st: Dictionary = p.st
	var finisher: bool = p.atk_kind == "side" and p.combo == 2
	var mult := 1.0
	var crit_bonus := 0.0
	match p.atk_kind:
		"side":
			if finisher:
				mult = 2.2 * (REND_DMG if st.rend else 1.0)
				crit_bonus = 0.15
		"lunge":
			mult = 1.8
			crit_bonus = 0.1
		"rise":
			mult = 1.5
	mult *= damage_bonus(p)
	for e in g.enemies.duplicate():
		if p.atk_hit.has(e.id) or (e.kind == "wisp" and _wisp_hidden(e)):
			continue
		if box.intersects(Physics.rect(e)):
			p.atk_hit[e.id] = true
			# the lunge, the finisher and crushing weapons break through shields
			if Foes.blocks(e, Physics.center(p).x, p.atk_kind) and not (finisher or p.atk_kind == "lunge" or st.crush):
				blocked = true
				e.flash = 0.05
				continue
			var m := mult
			if st.toll > 0:
				p.toll_n += 1
				if p.toll_n % TOLL_EVERY == 0:
					m *= 3.0
					g.sfx("bell", -4.0, 1.4)
					burst(g, Physics.center(e), ["o", "O", "·"], Color(0.95, 0.8, 0.45), 10, 140.0)
			if st.execute and e.hp < e.max_hp * Items.EXECUTE_AT:
				m *= Items.EXECUTE_MULT
			hurt_enemy(g, e, st.dmg * st.dmg_mult * m, kdir, true, crit_bonus)
			if st.leech > 0.0:
				heal_player(g, st.leech, false)
			if g.enemies.has(e) and finisher and st.rend:
				e.burn = maxf(e.burn, 2.5)
			if g.enemies.has(e) and st.chill:
				e.chill = 2.0
			if g.enemies.has(e) and st.crush and not e.boss:
				e.stun = maxf(e.stun, 0.5)
			if g.enemies.has(e) and not e.boss:
				if p.atk_kind == "rise" and not e.fly:
					e.vel.y = -380.0
					e.stun = 0.6
				elif finisher or p.atk_kind == "lunge":
					e.vel.x = p.facing * 320.0
					e.stun = 0.45
			p.ink = minf(Hero.MAX_INK, p.ink + INK_PER_HIT * st.ink_gain * st.ink_hit)
			if st.burn:
				e.burn = 2.1
			hit_any = true
			g.combo_hit()
	for pr in g.projectiles.duplicate():
		if pr.owner == "enemy" and pr.delay <= 0.0 and pr.kind != "wave" and box.has_point(pr.pos):
			g.projectiles.erase(pr)
			burst(g, pr.pos, ["*", "+", "·"], Color(1.0, 0.9, 0.6), 8, 120.0)
			p.ink = minf(Hero.MAX_INK, p.ink + 4.0 * st.ink_gain)
			hit_any = true
	var cracked: Array = Physics.tiles_in(box, g.lv, Level.CRACKED)
	if not cracked.is_empty() and not p.atk_hit.has("wall"):
		p.atk_hit["wall"] = true
		break_tiles(g, cracked)
		hit_any = true
	if p.atk_kind == "down" and not p.atk_hit.has("spikes") and Physics.touches_spikes(box, g.lv):
		p.atk_hit["spikes"] = true
		hit_any = true
	if blocked:
		g.sfx("clink")
		g.burst(box.get_center(), ["*", "'", "+"], Color(1.0, 0.9, 0.5), 6, 120.0)
		p.vel.x = -p.facing * 160.0
		g.hitstop = maxf(g.hitstop, 0.04)
	if hit_any:
		g.hitstop = maxf(g.hitstop, 0.08 if (finisher or p.atk_kind == "lunge") else 0.05)
		g.shake_add(5.0 if finisher else 2.5)
		if p.atk_kind == "down":
			p.slam = false
			p.vel.y = -Hero.POGO
			p.air_dash = true
			p.air_jumps = st.air_jumps
			p.dash_cd = 0.0
			g.sfx("pogo", -4.0)
		elif p.atk_kind == "side" and not p.on_floor:
			p.vel.y = minf(p.vel.y, 0.0)


## Damage multiplier from the hero's state: Blood Rosary and Last Stand at low
## health, Dance of Death after a kill.
static func damage_bonus(p: Dictionary) -> float:
	var st: Dictionary = p.st
	var low: bool = p.hp <= p.max_hp * 0.35
	var m := Hero.DANCE_DMG if p.dance_t > 0.0 else 1.0
	if low:
		m *= st.rage
		if st.last_stand:
			m *= 1.2
	return m


static func break_tiles(g, list: Array) -> void:
	for t in list:
		g.lv.set_t(t.x, t.y, Level.AIR)
		var c := Vector2((t.x + 0.5) * D.TILE, (t.y + 0.5) * D.TILE)
		burst(g, c, ["%", "#", ".", ","], g.biome.edge, 6, 110.0)
	g.sfx("crumble")
	g.shake_add(3.0)
	g.tiles_changed(list, true)


static func hurt_enemy(g, e: Dictionary, dmg: float, kdir: Vector2, melee: bool = false, crit_bonus: float = 0.0) -> void:
	if not g.enemies.has(e):
		return
	var crit := false
	var p: Dictionary = g.player
	var sure: bool = melee and p.iaido_t > 0.0
	if p.st.venom and e.burn > 0.0:
		dmg *= VENOM_DMG
	if melee and (sure or g.rng.randf() < p.st.crit + crit_bonus):
		dmg *= p.st.crit_mult
		crit = true
		p.iaido_t = 0.0
		g.on_crit(Physics.center(e))
		if p.st.crit_burn:
			e.burn = 2.5
	if e.get("stagger", 0.0) > 0.0:
		dmg *= STAGGER_DMG
	e.hp -= dmg
	if e.boss and e.hp > 0:
		_check_stagger(g, e)
	e.flash = 0.12
	e.aggro = true
	if not e.boss:
		e.stun = 0.2
		if e.kind == "bat" or e.kind == "wisp":
			e.vel = kdir * 220.0
		elif e.kind != "spitter" and kdir != Vector2.ZERO:
			e.vel.x = (kdir.x if kdir.x != 0.0 else float(e.dir) * -1.0) * 190.0
			e.vel.y = -110.0 if kdir.y >= 0.0 else -180.0
		if e.kind == "knight" and e.state == "tele":
			e.state = "rest"
			e.t = 0.4
	if g.cfg.get_v("damage_numbers"):
		var col := Color(1.0, 0.85, 0.3) if crit else (Color(1.0, 0.6, 0.3) if not melee else Color(1, 1, 1))
		g.popups.append({"pos": Physics.center(e) + Vector2(g.rng.randf_range(-6, 6), -e.size.y * 0.5),
			"text": (g.L("crit") + " " if crit else "") + str(int(round(dmg))), "color": col, "life": 1.0 if crit else 0.8,
			"big": crit})
	if melee:
		g.sfx("hit", -2.0)
	burst(g, Physics.center(e), ["*", "+", "x", "·"], Color(1, 1, 1), 7, 150.0)
	if e.hp <= 0:
		kill_enemy(g, e)


## A boss loses its footing each time a quarter of its health is gone: it
## stands dazed for a moment, takes more damage and sheds a health orb.
static func _check_stagger(g, e: Dictionary) -> void:
	var marks: int = e.get("marks", 0)
	if marks >= 3 or e.hp > e.max_hp * (0.75 - 0.25 * marks):
		return
	e.marks = marks + 1
	e.stagger = STAGGER_TIME
	e.vel.x = 0.0
	if e.fly:
		e.vel = Vector2.ZERO
	g.pickups.append({"kind": "orb", "pos": Physics.center(e) + Vector2(0, -10)})
	g.sfx("slam", -2.0, 1.3)
	g.shake_add(6.0)
	g.popups.append({"pos": Physics.center(e) + Vector2(0, -e.size.y * 0.7), "text": g.L("stagger"),
		"color": Color(1.0, 0.85, 0.3), "life": 1.2, "big": true})
	burst(g, Physics.center(e), ["*", "+", "x"], Color(1.0, 0.85, 0.4), 14, 170.0)


static func kill_enemy(g, e: Dictionary) -> void:
	if not g.enemies.has(e):
		return
	g.enemies.erase(e)
	g.kills += 1
	g.hitstop = maxf(g.hitstop, 0.12 if e.boss else 0.07)
	g.shake_add(14.0 if e.boss else 4.0)
	g.sfx("kill", 0.0, 0.6 if e.boss else 1.0)
	var def: Dictionary = S.FOES[e.kind]
	var pal: Array = def.pal
	var fr: Variant = Foes.frame(e)
	var lines: Array = fr.g if fr is Dictionary else fr
	var f := Physics.foot(e)
	var a: float = def.a
	var sc: float = def.get("scale", 1.0)
	for i in lines.size():
		var line: String = lines[i]
		for j in line.length():
			var ch := line[j]
			if ch == " ":
				continue
			var pp := f + Vector2((j - a) * D.GW * sc * e.dir, -(lines.size() - i - 0.5) * D.GH * sc)
			g.particles.append({"p": pp, "v": Vector2(g.rng.randf_range(-140, 140), g.rng.randf_range(-260, -80)),
				"g": ch, "c": pal[0], "life": 1.1, "max": 1.1, "grav": 900.0, "drag": 0.5, "s": 1.0})
	var st: Dictionary = g.player.st
	var base: int = D.ENEMIES[e.kind].shards
	var n := int(round(base * (2.5 if e.elite else 1.0) * st.shard_mult))
	drop_shards(g, Physics.center(e), n)
	g.gain_xp(base * 4.0 * (2.5 if e.elite else 1.0) * (1.0 + 0.1 * (g.level_num - 1)), Physics.center(e))
	if g.rng.randf() < st.lifesteal:
		heal_player(g, 0.08)
	if st.chain:
		heal_player(g, 0.04)
	var p: Dictionary = g.player
	if st.reaper:
		p.dash_cd = 0.0
		p.air_dash = true
		p.haste_t = 1.5
	if st.philosopher:
		p.ink = minf(Hero.MAX_INK, p.ink + STONE_INK)
	if st.death_dance:
		p.dance_t = Hero.DANCE_TIME
	if not e.boss and g.rng.randf() < 0.2 * st.orbs:
		g.pickups.append({"kind": "orb", "pos": Physics.center(e)})
	if e.kind == "bomber":
		explode(g, Physics.center(e), 48.0, false)
	if e.boss:
		g.on_boss_killed(e)


static func drop_shards(g, at: Vector2, n: int) -> void:
	for k in n:
		g.shards.append({"pos": at, "size": Vector2(4, 4),
			"vel": Vector2(g.rng.randf_range(-130, 130), g.rng.randf_range(-280, -120)),
			"on_floor": false, "on_wall": 0, "t": 0.0})


static func _wisp_hidden(e: Dictionary) -> bool:
	return fmod(e.anim, 3.0) > 2.3


# ---------------------------------------------------------------- player damage

## Heals a share of max health, with a small effect (and the healing pose
## unless [pose] is false, so a leeching weapon does not interrupt the swing).
static func heal_player(g, share: float, pose: bool = true) -> void:
	var p: Dictionary = g.player
	if p.dead or p.hp >= p.max_hp:
		return
	p.hp = mini(p.max_hp, p.hp + maxi(1, int(round(p.max_hp * share))))
	if pose:
		p.heal_t = 0.2
	burst(g, Physics.center(p), ["+", "·"], Color(0.55, 1.0, 0.6), 3 if not pose else 8, 80.0, -60.0)


## units is the size of the hit: 1 is a normal blow. Damage grows with depth.
static func hurt_player(g, units: float, src_x: float, spikes: bool = false) -> void:
	var p: Dictionary = g.player
	if p.dead or p.respawn_t > 0.0:
		return
	if g.god:
		if spikes:
			p.respawn_t = 0.45
		return
	if p.inv > 0.0:
		if spikes:
			p.respawn_t = 0.45
		return
	var st: Dictionary = p.st
	var armor: float = st.armor
	if st.last_stand and p.hp <= p.max_hp * 0.35:
		armor *= 0.65
	var dmg := maxi(1, int(round(units * g.hit_damage() * armor)))
	p.hp -= dmg
	p.calm = 0.0
	p.regen = 0.0
	p.inv = 1.1 * p.st.inv_time
	p.blink = p.inv
	p.hurt_t = 0.22
	p.dash_t = 0.0
	var away := 1.0 if Physics.center(p).x >= src_x else -1.0
	p.vel = Vector2(away * 190.0, -260.0)
	g.hitstop = 0.11
	g.shake_add(8.0)
	g.hurt_flash = 1.0
	g.sfx("hurt")
	burst(g, Physics.center(p), ["*", "x", "·", "+"], Color(1.0, 0.35, 0.3), 12, 170.0)
	g.popups.append({"pos": Physics.center(p) + Vector2(0, -18), "text": "-%d" % dmg, "color": Color(1.0, 0.35, 0.3), "life": 0.9,
		"big": false})
	if st.vengeance and p.hp > 0:
		shockwave(g, Physics.center(p), 70.0, st.dmg * st.dmg_mult * 1.5, Color(1.0, 0.4, 0.3))
	if p.hp <= 0:
		p.hp = 0
		p.dead = true
		g.on_player_died()
		var fr: Dictionary = Hero.frame(p)
		var lines: Array = fr.g
		for i in lines.size():
			var line: String = lines[i]
			for j in line.length():
				if line[j] != " ":
					var off := Vector2((j - S.HERO.a) * D.GW, -(lines.size() - i - 0.5) * D.GH) * S.HERO.scale
					g.particles.append({"p": Physics.foot(p) + off,
						"v": Vector2(g.rng.randf_range(-120, 120), g.rng.randf_range(-280, -120)), "g": line[j],
						"c": S.HERO_PAL[0], "life": 1.6, "max": 1.6, "grav": 700.0, "drag": 0.4, "s": 1.0})
	elif spikes:
		p.respawn_t = 0.45


static func check_contacts(g) -> void:
	var p: Dictionary = g.player
	if p.dead:
		return
	var pr := Physics.rect(p)
	var thorns: int = p.st.thorns
	for e in g.enemies.duplicate():
		if e.kind == "wisp" and _wisp_hidden(e):
			continue
		if pr.intersects(Physics.rect(e).grow(-2.0)):
			if thorns > 0 and e.thorn_t <= 0.0 and p.inv <= 0.0:
				e.thorn_t = 0.6
				hurt_enemy(g, e, thorns, Vector2.ZERO)
			hurt_player(g, 1.5 if e.boss else 1.0, Physics.center(e).x)


# ---------------------------------------------------------------- projectiles and hazards

static func fire(g, from: Vector2, vel: Vector2, owner: String, dmg: float, grav: float = 0.0, kind: String = "shot",
		delay: float = 0.0) -> Dictionary:
	if owner == "hero" and kind == "shot":
		kind = "knife"
	var pr := {"pos": from, "vel": vel, "life": 4.0, "owner": owner, "dmg": dmg, "grav": grav,
		"kind": kind, "delay": delay, "t": 0.0, "hits": {}, "back": {}, "pierce": 0, "bounce": 0}
	g.projectiles.append(pr)
	if delay <= 0.0 and owner == "enemy":
		burst(g, from, ["·"], SHOT_LOOK.get(kind, SHOT_LOOK.shot)[1], 4, 60.0)
	return pr


## Hurls the hero's throwing weapon. free: launched by Blade Storm (no ink, no
## twin, weaker). Thrown damage is the weapon's own and grows with the hero's
## level (Hero.refresh), so it does not ride on a heavy melee weapon.
static func throw_weapon(g, p: Dictionary, dir: Vector2, free: bool = false) -> void:
	var st: Dictionary = p.st
	var kind: String = THROW_KIND.get(p.get("throw", "ink_knife"), "knife")
	var dmg: float = st.throw_dmg * damage_bonus(p) * (STORM_DMG if free else 1.0)
	var from := Physics.center(p) + Vector2(p.facing * 6.0, -4.0)
	var dirs: Array = [dir]
	if st.twin_throw and not free:
		dirs.append(dir.rotated(-0.16 * p.facing))
	for i in dirs.size():
		var d: Vector2 = dirs[i]
		var pr: Dictionary
		var k := 1.0 if i == 0 else 0.6
		match kind:
			"boomerang":
				pr = fire(g, from, d * 400.0, "hero", dmg * k, 0.0, kind)
				pr.life = 2.6
				pr.pierce = 99
			"chakram":
				pr = fire(g, from, d * 380.0, "hero", dmg * k, 0.0, kind)
				pr.life = 2.2
				pr.pierce = 3
				pr.bounce = 3
			"flask":
				pr = fire(g, from, d * 330.0 + Vector2(0, -130.0), "hero", dmg * k, 700.0, kind)
			"javelin":
				pr = fire(g, from, d * 560.0, "hero", dmg * k, 0.0, kind)
				pr.pierce = 99
				pr.life = 1.4
			_:
				pr = fire(g, from, d * Hero.KNIFE_SPEED, "hero", dmg * k, 0.0, kind)
		if st.ricochet:
			pr.pierce += 1
			pr.bounce += 1
	g.sfx("throw", -4.0 if free else 0.0, 0.8 if kind == "flask" else 1.0)


## Juggernaut: a ripple of broken ground runs a short way along the floor from
## the finisher (at most every Hero.WAVE_COOLDOWN seconds).
static func ground_wave(g, p: Dictionary) -> void:
	var st: Dictionary = p.st
	var pr := fire(g, Physics.foot(p) + Vector2(p.facing * 14.0, -6.0), Vector2(p.facing * 300.0, 0.0), "hero",
		st.dmg * st.dmg_mult * 0.8, 0.0, "hwave")
	pr.pierce = 99
	pr.life = 0.5
	g.sfx("slam", -6.0, 1.3)


## Quake: the dive lands with a blast that hits every foe on the ground nearby.
static func quake(g, p: Dictionary) -> void:
	var st: Dictionary = p.st
	g.hitstop = maxf(g.hitstop, 0.06)
	g.shake_add(8.0)
	g.sfx("slam", -2.0, 0.9)
	shockwave(g, Physics.foot(p) + Vector2(0, -8), 80.0, st.dmg * st.dmg_mult * 2.0 * damage_bonus(p), g.biome.edge)


## Hits every foe within [radius] and throws them back.
static func shockwave(g, at: Vector2, radius: float, dmg: float, col: Color) -> void:
	for k in 18:
		var a := PI + PI * k / 17.0
		g.particles.append({"p": at, "v": Vector2(cos(a), sin(a) * 0.4) * 260.0, "g": "~" if k % 2 == 0 else "'", "c": col,
			"life": 0.35, "max": 0.35, "grav": 0.0, "drag": 4.0, "s": 1.0})
	for e in g.enemies.duplicate():
		var d: Vector2 = Physics.center(e) - at
		if d.length() < radius + e.size.x * 0.5 and not (e.kind == "wisp" and _wisp_hidden(e)):
			hurt_enemy(g, e, dmg, Vector2(signf(d.x), -0.5), false)
			if g.enemies.has(e) and not e.boss:
				e.vel = Vector2(signf(d.x) * 260.0, -220.0)
				e.stun = 0.6


## Shoulder Charge: the dash bowls over every foe it passes through, once.
static func dash_hits(g, p: Dictionary) -> void:
	var st: Dictionary = p.st
	var r := Physics.rect(p).grow(4.0)
	for e in g.enemies.duplicate():
		if p.dash_hit.has(e.id) or not r.intersects(Physics.rect(e)):
			continue
		p.dash_hit[e.id] = true
		hurt_enemy(g, e, st.dmg * st.dmg_mult * damage_bonus(p), Vector2(p.facing, -0.3), true)
		if g.enemies.has(e) and not e.boss:
			e.vel = Vector2(p.facing * 300.0, -200.0)
			e.stun = 0.5
		g.hitstop = maxf(g.hitstop, 0.04)
		g.shake_add(3.0)


static func _hero_shot_hits(g, pr: Dictionary) -> void:
	var st: Dictionary = g.player.st
	for e in g.enemies.duplicate():
		if pr.hits.get(e.id, -1.0) > pr.t or (e.kind == "wisp" and _wisp_hidden(e)):
			continue
		if not Physics.rect(e).grow(3.0).has_point(pr.pos):
			continue
		if pr.kind == "flask":
			_burst_flask(g, pr)
			return
		# a boomerang can hit the same foe once more, on its way back
		var again: bool = pr.kind == "boomerang" and not pr.back.has(e.id)
		if again:
			pr.back[e.id] = true
		pr.hits[e.id] = maxf(pr.t + 0.3, 0.45) if again else 99.0
		if Foes.blocks(e, pr.pos.x, "side") and pr.kind != "chakram" and pr.kind != "javelin":
			g.sfx("clink", -4.0)
			if pr.kind != "boomerang":
				g.projectiles.erase(pr)
				return
			pr.t = maxf(pr.t, 0.4)
			continue
		hurt_enemy(g, e, pr.dmg, pr.vel.normalized())
		g.sfx("hit", -4.0, 1.3)
		if g.enemies.has(e):
			if st.hex:
				e.burn = 2.5
			if st.chill:
				e.chill = 2.0
		if st.siphon and pr.get("siphoned", 0.0) < SIPHON_MAX:
			var p: Dictionary = g.player
			pr.siphoned = pr.get("siphoned", 0.0) + SIPHON_INK
			p.ink = minf(Hero.MAX_INK, p.ink + SIPHON_INK)
		if pr.pierce <= 0:
			g.projectiles.erase(pr)
			return
		pr.pierce -= 1


static func _burst_flask(g, pr: Dictionary) -> void:
	g.projectiles.erase(pr)
	g.sfx("splash", -2.0, 0.7)
	burst(g, pr.pos, ["@", "o", "·", "*"], SHOT_LOOK.flask[1], 22, 170.0, -40.0)
	var st: Dictionary = g.player.st
	for e in g.enemies.duplicate():
		if Physics.center(e).distance_to(pr.pos) < 46.0 + e.size.x * 0.5:
			hurt_enemy(g, e, pr.dmg, (Physics.center(e) - pr.pos).normalized())
			if g.enemies.has(e):
				e.burn = 3.0
				if st.chill:
					e.chill = 2.0
	var cracked: Array = Physics.tiles_in(Rect2(pr.pos - Vector2(20, 20), Vector2(40, 40)), g.lv, Level.CRACKED)
	if not cracked.is_empty():
		break_tiles(g, cracked)


static func _update_hero_shot(g, pr: Dictionary, dt: float) -> void:
	var lv = g.lv
	var p: Dictionary = g.player
	pr.t += dt
	pr.life -= dt
	if pr.kind == "boomerang" and pr.t > 0.36:
		# turns around and flies back to the hand, through walls
		var to_p: Vector2 = Physics.center(p) - pr.pos
		pr.vel = pr.vel.move_toward(to_p.normalized() * 470.0, 1500.0 * dt)
		if pr.t > 0.6 and to_p.length() < 14.0:
			g.projectiles.erase(pr)
			return
	pr.vel.y += pr.grav * dt
	var nxt: Vector2 = pr.pos + pr.vel * dt
	var tx := int(floor(nxt.x / D.TILE))
	var ty := int(floor(nxt.y / D.TILE))
	if pr.kind != "boomerang" and lv.solid(tx, ty):
		if lv.at(tx, ty) == Level.CRACKED and pr.kind != "hwave":
			break_tiles(g, [Vector2i(tx, ty)])
		if pr.kind == "flask":
			_burst_flask(g, pr)
			return
		if pr.bounce > 0 and pr.kind != "hwave":
			pr.bounce -= 1
			if lv.solid(int(floor(nxt.x / D.TILE)), int(floor(pr.pos.y / D.TILE))):
				pr.vel.x = -pr.vel.x
			if lv.solid(int(floor(pr.pos.x / D.TILE)), int(floor(nxt.y / D.TILE))):
				pr.vel.y = -pr.vel.y
			g.sfx("clink", -10.0, 1.5)
			nxt = pr.pos
		else:
			pr.life = 0.0
	if pr.kind == "hwave":
		var below := int(floor((nxt.y + 10.0) / D.TILE))
		if not (lv.solid(tx, below) or lv.at(tx, below) == Level.ONEWAY):
			pr.life = 0.0
		elif g.rng.randf() < 40.0 * dt:
			burst(g, nxt + Vector2(0, 6), [".", ",", "'"], g.biome.edge, 1, 60.0, -60.0)
	pr.pos = nxt
	if pr.life <= 0.0:
		g.projectiles.erase(pr)
		burst(g, pr.pos, ["·", "*"], SHOT_LOOK.get(pr.kind, SHOT_LOOK.knife)[1], 5, 80.0)
		return
	if g.rng.randf() < 30.0 * dt:
		g.particles.append({"p": pr.pos, "v": Vector2.ZERO, "g": "·", "c": SHOT_LOOK.get(pr.kind, SHOT_LOOK.knife)[1],
			"life": 0.3, "max": 0.3, "grav": 0.0, "drag": 0.0, "s": 0.8})
	_hero_shot_hits(g, pr)


static func update_projectiles(g, dt: float) -> void:
	var p: Dictionary = g.player
	var lv = g.lv
	for pr in g.projectiles.duplicate():
		if not g.projectiles.has(pr):
			continue
		if pr.delay > 0.0:
			pr.delay -= dt
			continue
		if pr.owner == "hero":
			_update_hero_shot(g, pr, dt)
			continue
		pr.vel.y += pr.grav * dt
		pr.pos += pr.vel * dt
		pr.life -= dt
		var col: Color = SHOT_LOOK.get(pr.kind, SHOT_LOOK.shot)[1]
		if g.rng.randf() < 30.0 * dt:
			g.particles.append({"p": pr.pos, "v": Vector2.ZERO, "g": "·", "c": col,
				"life": 0.3, "max": 0.3, "grav": 0.0, "drag": 0.0, "s": 0.8})
		var tx := int(floor(pr.pos.x / D.TILE))
		var ty := int(floor(pr.pos.y / D.TILE))
		var dead: bool = pr.life <= 0.0 or lv.solid(tx, ty)
		if pr.kind == "wave":
			var below := int(floor((pr.pos.y + 10.0) / D.TILE))
			dead = dead or not (lv.solid(tx, below) or lv.at(tx, below) == Level.ONEWAY)
		if dead:
			g.projectiles.erase(pr)
			burst(g, pr.pos, ["·", "*"], col, 5, 80.0)
			continue
		if not p.dead and Physics.rect(p).grow(2.0).has_point(pr.pos):
			g.projectiles.erase(pr)
			hurt_player(g, pr.dmg, pr.pos.x)
			if pr.kind == "frost":
				p.chill_t = 1.2


## kind: "fire" (Ember Colossus) or "light" (Drowned Abbess).
static func add_pillar(g, x: float, floor_y: float, kind: String = "fire") -> void:
	g.hazards.append({"x": x, "y": floor_y, "t": 0.0, "warn": 0.75, "active": 0.5, "kind": kind})


static func update_hazards(g, dt: float) -> void:
	var p: Dictionary = g.player
	for hz in g.hazards.duplicate():
		var was: float = hz.t
		hz.t += dt
		if was < hz.warn and hz.t >= hz.warn:
			g.sfx("explode", -8.0, 1.6)
		if hz.t >= hz.warn and hz.t < hz.warn + hz.active:
			var r := Rect2(hz.x - 10.0, hz.y - 110.0, 20.0, 110.0)
			if not p.dead and r.intersects(Physics.rect(p)):
				hurt_player(g, 1, hz.x)
			if g.rng.randf() < 36.0 * dt:
				g.particles.append({"p": Vector2(hz.x + g.rng.randf_range(-8, 8), hz.y - g.rng.randf_range(0, 100)),
					"v": Vector2(0, -120), "g": "*", "c": Color(1.0, 0.6, 0.2), "life": 0.4, "max": 0.4,
					"grav": -100.0, "drag": 0.0, "s": 1.0})
		if hz.t > hz.warn + hz.active:
			g.hazards.erase(hz)


static func explode(g, at: Vector2, radius: float, hurts_player: bool) -> void:
	g.sfx("explode")
	g.shake_add(9.0)
	burst(g, at, ["*", "#", "@", "+", "·"], Color(1.0, 0.6, 0.25), 26, 230.0)
	burst(g, at, ["·", "."], Color(1.0, 0.9, 0.5), 12, 120.0)
	var p: Dictionary = g.player
	if hurts_player and not p.dead and Physics.center(p).distance_to(at) < radius:
		hurt_player(g, 1.6, at.x)
	for e in g.enemies.duplicate():
		if Physics.center(e).distance_to(at) < radius:
			hurt_enemy(g, e, 30.0, (Physics.center(e) - at).normalized())
	var cracked: Array = Physics.tiles_in(Rect2(at - Vector2(radius, radius) * 0.6, Vector2(radius, radius) * 1.2), g.lv, Level.CRACKED)
	if not cracked.is_empty():
		break_tiles(g, cracked)


# ---------------------------------------------------------------- shards and pickups

static func update_shards(g, dt: float) -> void:
	var p: Dictionary = g.player
	var pc := Physics.center(p)
	var reach: float = 95.0 * p.st.magnet
	for s in g.shards.duplicate():
		s.t += dt
		var d: Vector2 = pc - (s.pos + s.size * 0.5)
		if s.t > 0.45 and d.length() < reach and not p.dead:
			s.vel = s.vel.move_toward(d.normalized() * 380.0, 2400.0 * dt)
			s.pos += s.vel * dt
			if d.length() < 12.0:
				g.shards.erase(s)
				p.shards += 1
				g.shard_streak += 1
				g.sfx("shard", -8.0, 1.0 + minf(g.shard_streak, 12) * 0.04, 0.0)
				burst(g, pc, ["·"], Color(1.0, 0.85, 0.4), 2, 50.0)
		else:
			s.vel.y = minf(s.vel.y + 900.0 * dt, 400.0)
			s.vel.x = move_toward(s.vel.x, 0.0, 120.0 * dt)
			var vy_before: float = s.vel.y
			Physics.move(s, g.lv, dt)
			if s.on_floor and vy_before > 120.0:
				s.vel.y = -vy_before * 0.35
		if s.t > 25.0:
			g.shards.erase(s)


static func update_pickups(g, dt: float) -> void:
	var p: Dictionary = g.player
	if p.dead:
		return
	var pr := Physics.rect(p).grow(4.0)
	var pc := Physics.center(p)
	for pk in g.pickups.duplicate():
		# health orbs drift toward a wounded hero
		if pk.kind == "orb" and p.hp < p.max_hp and pk.pos.distance_to(pc) < 70.0:
			pk.pos = pk.pos.move_toward(pc, 360.0 * dt)
		if not pr.has_point(pk.pos):
			continue
		if (pk.kind == "heart" or pk.kind == "orb") and p.hp < p.max_hp:
			heal_player(g, 0.25 if pk.kind == "heart" else 0.12)
			g.pickups.erase(pk)
			g.sfx("heart", -4.0 if pk.kind == "orb" else 0.0, 1.2 if pk.kind == "orb" else 1.0)
			burst(g, pk.pos, ["+", "·"], Color(1.0, 0.4, 0.5), 10, 90.0, -60.0)
		elif pk.kind == "cache":
			g.pickups.erase(pk)
			g.sfx("chest", -4.0, 1.3)
			drop_shards(g, pk.pos, g.rng.randi_range(8, 14))


# ---------------------------------------------------------------- effects

static func burst(g, at: Vector2, glyphs: Array, color: Color, count: int, speed: float, lift: float = 0.0) -> void:
	for i in count:
		var a: float = g.rng.randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a)) * g.rng.randf_range(0.3, 1.0) * speed + Vector2(0, lift)
		var life: float = g.rng.randf_range(0.25, 0.6)
		g.particles.append({"p": at, "v": v, "g": glyphs[g.rng.randi_range(0, glyphs.size() - 1)], "c": color,
			"life": life, "max": life, "grav": 200.0, "drag": 3.0, "s": 0.85})


static func update_particles(g, dt: float) -> void:
	var keep: Array = []
	for pt in g.particles:
		pt.life -= dt
		if pt.life <= 0.0:
			continue
		pt.v.y += pt.grav * dt
		pt.v *= maxf(0.0, 1.0 - pt.drag * dt)
		pt.p += pt.v * dt
		keep.append(pt)
	var cap: int = g.particle_cap()
	if keep.size() > cap:
		keep = keep.slice(keep.size() - cap)
	g.particles = keep
	var keep2: Array = []
	for pu in g.popups:
		pu.life -= dt
		pu.pos.y -= 30.0 * dt
		if pu.life > 0.0:
			keep2.append(pu)
	g.popups = keep2
