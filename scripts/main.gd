## Game state, input, combat rules and level flow.
extends Node2D

const D := preload("res://scripts/data.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Renderer := preload("res://scripts/renderer.gd")
const Hud := preload("res://scripts/hud.gd")
const PostShader := preload("res://shaders/post.gdshader")
const FontRegular := preload("res://fonts/DejaVuSansMono.ttf")
const FontBold := preload("res://fonts/DejaVuSansMono-Bold.ttf")

enum State { TITLE, PLAY, DEAD, PAUSE }

const KEYS := {
	"left": [KEY_LEFT, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"up": [KEY_UP, KEY_W],
	"down": [KEY_DOWN, KEY_S],
	"jump": [KEY_SPACE, KEY_Z, KEY_K],
	"attack": [KEY_X, KEY_J],
	"dash": [KEY_C, KEY_L, KEY_SHIFT],
	"heal": [KEY_H],
}

var state: State = State.TITLE
var rng := RandomNumberGenerator.new()
var lv: Level
var level_num := 1
var biome: Dictionary = D.BIOMES[0]
var player: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var shards: Array = []
var pickups: Array = []
var particles: Array = []
var slashes: Array = []
var ghosts: Array = []

var held := {}
var just := {}
var released := {}
var _prev := {}

var cam := Vector2.ZERO
var look := 0.0
var shake := 0.0
var hurt_flash := 0.0
var fade := 0.0
var hitstop := 0.0
var slowmo := 1.0
var dying_t := 0.0
var run_time := 0.0
var level_time := 0.0
var kills := 0
var shard_count := 0
var lang := "en"
var ui_scale := 1.0

var font: Font
var font_bold: Font
var world: Node2D
var hud: Node2D
var post: ColorRect

# Debug / screenshot options, passed after "--":
#   --play  --bot  --seed=N  --level=N  --shot=file.png  --time=seconds  --lang=ru
var _shot_path := ""
var _shot_time := 1.0
var _bot := false
var _bot_t := 0.0
var _start_level := 1
var _record_dir := ""
var _record_frame := 0


func _ready() -> void:
	rng.randomize()
	lang = "ru" if OS.get_locale_language() == "ru" else "en"
	ui_scale = maxf(1.0, DisplayServer.screen_get_scale())
	for a in KEYS:
		held[a] = false
		just[a] = false
		released[a] = false
		_prev[a] = false
	var autostart := _parse_cmdline()
	if _shot_path == "":
		_fit_window()

	font = _make_font(400)
	font_bold = _make_font(700)

	world = Renderer.new()
	add_child(world)
	world.setup(self, font, font_bold)

	var post_layer := CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PostShader
	mat.set_shader_parameter("radius", 1.6 * ui_scale)
	post.material = mat
	post_layer.add_child(post)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = Hud.new()
	hud_layer.add_child(hud)
	hud.setup(self, font, font_bold)

	if autostart:
		new_run()
	else:
		show_title()


func _parse_cmdline() -> bool:
	var autostart := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--time="):
			_shot_time = float(a.substr(7))
		elif a.begins_with("--seed="):
			rng.seed = hash(a.substr(7))
		elif a.begins_with("--level="):
			_start_level = maxi(1, int(a.substr(8)))
		elif a.begins_with("--lang="):
			lang = a.substr(7)
		elif a.begins_with("--record="):
			_record_dir = a.substr(9)
		elif a == "--bot":
			_bot = true
		elif a == "--play":
			autostart = true
	return autostart


func _fit_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var r := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(int(r.size.x * 0.85), int(r.size.y * 0.85))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(r.position + (r.size - size) / 2)


func _make_font(weight: int) -> Font:
	var bundled: Font = FontBold if weight >= 700 else FontRegular
	# System fonts are not available on the Web, so use the bundled one there.
	if OS.has_feature("web"):
		return bundled
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Menlo", "SF Mono", "Monaco", "JetBrains Mono", "DejaVu Sans Mono",
		"Liberation Mono", "Consolas", "Courier New", "monospace",
	])
	f.font_weight = weight
	f.fallbacks = [bundled]
	return f


func L(key: String) -> String:
	return D.STRINGS[lang].get(key, key)


func biome_name() -> String:
	return biome["name_" + lang]


func is_title() -> bool:
	return state == State.TITLE


# ---------------------------------------------------------------- flow

func show_title() -> void:
	state = State.TITLE
	level_num = 1
	_build_level()
	world.title_cam_reset()


func new_run() -> void:
	level_num = _start_level
	kills = 0
	shard_count = 0
	run_time = 0.0
	player = {}
	_build_level()
	state = State.PLAY


func _build_level() -> void:
	biome = D.BIOMES[(level_num - 1) % D.BIOMES.size()]
	lv = Level.new()
	lv.build(level_num, rng)
	var old := player
	player = Hero.create(lv.start)
	if not old.is_empty():
		player.hp = old.hp
		player.max_hp = old.max_hp
	enemies.clear()
	for s in lv.spawns:
		enemies.append(Foes.create(s.kind, s.pos, level_num, rng))
	pickups = []
	for pk in lv.pickups:
		pickups.append({"kind": pk.kind, "pos": pk.pos - Vector2(0, 8)})
	projectiles.clear()
	shards.clear()
	particles.clear()
	slashes.clear()
	ghosts.clear()
	slowmo = 1.0
	hitstop = 0.0
	level_time = 0.0
	fade = 1.0
	cam = Physics.center(player)
	world.on_level_built()


func _next_level() -> void:
	level_num += 1
	_build_level()


# ---------------------------------------------------------------- input

func _poll_input() -> void:
	for a in KEYS:
		var h := false
		for k in KEYS[a]:
			if Input.is_physical_key_pressed(k):
				h = true
				break
		held[a] = h
	if _bot and state == State.PLAY:
		_bot_input()
	for a in KEYS:
		just[a] = held[a] and not _prev[a]
		released[a] = _prev[a] and not held[a]
		_prev[a] = held[a]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var e := event as InputEventKey
	var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	match k:
		KEY_F:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		KEY_G:
			post.visible = not post.visible
			return
		KEY_EQUAL, KEY_KP_ADD:
			world.zoom(1)
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			world.zoom(-1)
			return
	match state:
		State.TITLE:
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				new_run()
			elif k == KEY_L:
				lang = "en" if lang == "ru" else "ru"
			elif k == KEY_ESCAPE:
				get_tree().quit()
		State.PLAY:
			if k == KEY_ESCAPE or k == KEY_P:
				state = State.PAUSE
		State.PAUSE:
			if k == KEY_ESCAPE or k == KEY_P:
				state = State.PLAY
			elif k == KEY_Q:
				show_title()
			elif k == KEY_L:
				lang = "en" if lang == "ru" else "ru"
		State.DEAD:
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				new_run()
			elif k == KEY_ESCAPE:
				show_title()


# ---------------------------------------------------------------- frame

func _physics_process(dt: float) -> void:
	_poll_input()
	if _record_dir != "" and state == State.PLAY:
		_record_frame += 1
		if _record_frame % 3 == 0:
			get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [_record_dir, _record_frame / 3])
	if _shot_path != "":
		_shot_time -= dt
		if _shot_time <= 0.0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			print("state=%d level=%d hp=%d kills=%d shards=%d x=%.0f/%.0f" % [
				state, level_num, player.get("hp", 0), kills, shard_count,
				player.get("pos", Vector2.ZERO).x, lv.pixel_size().x])
			get_tree().quit()
			_shot_path = ""

	shake = move_toward(shake, 0.0, dt * 30.0)
	hurt_flash = move_toward(hurt_flash, 0.0, dt * 2.5)
	fade = move_toward(fade, 0.0, dt * 2.2)

	match state:
		State.TITLE:
			_update_particles(dt)
		State.PAUSE:
			pass
		State.DEAD:
			_update_particles(dt)
			_update_effects(dt)
		State.PLAY:
			if hitstop > 0.0:
				hitstop -= dt
				return
			var sdt := dt * slowmo
			run_time += dt
			level_time += dt
			Hero.update(self, player, sdt)
			for e in enemies.duplicate():
				Foes.update(self, e, sdt)
			_update_projectiles(sdt)
			_update_shards(sdt)
			_update_pickups()
			_check_contacts()
			_update_particles(sdt)
			_update_effects(sdt)
			_update_camera(dt)
			if player.dead:
				dying_t -= dt
				if dying_t <= 0.0:
					state = State.DEAD
			elif lv.door.has_point(Physics.center(player)):
				_next_level()


func _update_camera(dt: float) -> void:
	var c := Physics.center(player)
	look = move_toward(look, player.facing * 46.0, 140.0 * dt)
	var target := c + Vector2(look, -10.0)
	cam = cam.lerp(target, 1.0 - exp(-dt * 6.0))
	cam = world.clamp_cam(cam)


func _update_effects(dt: float) -> void:
	for s in slashes.duplicate():
		s.t += dt
		if s.t > 0.22:
			slashes.erase(s)
	for gh in ghosts.duplicate():
		gh.life -= dt
		if gh.life <= 0.0:
			ghosts.erase(gh)


# ---------------------------------------------------------------- combat

func attack_hits(p: Dictionary, box: Rect2) -> void:
	var hit_any := false
	var kdir := Vector2(p.facing, 0)
	if p.atk_kind == "up":
		kdir = Vector2(0, -1)
	elif p.atk_kind == "down":
		kdir = Vector2(0, 1)
	for e in enemies.duplicate():
		if p.atk_hit.has(e.id):
			continue
		if box.intersects(Physics.rect(e)):
			p.atk_hit[e.id] = true
			var dmg := 2 if (p.atk_kind == "side" and p.combo == 2) else 1
			hurt_enemy(e, dmg, kdir)
			hit_any = true
	for pr in projectiles.duplicate():
		if box.has_point(pr.pos):
			projectiles.erase(pr)
			burst(pr.pos, ["*", "+", "·"], Color(1.0, 0.9, 0.6), 8, 120.0)
			hit_any = true
	if p.atk_kind == "down" and not p.atk_hit.has("spikes") and Physics.touches_spikes(box, lv):
		p.atk_hit["spikes"] = true
		hit_any = true
	if hit_any:
		hitstop = maxf(hitstop, 0.05)
		shake = maxf(shake, 2.5)
		if p.atk_kind == "down":
			p.vel.y = -Hero.POGO
			p.air_dash = true
			p.dash_cd = 0.0
		elif p.atk_kind == "side" and not p.on_floor:
			p.vel.y = minf(p.vel.y, 0.0)


func hurt_enemy(e: Dictionary, dmg: int, kdir: Vector2) -> void:
	e.hp -= dmg
	e.flash = 0.12
	e.stun = 0.2
	e.aggro = true
	if e.kind == "bat":
		e.vel = kdir * 220.0
	elif e.kind != "spitter":
		e.vel.x = (kdir.x if kdir.x != 0.0 else float(e.dir) * -1.0) * 190.0
		e.vel.y = -110.0 if kdir.y >= 0.0 else -180.0
	if e.kind == "knight" and e.state == "tele":
		e.state = "rest"
		e.t = 0.4
	burst(Physics.center(e), ["*", "+", "x", "·"], Color(1, 1, 1), 7, 150.0)
	if e.hp <= 0:
		_kill_enemy(e)


func _kill_enemy(e: Dictionary) -> void:
	enemies.erase(e)
	kills += 1
	hitstop = maxf(hitstop, 0.07)
	shake = maxf(shake, 4.0)
	var col: Color = D.ENEMIES[e.kind].color
	var lines: Array = Foes.frame(e)
	var f := Physics.foot(e)
	for i in lines.size():
		var line: String = lines[i]
		for j in line.length():
			var ch := line[j]
			if ch == " ":
				continue
			var p := f + Vector2((j - line.length() * 0.5) * 6.0, -(lines.size() - i) * 10.0)
			particles.append({"p": p, "v": Vector2(rng.randf_range(-140, 140), rng.randf_range(-260, -80)),
				"g": ch, "c": col, "life": 1.1, "max": 1.1, "grav": 900.0, "drag": 0.5, "s": 1.0})
	for k in rng.randi_range(3, 6):
		shards.append({"pos": Physics.center(e), "size": Vector2(4, 4),
			"vel": Vector2(rng.randf_range(-120, 120), rng.randf_range(-260, -120)),
			"on_floor": false, "on_wall": 0, "t": 0.0})
	if rng.randf() < 0.1:
		pickups.append({"kind": "heart", "pos": Physics.center(e)})


func hurt_player(dmg: int, src_x: float, spikes: bool = false) -> void:
	var p := player
	if p.inv > 0.0 or p.dead or p.respawn_t > 0.0:
		return
	p.hp -= dmg
	p.inv = 1.1
	p.blink = 1.1
	p.hurt_t = 0.22
	p.dash_t = 0.0
	var away := 1.0 if Physics.center(p).x >= src_x else -1.0
	p.vel = Vector2(away * 190.0, -260.0)
	hitstop = 0.11
	shake = 8.0
	hurt_flash = 1.0
	burst(Physics.center(p), ["*", "x", "·", "+"], Color(1.0, 0.35, 0.3), 12, 170.0)
	if p.hp <= 0:
		p.hp = 0
		p.dead = true
		slowmo = 0.35
		dying_t = 1.4
		var lines: Array = Hero.frame(p)
		for i in lines.size():
			var line: String = lines[i]
			for j in line.length():
				if line[j] != " ":
					particles.append({"p": Physics.foot(p) + Vector2((j - 1) * 6.0, -(lines.size() - i) * 10.0),
						"v": Vector2(rng.randf_range(-120, 120), rng.randf_range(-280, -120)), "g": line[j],
						"c": Color(0.95, 0.93, 0.85), "life": 1.6, "max": 1.6, "grav": 700.0, "drag": 0.4, "s": 1.0})
	elif spikes:
		p.respawn_t = 0.45


func _check_contacts() -> void:
	var p := player
	if p.dead:
		return
	var pr := Physics.rect(p)
	for e in enemies:
		if pr.intersects(Physics.rect(e).grow(-2.0)):
			hurt_player(1, Physics.center(e).x)


func fire(from: Vector2, vel: Vector2) -> void:
	projectiles.append({"pos": from, "vel": vel, "life": 4.0})
	burst(from, ["·"], Color(1.0, 0.5, 0.4), 4, 60.0)


func _update_projectiles(dt: float) -> void:
	var p := player
	for pr in projectiles.duplicate():
		pr.pos += pr.vel * dt
		pr.life -= dt
		if rng.randf() < 0.5:
			particles.append({"p": pr.pos, "v": Vector2.ZERO, "g": "·", "c": Color(1.0, 0.45, 0.35),
				"life": 0.3, "max": 0.3, "grav": 0.0, "drag": 0.0, "s": 0.8})
		var tx := int(floor(pr.pos.x / D.TILE))
		var ty := int(floor(pr.pos.y / D.TILE))
		if pr.life <= 0.0 or lv.solid(tx, ty):
			projectiles.erase(pr)
			burst(pr.pos, ["·", "*"], Color(1.0, 0.5, 0.4), 5, 80.0)
		elif not p.dead and Physics.rect(p).grow(2.0).has_point(pr.pos):
			projectiles.erase(pr)
			hurt_player(1, pr.pos.x)


func _update_shards(dt: float) -> void:
	var p := player
	var pc := Physics.center(p)
	for s in shards.duplicate():
		s.t += dt
		var d: Vector2 = pc - (s.pos + s.size * 0.5)
		if s.t > 0.45 and d.length() < 95.0 and not p.dead:
			s.vel = s.vel.move_toward(d.normalized() * 380.0, 2400.0 * dt)
			s.pos += s.vel * dt
			if d.length() < 12.0:
				shards.erase(s)
				shard_count += 1
				burst(pc, ["·"], Color(1.0, 0.85, 0.4), 2, 50.0)
		else:
			s.vel.y = minf(s.vel.y + 900.0 * dt, 400.0)
			s.vel.x = move_toward(s.vel.x, 0.0, 120.0 * dt)
			var vy_before: float = s.vel.y
			Physics.move(s, lv, dt)
			if s.on_floor and vy_before > 120.0:
				s.vel.y = -vy_before * 0.35
		if s.t > 15.0:
			shards.erase(s)


func _update_pickups() -> void:
	var p := player
	if p.dead:
		return
	var pr := Physics.rect(p)
	for pk in pickups.duplicate():
		if pk.kind == "heart" and pr.has_point(pk.pos) and p.hp < p.max_hp:
			p.hp += 1
			pickups.erase(pk)
			burst(pk.pos, ["+", "·"], Color(1.0, 0.4, 0.5), 10, 90.0, -60.0)


# ---------------------------------------------------------------- effects

func burst(at: Vector2, glyphs: Array, color: Color, count: int, speed: float, lift: float = 0.0) -> void:
	for i in count:
		var a := rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * rng.randf_range(0.3, 1.0) * speed + Vector2(0, lift)
		var life := rng.randf_range(0.25, 0.6)
		particles.append({"p": at, "v": v, "g": glyphs[rng.randi_range(0, glyphs.size() - 1)], "c": color,
			"life": life, "max": life, "grav": 200.0, "drag": 3.0, "s": 0.85})


func _update_particles(dt: float) -> void:
	for pt in particles.duplicate():
		pt.life -= dt
		if pt.life <= 0.0:
			particles.erase(pt)
			continue
		pt.v.y += pt.grav * dt
		pt.v *= maxf(0.0, 1.0 - pt.drag * dt)
		pt.p += pt.v * dt
	if particles.size() > 600:
		particles = particles.slice(particles.size() - 600)


func add_slash(kind: String, combo: int, facing: int) -> void:
	slashes.append({"kind": kind, "combo": combo, "facing": facing, "t": 0.0})


func add_ghost(p: Dictionary) -> void:
	ghosts.append({"foot": Physics.foot(p), "facing": p.facing, "lines": Hero.frame(p), "life": 0.22})


# ---------------------------------------------------------------- test bot

## Simple scripted player used for automated testing and screenshots.
func _bot_input() -> void:
	_bot_t += get_physics_process_delta_time()
	var p := player
	held.right = true
	var c := Physics.center(p)
	var T := D.TILE
	var ahead := int(floor((c.x + 20.0) / T))
	var feet := int(floor((p.pos.y + p.size.y + 2.0) / T))
	var wall := lv.solid(ahead, int(floor(c.y / T))) or lv.solid(ahead, int(floor((p.pos.y + p.size.y - 4.0) / T)))
	var gap := lv.at(ahead, feet) != Level.SOLID and lv.at(ahead, feet) != Level.ONEWAY
	held.jump = (p.on_floor and (wall or gap)) or (not p.on_floor and p.vel.y < 0.0 and _prev.jump)
	held.attack = false
	held.up = false
	held.down = false
	for e in enemies:
		var d: Vector2 = Physics.center(e) - c
		if absf(d.x) < 46.0 and absf(d.y) < 46.0:
			held.attack = not _prev.attack
			held.up = d.y < -24.0
			held.down = d.y > 24.0 and not p.on_floor
			break
	held.dash = fmod(_bot_t, 2.3) < 0.02
	held.heal = p.hp <= 2
