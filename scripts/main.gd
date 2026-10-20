## Game state, level flow, saving, input routing and the shared API that the
## hero, enemies, combat and props scripts call back into.
## The descent never ends: biomes repeat, deeper and harder. Falling in battle
## sends the hero back to the last lantern with full health and a few shards
## less; levels, gear and experience are kept.
extends Node2D

const D := preload("res://scripts/data.gd")
const T := preload("res://scripts/strings.gd")
const Items := preload("res://scripts/items.gd")
const Level := preload("res://scripts/level.gd")
const Physics := preload("res://scripts/physics.gd")
const Hero := preload("res://scripts/hero.gd")
const Foes := preload("res://scripts/foes.gd")
const Combat := preload("res://scripts/combat.gd")
const Props := preload("res://scripts/props.gd")
const Hints := preload("res://scripts/hints.gd")
const Settings := preload("res://scripts/settings.gd")
const Controls := preload("res://scripts/controls.gd")
const Audio := preload("res://scripts/audio.gd")
const Renderer := preload("res://scripts/renderer.gd")
const Hud := preload("res://scripts/hud.gd")
const Menu := preload("res://scripts/menu.gd")
const PostShader := preload("res://shaders/post.gdshader")
const FontRegular := preload("res://fonts/DejaVuSansMono.ttf")
const FontBold := preload("res://fonts/DejaVuSansMono-Bold.ttf")

enum State { TITLE, PLAY }

## The 0.4.0 single save; moved into the first world slot on start.
const RUN_PATH := "user://run.cfg"
## Each world (a hero with its own seed and difficulty) lives in its own slot.
const WORLD_PATH := "user://world_%d.cfg"
const MAX_WORLDS := 5
## Bumped when the saved hero changes shape; older saves are not continued.
const RUN_VERSION := 2
const DIFFICULTIES := ["easy", "normal", "hard", "nightmare"]
## Enemy damage and health, share of carried shards lost on a fall, experience.
const DIFF := {
	"easy": {"dmg": 0.6, "hp": 0.75, "toll": 0.15, "xp": 1.0},
	"normal": {"dmg": 1.0, "hp": 1.0, "toll": 0.3, "xp": 1.0},
	"hard": {"dmg": 1.4, "hp": 1.3, "toll": 0.5, "xp": 1.25},
	"nightmare": {"dmg": 1.9, "hp": 1.6, "toll": 1.0, "xp": 1.5},
}
const NAME_A := ["Ash", "Grave", "Hollow", "Mourn", "Dusk", "Wither", "Bone", "Raven", "Thorn", "Gloam", "Rot", "Cinder", "Black",
	"Dread", "Wraith", "Sorrow"]
const NAME_B := ["mere", "wood", "fall", "moor", "reach", "vale", "crypt", "barrow", "spire", "deep", "mire", "hold", "gate", "fen"]
const RUN_KEYS := ["hp", "base_hp", "ink", "shards", "weapon", "charms", "bag", "xp", "xp_level", "up_hp", "up_dmg"]
## Glyph-level fallbacks for Chinese and Japanese text (system fonts).
const CJK_FONTS := {
	"zh": ["PingFang SC", "Hiragino Sans GB", "Heiti SC", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "Noto Sans SC",
		"Source Han Sans SC", "WenQuanYi Micro Hei", "Droid Sans Fallback"],
	"ja": ["Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic", "Meiryo", "MS Gothic", "Noto Sans CJK JP", "Noto Sans JP",
		"Source Han Sans JP", "TakaoGothic", "Droid Sans Fallback"],
}

var state: State = State.TITLE
var rng := RandomNumberGenerator.new()
var run_seed := 0
var lv: Level
var level_num := 1
var biome: Dictionary = D.BIOMES[0]
var player: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var hazards: Array = []
var shards: Array = []
var pickups: Array = []
var props: Array = []
var particles: Array = []
var popups: Array = []
var slashes: Array = []
var ghosts: Array = []
var toasts: Array = []
var boss: Dictionary = {}
var near: Dictionary = {}
var hint := ""
var hint_state := {}
var shop_prop: Dictionary = {}
var sign_text := ""

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
var items_found := 0
var rooms_seen := 0
var shard_streak := 0
var _streak_t := 0.0
var ink_flash := 0.0
var lang := "en"
var lang_idx := 0
var ui_scale := 1.0
var checkpoint := Vector2.ZERO
var checkpoint_prop: Dictionary = {}
var hit_combo := 0
var combo_t := 0.0
var best_combo := 0
var crit_flash := 0.0
var level_up_t := 0.0
var _cjk: Array = []
## Bumped whenever tiles change after the level is built (for the minimap).
var lv_changes := 0
var world_slot := -1
var world_name := ""
var difficulty := "normal"

var cfg: Settings
var ctl: Controls
var audio: Audio
var font: Font
var font_bold: Font
var world: Renderer
var hud: Hud
var menu: Menu
var post: ColorRect

# Debug / screenshot options, passed after "--":
#   --play --bot --god --seed=N --level=N --shot=file.png --time=seconds --lang=ru --record=dir --menu=name
var _shot_path := ""
var _shot_time := 1.0
var _bot := false
var god := false
var _bot_t := 0.0
var _start_level := 1
var _record_dir := ""
var _record_frame := 0
var _menu_arg := ""
var _fixed_seed := -1
var _to_boss := false
var _nopost := false
var debug_tab := 0
## --uicheck: walks every menu in every language and prints text that leaves its panel or the window.
var ui_check := false
var _ui_steps: Array = []
var _ui_wait := 0
var _ui_issues := {}
var _zoo := false
var _dts: Array = []


func _process(delta: float) -> void:
	_dts.append(delta)
	if delta > 0.03 and _shot_path != "":
		print("slow frame %.0fms at %.2fs" % [delta * 1000.0, Time.get_ticks_msec() / 1000.0])
	if _dts.size() > 240:
		_dts.pop_front()


func _ready() -> void:
	rng.randomize()
	cfg = Settings.new()
	cfg.load_all()
	_migrate_save()
	ctl = Controls.new()
	ctl.setup(cfg.get_v("binds"))
	audio = Audio.new()
	add_child(audio)
	audio.setup()
	ui_scale = maxf(1.0, DisplayServer.screen_get_scale())
	var autostart := _parse_cmdline()
	if _shot_path == "":
		_fit_window()

	font = _make_font(400)
	font_bold = _make_font(700)
	_cjk = [_make_cjk(400), _make_cjk(700)]

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
	menu = Menu.new()
	hud_layer.add_child(menu)
	menu.setup(self, font, font_bold)

	apply_settings()
	post.visible = not _nopost
	get_tree().root.focus_entered.connect(func(): audio.set_muted(false))
	get_tree().root.focus_exited.connect(func(): audio.set_muted(cfg.get_v("mute_unfocused")))

	if autostart:
		new_run()
	else:
		show_title()
	if _menu_arg != "":
		menu.open(_menu_arg)


func _parse_cmdline() -> bool:
	var autostart := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--time="):
			_shot_time = float(a.substr(7))
		elif a.begins_with("--seed="):
			_fixed_seed = hash(a.substr(7))
			rng.seed = _fixed_seed
		elif a.begins_with("--level="):
			_start_level = maxi(1, int(a.substr(8)))
		elif a.begins_with("--lang="):
			cfg.values.lang = a.substr(7)
		elif a.begins_with("--record="):
			_record_dir = a.substr(9)
		elif a.begins_with("--menu="):
			_menu_arg = a.substr(7)
		elif a == "--bot":
			_bot = true
		elif a == "--god":
			god = true
		elif a.begins_with("--tab="):
			debug_tab = int(a.substr(6))
		elif a == "--zoo":
			_zoo = true
		elif a == "--nopost":
			_nopost = true
		elif a == "--boss":
			_to_boss = true
		elif a == "--play":
			autostart = true
		elif a.begins_with("--uiscale="):
			cfg.values.ui_scale = float(a.substr(10))
		elif a.begins_with("--uicheck"):
			ui_check = true
			if a.begins_with("--uicheck="):
				cfg.values.ui_scale = float(a.substr(10))
	return autostart


func _fit_window() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
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


func _make_cjk(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_weight = weight
	return f


## Points the CJK fallback at fonts for the current language, so Chinese and
## Japanese text get the right glyph shapes.
func _apply_cjk() -> void:
	if OS.has_feature("web"):
		return
	var names: Array = CJK_FONTS["ja" if lang == "ja" else "zh"]
	for i in 2:
		var cjk: SystemFont = _cjk[i]
		cjk.font_names = PackedStringArray(names)
		var main_font := font if i == 0 else font_bold
		var fb: Array = main_font.fallbacks
		if not fb.has(cjk):
			fb.append(cjk)
			main_font.fallbacks = fb

# ---------------------------------------------------------------- settings

## Applies the settings; [changed] names the one that changed ("" applies all).
## Costly steps (window mode, vsync, redrawing the world) only run when needed.
func apply_settings(changed: String = "") -> void:
	var all := changed == ""
	var l: String = cfg.get_v("lang")
	if not T.LANGS.has(l):
		l = OS.get_locale_language()
		if not T.LANGS.has(l):
			l = "en"
	lang = l
	lang_idx = T.LANGS.find(l)
	_apply_cjk()
	if DisplayServer.get_name() != "headless" and _shot_path == "" and not ui_check and (all or changed in ["window", "vsync"]):
		var mode: String = cfg.get_v("window")
		var want := DisplayServer.WINDOW_MODE_WINDOWED
		if mode == "borderless":
			want = DisplayServer.WINDOW_MODE_FULLSCREEN
		elif mode == "fullscreen":
			want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if not OS.has_feature("web") else DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if cfg.get_v("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(cfg.get_v("fps"))
	world.zoom_idx = int(cfg.get_v("zoom"))
	if all or changed in ["zoom", "quality", "lang"]:
		world.redraw_all()
	var mat := post.material as ShaderMaterial
	var q: String = cfg.get_v("quality")
	mat.set_shader_parameter("glow", 0.75 if cfg.get_v("glow") and q != "low" else 0.0)
	mat.set_shader_parameter("scanlines", 0.05 if cfg.get_v("scanlines") else 0.0)
	mat.set_shader_parameter("vignette", 0.35 if cfg.get_v("vignette") else 0.0)
	mat.set_shader_parameter("lighting", 1.0 if cfg.get_v("lighting") else 0.0)
	audio.set_volumes(cfg.get_v("vol_master"), cfg.get_v("vol_music"), cfg.get_v("vol_sfx"), cfg.get_v("vol_amb"))


func set_setting(key: String, v: Variant) -> void:
	if cfg.get_v(key) == v:
		return
	cfg.set_v(key, v)
	apply_settings(key)


## Particles kept alive at once, by quality.
func particle_cap() -> int:
	return {"low": 220, "medium": 420}.get(cfg.get_v("quality"), 700)


func L(key: String) -> String:
	var row: Array = T.STRINGS.get(key, [])
	if row.is_empty():
		return key
	return row[lang_idx] if lang_idx < row.size() and row[lang_idx] != "" else row[0]


func biome_name() -> String:
	return L("biome_" + biome.id)


func is_title() -> bool:
	return state == State.TITLE


func is_playing() -> bool:
	return state == State.PLAY


# ---------------------------------------------------------------- flow

func show_title() -> void:
	save_run()
	world_slot = -1
	state = State.TITLE
	level_num = 1
	run_seed = rng.randi()
	player = {}
	_build_level()
	world.title_cam_reset()
	menu.close_all()
	menu.open("title")
	audio.music("title")
	audio.ambient("wood")


## True when there is a world to continue.
func has_save() -> bool:
	return not worlds().is_empty()


## Saved worlds, most recently played first.
func worlds() -> Array:
	var out: Array = []
	if ui_check:
		for i in MAX_WORLDS:
			out.append({"slot": i, "name": "Wraithbarrow", "difficulty": DIFFICULTIES[i % 4], "level": 12 + i, "hero": 23, "time": 99999.0,
				"played": i})
		return out
	for slot in MAX_WORLDS:
		var cf := ConfigFile.new()
		if cf.load(WORLD_PATH % slot) != OK or cf.get_value("run", "ver", 1) != RUN_VERSION:
			continue
		var pl: Dictionary = cf.get_value("run", "player", {})
		out.append({"slot": slot, "name": cf.get_value("run", "name", "?"), "difficulty": cf.get_value("run", "difficulty", "normal"),
			"level": cf.get_value("run", "level", 1), "hero": pl.get("xp_level", 1), "time": cf.get_value("run", "time", 0.0),
			"played": cf.get_value("run", "played", 0)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.played > b.played)
	return out


func free_world_slot() -> int:
	for slot in MAX_WORLDS:
		if not FileAccess.file_exists(WORLD_PATH % slot):
			return slot
	return -1


static func make_world_name(seed_v: int) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return NAME_A[r.randi() % NAME_A.size()] + NAME_B[r.randi() % NAME_B.size()]


## Starts a new hero in a new world slot.
func create_world(wname: String, diff: String, seed_v: int) -> void:
	world_slot = free_world_slot()
	world_name = wname
	difficulty = diff
	run_seed = seed_v
	_begin_run()


func play_world(slot: int) -> void:
	world_slot = slot
	continue_run()


func delete_world(slot: int) -> void:
	var path := WORLD_PATH % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The single save of 0.4.0 becomes the first world.
func _migrate_save() -> void:
	if not FileAccess.file_exists(RUN_PATH):
		return
	var cf := ConfigFile.new()
	if cf.load(RUN_PATH) == OK and cf.get_value("run", "ver", 1) == RUN_VERSION and free_world_slot() >= 0:
		cf.set_value("run", "name", make_world_name(cf.get_value("run", "seed", 0)))
		cf.set_value("run", "difficulty", "normal")
		cf.set_value("run", "played", int(Time.get_unix_time_from_system()))
		cf.save(WORLD_PATH % free_world_slot())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


func diff() -> Dictionary:
	return DIFF.get(difficulty, DIFF.normal)


## A new hero without a world slot (debug starts with --play are not saved).
func new_run() -> void:
	world_slot = -1
	world_name = ""
	difficulty = "normal"
	run_seed = _fixed_seed if _fixed_seed != -1 else rng.randi()
	_begin_run()


func _begin_run() -> void:
	Foes.hp_mult = diff().hp
	player = Hero.create()
	level_num = _start_level
	kills = 0
	run_time = 0.0
	items_found = 0
	if not _bot:
		cfg.profile.runs += 1
		cfg.save_profile()
	_start_level_now()


## Continues world_slot, or the most recently played world.
func continue_run() -> void:
	if world_slot < 0:
		var ws := worlds()
		if ws.is_empty():
			return
		world_slot = ws[0].slot
	var cf := ConfigFile.new()
	if cf.load(WORLD_PATH % world_slot) != OK or cf.get_value("run", "ver", 1) != RUN_VERSION:
		return
	world_name = cf.get_value("run", "name", "")
	difficulty = cf.get_value("run", "difficulty", "normal")
	Foes.hp_mult = diff().hp
	run_seed = cf.get_value("run", "seed", 0)
	level_num = cf.get_value("run", "level", 1)
	kills = cf.get_value("run", "kills", 0)
	run_time = cf.get_value("run", "time", 0.0)
	items_found = 1
	player = Hero.create()
	var saved: Dictionary = cf.get_value("run", "player", {})
	for k in RUN_KEYS:
		if saved.has(k):
			player[k] = saved[k]
	Hero.refresh(player)
	_start_level_now()


func _start_level_now() -> void:
	state = State.PLAY
	menu.close_all()
	_build_level()
	save_run()


func save_run() -> void:
	if _bot or state != State.PLAY or world_slot < 0:
		return
	var cf := ConfigFile.new()
	cf.set_value("run", "ver", RUN_VERSION)
	cf.set_value("run", "name", world_name)
	cf.set_value("run", "difficulty", difficulty)
	cf.set_value("run", "played", int(Time.get_unix_time_from_system()))
	cf.set_value("run", "seed", run_seed)
	cf.set_value("run", "level", level_num)
	cf.set_value("run", "kills", kills)
	cf.set_value("run", "time", run_time)
	var saved := {}
	for k in RUN_KEYS:
		saved[k] = player[k]
	cf.set_value("run", "player", saved)
	cf.save(WORLD_PATH % world_slot)


func biome_index(n: int) -> int:
	return int((n - 1) / D.LEVELS_PER_BIOME) % D.BIOMES.size()


func _build_level() -> void:
	biome = D.BIOMES[biome_index(level_num)]
	var boss_level := level_num % D.LEVELS_PER_BIOME == 0
	lv = Level.new()
	var lrng := RandomNumberGenerator.new()
	lrng.seed = hash([run_seed, level_num])
	lv.build(level_num, biome, lrng, boss_level and state != State.TITLE)
	if player.is_empty():
		player = Hero.create()
	Hero.place(player, lv.start)
	checkpoint = lv.start
	checkpoint_prop = {}
	for pr in lv.props:
		if pr.kind == "lantern" and pr.get("start", false):
			checkpoint_prop = pr
			checkpoint = pr.pos
	if _to_boss and lv.boss_level:
		var br: Dictionary = lv.path[-1]
		Hero.place(player, Vector2((br.x0 + 6) * D.TILE, (br.y0 + D.EDGE_FLOOR) * D.TILE))
	enemies.clear()
	for s in lv.spawns:
		enemies.append(Foes.create(s.kind, s.pos, level_num, rng, s.elite))
	if _zoo and state != State.TITLE:
		enemies.clear()
		var kinds := ["crawler", "hopper", "bat", "spitter", "knight", "shield", "wisp", "archer", "bomber"]
		for i in kinds.size():
			var side := -1.0 if lv.start.x > lv.pixel_size().x * 0.5 else 1.0
			var e := Foes.create(kinds[i], lv.start + Vector2(side * (50 + i * 40), -120), level_num, rng, i == 4)
			e.stun = 99.0
			enemies.append(e)
	props = lv.props
	pickups = lv.pickups
	projectiles.clear()
	hazards.clear()
	shards.clear()
	particles.clear()
	popups.clear()
	slashes.clear()
	ghosts.clear()
	boss = {}
	near = {}
	slowmo = 1.0
	hitstop = 0.0
	level_time = 0.0
	rooms_seen = 0
	fade = 1.0
	cam = Physics.center(player)
	_mark_rooms()
	world.on_level_built()
	if state != State.TITLE:
		audio.music(biome.id)
		audio.ambient(biome.id)


## Goes one level deeper. After the last biome's boss the biomes start over,
## with tougher enemies.
func _next_level() -> void:
	audio.play("door")
	var cycle := level_num % D.FINAL_LEVEL == 0
	level_num += 1
	_record_profile(cycle)
	_start_level_now()
	if cycle:
		toast(L("toast_cycle") % (level_num / D.FINAL_LEVEL + 1), Color(1.0, 0.85, 0.4))
		audio.play("victory", -4.0)


func _record_profile(won: bool) -> void:
	if _bot:
		return
	var pr: Dictionary = cfg.profile
	pr.best_level = maxi(pr.best_level, level_num)
	pr.best_xp = maxi(pr.get("best_xp", 1), player.get("xp_level", 1))
	pr.best_combo = maxi(pr.get("best_combo", 0), best_combo)
	if won:
		pr.wins += 1
	cfg.save_profile()


func on_player_died() -> void:
	slowmo = 0.35
	dying_t = 1.6
	audio.play("death")
	audio.music("")
	hit_combo = 0


## Brings the hero back at the last lantern after a fall.
func _respawn() -> void:
	var p := player
	var lost := int(ceil(p.shards * diff().toll))
	p.shards -= lost
	for ar in lv.arenas:
		if ar.state == "active":
			Props.reset_arena(self, ar)
	projectiles.clear()
	hazards.clear()
	Hero.place(p, checkpoint)
	p.hp = p.max_hp
	p.inv = 1.5
	p.blink = 1.5
	cam = Physics.center(p)
	fade = 1.0
	slowmo = 1.0
	audio.music(biome.id)
	toast(L("toast_fell") % lost if lost > 0 else L("toast_fell0"), Color(0.95, 0.75, 0.6))
	_record_profile(false)
	save_run()


## Experience from a kill; levels up as often as it fills the bar.
func gain_xp(amount: float, at: Vector2) -> void:
	var p := player
	var got := int(round(amount * diff().xp * (1.0 + minf(hit_combo, 30) * 0.02)))
	p.xp += got
	if cfg.get_v("damage_numbers"):
		popups.append({"pos": at + Vector2(0, 14), "text": "+%d %s" % [got, L("xp")], "color": Color(0.6, 0.85, 1.0), "life": 0.9,
			"big": false})
	var up := false
	while p.xp >= Hero.xp_need(p.xp_level):
		p.xp -= Hero.xp_need(p.xp_level)
		p.xp_level += 1
		up = true
		if Items.SLOT_LEVELS.has(p.xp_level):
			toast(L("toast_slot"), Color(0.75, 0.9, 1.0))
	if up:
		Hero.refresh(p)
		p.hp = p.max_hp
		p.heal_t = 0.4
		level_up_t = 2.6
		audio.play("victory", -6.0, 1.3)
		burst(Physics.center(p), ["+", "*", "·", "^"], Color(0.6, 0.85, 1.0), 30, 160.0, -90.0)
		toast(L("toast_level") % [p.xp_level, Hero.HP_PER_LEVEL, int(Hero.DMG_PER_LEVEL * 100.0)], Color(0.6, 0.85, 1.0))
		save_run()


## Damage of one normal enemy blow at the current depth.
func hit_damage() -> float:
	return 14.0 * (1.0 + 0.12 * (level_num - 1)) * diff().dmg


func combo_hit() -> void:
	hit_combo += 1
	combo_t = 1.8
	best_combo = maxi(best_combo, hit_combo)


func on_crit(at: Vector2) -> void:
	hitstop = maxf(hitstop, 0.1)
	slowmo = minf(slowmo, 0.6)
	shake_add(6.0)
	crit_flash = 0.12 if cfg.get_v("quality") != "low" else 0.0
	sfx("kill", -5.0, 1.7)
	for i in 14:
		var a := i * TAU / 14.0
		particles.append({"p": at, "v": Vector2(cos(a), sin(a)) * 240.0, "g": "*" if i % 2 == 0 else "+",
			"c": Color(1.0, 0.85, 0.35), "life": 0.35, "max": 0.35, "grav": 0.0, "drag": 5.0, "s": 1.1})


## Where the hero should head next: the way along the room path toward the
## exit door or the boss. Zero when there is nothing to point at.
func guide_target() -> Vector2:
	if lv == null or player.is_empty() or not boss.is_empty():
		return Vector2.ZERO
	var c := Physics.center(player)
	var ts := D.TILE
	var room = lv.room_at_tile(int(c.x / ts), int(c.y / ts))
	if room == null:
		return Vector2.ZERO
	var edge_y: float = (room.y0 + D.EDGE_FLOOR - 2) * ts
	var idx := lv.path.find(room)
	var target: Vector2
	if idx < 0:
		# a side room: back the way we came
		target = Vector2((room.x0 - 1 if room.l else room.x0 + D.ROOM_W + 1) * ts, edge_y)
	elif idx == lv.path.size() - 1:
		target = lv.door.get_center()
		if lv.boss_level and not lv.door_open:
			target = Vector2((room.x0 + D.ROOM_W * 0.5) * ts, edge_y)
	else:
		var nxt: Dictionary = lv.path[idx + 1]
		if nxt.gy > room.gy:
			target = Vector2((room.x0 + room.d + D.SHAFT_W * 0.5) * ts, (room.y0 + D.ROOM_H) * ts)
		else:
			target = Vector2((nxt.x0 + 2 if nxt.gx > room.gx else nxt.x0 + D.ROOM_W - 2) * ts, edge_y)
	return target


func boss_started() -> void:
	audio.music("boss")
	audio.play("roar")
	shake_add(6.0)


func on_boss_killed(e: Dictionary) -> void:
	lv.door_open = true
	slowmo = 0.4
	toast(L("toast_boss") % L("boss_" + e.kind), Color(1.0, 0.85, 0.4))
	var id: String = Items.BOSS_DROPS.get(e.kind, "")
	if id != "" and Items.give(player, id):
		Hero.refresh(player)
	if id != "":
		item_found(id, player.charms.has(id))
	for x in hazards.duplicate():
		hazards.erase(x)
	for pr in projectiles.duplicate():
		if pr.owner == "enemy":
			projectiles.erase(pr)
	audio.music(biome.id)
	boss = {}


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	ctl.note_event(event)
	if menu.capturing():
		menu.capture(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_F11 or (k == KEY_ENTER and event.alt_pressed):
			var fs := DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED
			set_setting("window", "windowed" if fs else "borderless")
			return
		if k == KEY_EQUAL or k == KEY_KP_ADD or k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			var step := 1 if (k == KEY_EQUAL or k == KEY_KP_ADD) else -1
			set_setting("zoom", clampi(int(cfg.get_v("zoom")) + step, 0, world.ZOOMS.size() - 1))
			return
	if menu.active():
		menu.handle(event)
		return
	if state == State.PLAY and not player.dead:
		if event.is_action_pressed("g_pause"):
			menu.open("pause")
		elif event.is_action_pressed("g_inventory"):
			menu.open("inventory")
		elif event.is_action_pressed("g_map"):
			menu.open("map")


func aiming_with_mouse() -> bool:
	return cfg.get_v("mouse_aim") and ctl.device == "mouse"


func aim_vector(p: Dictionary) -> Vector2:
	var m := world.screen_to_world(get_viewport().get_mouse_position())
	var d := m - Physics.center(p)
	return d.normalized() if d.length() > 1.0 else Vector2(p.facing, 0)


func _update_cursor() -> void:
	var hide: bool = state == State.PLAY and not menu.active() and aiming_with_mouse() and not player.dead
	var want := Input.MOUSE_MODE_HIDDEN if hide else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want


# ---------------------------------------------------------------- frame

func _physics_process(dt: float) -> void:
	ctl.poll(dt)
	if _bot and state == State.PLAY:
		_bot_input()
	ctl.latch()
	_debug_capture(dt)
	if ui_check:
		_ui_check_step()
	_update_cursor()

	shake = move_toward(shake, 0.0, dt * 30.0)
	hurt_flash = move_toward(hurt_flash, 0.0, dt * 2.5)
	fade = move_toward(fade, 0.0, dt * 2.2)
	ink_flash = maxf(0.0, ink_flash - dt)
	crit_flash = maxf(0.0, crit_flash - dt)
	level_up_t = maxf(0.0, level_up_t - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		hit_combo = 0
	_streak_t -= dt
	if _streak_t <= 0.0:
		shard_streak = 0
		_streak_t = 0.6
	for t in toasts.duplicate():
		t.t -= dt
		if t.t <= 0.0:
			toasts.erase(t)
	audio.duck(1.0 if menu.active() and state == State.PLAY else 0.0)

	match state:
		State.TITLE:
			Combat.update_particles(self, dt)
		State.PLAY:
			if menu.active():
				return
			if hitstop > 0.0:
				hitstop -= dt
				return
			_step_play(dt)


func _step_play(dt: float) -> void:
	slowmo = move_toward(slowmo, 1.0, dt * 0.8) if not player.dead else slowmo
	var sdt := dt * slowmo
	run_time += dt
	level_time += dt
	Hero.update(self, player, sdt)
	for e in enemies.duplicate():
		if enemies.has(e):
			Foes.update(self, e, sdt)
	Combat.update_projectiles(self, sdt)
	Combat.update_hazards(self, sdt)
	Combat.update_shards(self, sdt)
	Combat.update_pickups(self)
	Combat.check_contacts(self)
	Props.update_arenas(self)
	Props.update_lanterns(self)
	near = Props.nearest(self)
	if not near.is_empty() and (ctl.just.interact or (ctl.just.up and not ctl.held.attack and near.kind != "sign")):
		Props.interact(self, near)
	Combat.update_particles(self, sdt)
	_update_effects(sdt)
	_update_camera(dt)
	_mark_rooms()
	hint = Hints.update(self, dt)
	if player.dead:
		dying_t -= dt
		if dying_t <= 0.0:
			_respawn()
	elif lv.door_open and lv.door.has_point(Physics.center(player)):
		_next_level()


func _mark_rooms() -> void:
	var c := Physics.center(player)
	var r = lv.room_at_tile(int(c.x / D.TILE), int(c.y / D.TILE))
	if r != null and not r.seen:
		r.seen = true
		rooms_seen += 1


func _update_camera(dt: float) -> void:
	var c := Physics.center(player)
	look = move_toward(look, player.facing * 40.0, 140.0 * dt)
	var target := c + Vector2(look, -12.0)
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


func _debug_capture(dt: float) -> void:
	if _record_dir != "" and state == State.PLAY:
		_record_frame += 1
		if _record_frame % 3 == 0:
			get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [_record_dir, _record_frame / 3])
	if _shot_path != "":
		_shot_time -= dt
		if _shot_time <= 0.0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			var avg := 0.0
			var mx := 0.0
			for d in _dts:
				avg += d / _dts.size()
				mx = maxf(mx, d)
			print("avg=%.1fms max=%.1fms" % [avg * 1000.0, mx * 1000.0])
			print("prims=%d" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			print("draws=%d fps=%d menu=%s state=%d level=%d hp=%d kills=%d shards=%d x=%.0f/%.0f" % [
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second(),
				str(menu.stack), state, level_num, player.get("hp", 0), kills, player.get("shards", 0),
				player.get("pos", Vector2.ZERO).x, lv.pixel_size().x])
			get_tree().quit()
			_shot_path = ""


func ui_issue(where: String, text: String) -> void:
	var k := "[%s] %s: %s" % [lang, where, text]
	if not _ui_issues.has(k):
		_ui_issues[k] = true
		print("UI OVERFLOW ", k)


func _ui_check_step() -> void:
	if _ui_steps.is_empty() and _ui_wait == 0:
		for l in T.LANGS:
			for m in ["", "new_world", "worlds", "world", "confirm_delete"]:
				_ui_steps.append([l, "title", m, 0])
			for m in ["", "pause", "inventory", "shop", "map", "moves"]:
				_ui_steps.append([l, "play", m, 0])
			for k in 4:
				_ui_steps.append([l, "play", "settings", k])
			for key in T.STRINGS:
				if key.begins_with("hint_"):
					_ui_steps.append([l, "hint", key.substr(5), 0])
		_ui_steps.append(["", "done", "", 0])
		_ui_wait = 1
	_ui_wait -= 1
	if _ui_wait > 0:
		return
	_ui_wait = 3
	var s: Array = _ui_steps.pop_front()
	if s[1] == "done":
		print("UI CHECK DONE: %d issues" % _ui_issues.size())
		get_tree().quit()
		return
	if s[0] != lang:
		cfg.values.lang = s[0]
		apply_settings()
	if s[1] == "title" and state != State.TITLE:
		show_title()
	elif s[1] != "title" and state != State.PLAY:
		new_run()
		player.xp_level = 20
		player.bag = Items.ITEMS.keys().filter(func(id: String) -> bool: return id != player.weapon)
		Hero.refresh(player)
		shop_prop = {"stock": ["glyph_saber", "phantom_step", "lucky_coin"]}
	menu.close_all()
	if s[1] == "title":
		menu.open("title")
	hint = s[2] if s[1] == "hint" else ""
	if s[1] != "hint" and s[2] != "":
		menu._world = worlds()[0]
		if s[2] == "world" or s[2] == "confirm_delete":
			menu.open("worlds")
			if s[2] == "confirm_delete":
				menu.open("world")
		debug_tab = s[3]
		menu.open(s[2])


# ---------------------------------------------------------------- API for other scripts

func sfx(name: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.06) -> void:
	audio.play(name, vol_db, pitch, vary)


func shake_add(amount: float) -> void:
	shake = maxf(shake, amount * float(cfg.get_v("shake")))


func burst(at: Vector2, glyphs: Array, color: Color, count: int, speed: float, lift: float = 0.0) -> void:
	Combat.burst(self, at, glyphs, color, count, speed, lift)


func attack_hits(p: Dictionary, box: Rect2) -> void:
	Combat.attack_hits(self, p, box)


func hurt_enemy(e: Dictionary, dmg: float, kdir: Vector2, _melee: bool = false) -> void:
	Combat.hurt_enemy(self, e, dmg, kdir, false)


func hurt_player(dmg: float, src_x: float, spikes: bool = false) -> void:
	Combat.hurt_player(self, dmg, src_x, spikes)


func fire(from: Vector2, vel: Vector2, owner: String = "enemy", dmg: float = 1.0, grav: float = 0.0,
		kind: String = "shot", delay: float = 0.0) -> void:
	Combat.fire(self, from, vel, owner, dmg, grav, kind, delay)


func explode(at: Vector2, radius: float, hurts_player: bool) -> void:
	Combat.explode(self, at, radius, hurts_player)


func add_pillar(x: float, floor_y: float) -> void:
	Combat.add_pillar(self, x, floor_y)


func remove_enemy(e: Dictionary) -> void:
	enemies.erase(e)


func spawn_enemy(kind: String, at: Vector2) -> void:
	var size: Vector2 = D.ENEMIES[kind].size
	var e := Foes.create(kind, at + Vector2(0, size.y * 0.5), level_num, rng)
	e.aggro = true
	enemies.append(e)
	burst(at, ["*", "+", "·"], Color(0.8, 0.9, 1.0), 12, 120.0)


func add_slash(kind: String, combo: int, facing: int, reach: float = 1.0) -> void:
	slashes.append({"kind": kind, "combo": combo, "facing": facing, "t": 0.0, "reach": reach})


func add_ghost(p: Dictionary) -> void:
	ghosts.append({"foot": Physics.foot(p), "facing": p.facing, "frame": Hero.frame(p), "life": 0.22})


func flash_ink() -> void:
	ink_flash = 0.5


func toast(text: String, color: Color = Color(0.92, 0.92, 0.88)) -> void:
	toasts.append({"text": text, "color": color, "t": 3.5})


func item_found(id: String, equipped: bool) -> void:
	items_found += 1
	var name := L("item_" + id)
	toast(L("toast_found") % name, Items.def(id).color)
	if not equipped:
		toast(L("toast_to_bag") % ctl.label("inventory", mouse_names()), Color(0.7, 0.75, 0.72))


func open_shop(pr: Dictionary) -> void:
	shop_prop = pr
	menu.open("shop")


func read_sign(pr: Dictionary) -> void:
	sign_text = L(pr.text)
	menu.open("sign")


func mouse_names() -> Array:
	return [L("mouse_left"), L("mouse_right"), L("mouse_middle"), L("wheel_up"), L("wheel_down")]


## Shows an action's binding as a key cap, e.g. "[Space]".
func key(action: String) -> String:
	return "[" + ctl.label(action, mouse_names()) + "]"


# ---------------------------------------------------------------- test bot

## Simple scripted player used for automated testing and screenshots: follows
## the room path, jumps over walls and gaps, drops down shafts, fights.
func _bot_input() -> void:
	_bot_t += get_physics_process_delta_time()
	var p := player
	var held: Dictionary = ctl.held
	for a in ctl.ACTIONS:
		held[a] = false
	var c := Physics.center(p)
	var ts := D.TILE
	var room = lv.room_at_tile(int(c.x / ts), int(c.y / ts))
	var target_x := lv.door.get_center().x
	var to_shaft := false
	if room != null:
		var idx := lv.path.find(room)
		if idx >= 0 and idx < lv.path.size() - 1:
			var nxt: Dictionary = lv.path[idx + 1]
			if nxt.gy > room.gy:
				target_x = (room.x0 + room.d + D.SHAFT_W * 0.5) * ts
				to_shaft = true
			else:
				target_x = (nxt.x0 + D.ROOM_W * 0.5) * ts
		elif idx < 0:
			target_x = (room.x0 + (-4 if room.l else D.ROOM_W + 4)) * ts
		if not boss.is_empty():
			target_x = Physics.center(boss).x
	var dir := signf(target_x - c.x)
	if absf(target_x - c.x) < 6.0:
		dir = 0.0
	held.right = dir > 0.0
	held.left = dir < 0.0
	var ahead := int(floor((c.x + dir * 20.0) / ts))
	var feet := int(floor((p.pos.y + p.size.y + 2.0) / ts))
	var wall := lv.solid(ahead, int(floor(c.y / ts))) or lv.solid(ahead, int(floor((p.pos.y + p.size.y - 4.0) / ts)))
	var below := lv.at(ahead, feet)
	var gap := below != Level.SOLID and below != Level.ONEWAY and absf(target_x - c.x) > 40.0 and not to_shaft
	held.jump = (p.on_floor and (wall or gap) and dir != 0.0) or (not p.on_floor and p.vel.y < 0.0 and ctl._prev.jump)
	held.jump = held.jump or (p.swim and fmod(_bot_t, 0.4) < 0.1) or (p.sliding)
	for e in enemies:
		var d: Vector2 = Physics.center(e) - c
		if absf(d.x) < 50.0 and absf(d.y) < 50.0:
			held.attack = not ctl._prev.attack
			held.up = d.y < -24.0
			held.down = d.y > 24.0 and not p.on_floor
			break
	held.dash = fmod(_bot_t, 2.3) < 0.02
	held.interact = not near.is_empty() and near.kind == "chest" and fmod(_bot_t, 0.5) < 0.05
