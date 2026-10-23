## Menus drawn with glyphs: title, pause, settings (game, video, audio,
## controls with rebinding; every option has a short explanation), inventory,
## merchant, map, moves and sign.
## Every screen works with the keyboard, the mouse (hover, click, wheel) and a
## gamepad. Items are rebuilt every frame from the game state.
extends Node2D

const D := preload("res://scripts/data.gd")
const T := preload("res://scripts/strings.gd")
const Items := preload("res://scripts/items.gd")
const Hero := preload("res://scripts/hero.gd")
const Physics := preload("res://scripts/physics.gd")
const Settings := preload("res://scripts/settings.gd")
const Controls := preload("res://scripts/controls.gd")
const S := preload("res://scripts/sprites.gd")
const Hud := preload("res://scripts/hud.gd")
const Skills := preload("res://scripts/skills.gd")
const SkillTree := preload("res://scripts/skilltree.gd")
const Inventory := preload("res://scripts/inventory.gd")
const IconArt := preload("res://scripts/icon_art.gd")

const LOGO := [
	"  ▄████  ██▓   ▓██   ██▓ ██▓███   ██░ ██  █     █░ ▒█████   ▒█████  ▓█████▄",
	" ██▒ ▀█▒▓██▒    ▒██  ██▒▓██░  ██▒▓██░ ██▒▓█░ █ ░█░▒██▒  ██▒▒██▒  ██▒▒██▀ ██▌",
	"▒██░▄▄▄░▒██░     ▒██ ██░▓██░ ██▓▒▒██▀▀██░▒█░ █ ░█ ▒██░  ██▒▒██░  ██▒░██   █▌",
	"░▓█  ██▓▒██░     ░ ▐██▓░▒██▄█▓▒ ▒░▓█ ░██ ░█░ █ ░█ ▒██   ██░▒██   ██░░▓█▄   ▌",
	"░▒▓███▀▒░██████▒ ░ ██▒▓░▒██▒ ░  ░░▓█▒░██▓░░██▒██▓ ░ ████▓▒░░ ████▓▒░░▒████▓",
	" ░▒   ▒ ░ ▒░▓  ░  ██▒▒▒ ▒▓▒░ ░  ░ ▒ ░░▒░▒░ ▓░▒ ▒  ░ ▒░▒░▒░ ░ ▒░▒░▒░  ▒▒▓  ▒",
	"  ░   ░ ░ ░ ▒  ░▓██ ░▒░ ░▒ ░      ▒ ░▒░ ░  ▒ ░ ░    ░ ▒ ▒░   ░ ▒ ▒░  ░ ▒  ▒",
	"░ ░   ░   ░ ░   ▒ ▒ ░░  ░░        ░  ░░ ░  ░   ░  ░ ░ ░ ▒  ░ ░ ░ ▒   ░ ░  ░",
	"      ░     ░  ░░ ░               ░  ░  ░    ░        ░ ░      ░ ░     ░",
	"                ░ ░                                                  ░",
]
const TABS := ["tab_game", "tab_video", "tab_audio", "tab_controls"]

var game
var font: Font
var bold: Font
var stack: Array = []
var sel := 0
var col := 0
var tab := 0
var items: Array = []
var t := 0.0
var u := 1.0
var _capture := {}
var _msg := ""
var _msg_t := 0.0
var _mouse := Vector2.ZERO
var _map_ci: Node2D
var _map_rect := Rect2()
## The world being created on the "new_world" screen, and the one picked in "worlds".
var _nw := {"name": "", "difficulty": "normal", "seed": 0}
## True while keys type into the new world's name.
var _typing := false
const NAME_MAX := 20
var _world := {}
## The panel text has to stay inside (checked with --uicheck).
var _bounds := Rect2()
## Holding ←/→ on a number speeds up after a moment; Shift moves 10 at a time.
var _adj_last := 0
var _adj_n := 0
var _dragging := false


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b
	_map_ci = Node2D.new()
	_map_ci.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_ci.draw.connect(_draw_map_content)
	add_child(_map_ci)


func open(name: String) -> void:
	stack.append(name)
	sel = 0
	col = 0
	if name == "settings":
		tab = game.debug_tab
	if name != "title" and name != "dead":
		game.sfx("menu_ok", -4.0)


func close() -> void:
	if not stack.is_empty():
		stack.pop_back()
	sel = 0
	col = 0
	_capture = {}
	_typing = false
	game.ctl.swallow()
	game.sfx("menu_back", -4.0)


func close_all() -> void:
	stack.clear()
	game.ctl.swallow()
	_capture = {}
	_typing = false
	sel = 0


func active() -> bool:
	return not stack.is_empty()


func is_open(name: String) -> bool:
	return stack.has(name)


func top() -> String:
	return stack[-1] if not stack.is_empty() else ""


func capturing() -> bool:
	return not _capture.is_empty() or _typing


func _process(delta: float) -> void:
	t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	visible = active()
	if active():
		items = _build(top())
		sel = clampi(sel, 0, maxi(0, items.size() - 1))
		if not items.is_empty() and not _selectable(items[sel]):
			_move(1, false)
	queue_redraw()
	_map_ci.queue_redraw()


func _message(text: String) -> void:
	_msg = text
	_msg_t = 2.5


# ---------------------------------------------------------------- content

func _btn(label: String, act: Callable, extra: Dictionary = {}) -> Dictionary:
	var d := {"type": "button", "label": label, "act": act}
	d.merge(extra)
	return d


## Every setting has an explanation under "tip_<label>" shown while it is selected.
func _tip(label: String) -> String:
	return game.L("tip_" + label.substr(2))


func _toggle(label: String, key: String) -> Dictionary:
	var v: bool = game.cfg.get_v(key)
	var flip := func(_dir: int = 0) -> void: game.set_setting(key, not game.cfg.get_v(key))
	return {"type": "value", "label": game.L(label), "value": game.L("on" if v else "off"), "act": flip, "adj": flip, "tip": _tip(label)}


func _choice(label: String, value: String, adj: Callable) -> Dictionary:
	return {"type": "value", "label": game.L(label), "value": value, "act": adj.bind(1), "adj": adj, "tip": _tip(label)}


func _slider(label: String, key: String, lo: float, hi: float, step: float) -> Dictionary:
	var v: float = game.cfg.get_v(key)
	var adj := func(dir: int) -> void: game.set_setting(key, clampf(snappedf(game.cfg.get_v(key) + dir * step, step), lo, hi))
	var setf := func(f: float) -> void: game.set_setting(key, clampf(snappedf(lerpf(lo, hi, f), step), lo, hi))
	return {"type": "slider", "label": game.L(label), "frac": (v - lo) / (hi - lo), "value": "%d%%" % int(round(v * 100.0)),
		"act": adj.bind(1), "adj": adj, "setf": setf, "tip": _tip(label)}


## Frames-per-second limit, one by one from FPS_MIN to FPS_MAX, then "no limit".
func _fps_slider() -> Dictionary:
	var lo := Settings.FPS_MIN
	var hi := Settings.FPS_MAX + 1
	var v: int = game.cfg.get_v("fps")
	var pos := hi if v == 0 else clampi(v, lo, Settings.FPS_MAX)
	var put := func(n: int) -> void: game.set_setting("fps", 0 if n >= hi else clampi(n, lo, Settings.FPS_MAX))
	var adj := func(dir: int) -> void: put.call(clampi(pos + dir, lo, hi))
	var setf := func(f: float) -> void: put.call(int(round(lerpf(lo, hi, f))))
	return {"type": "slider", "label": game.L("s_fps"), "frac": float(pos - lo) / (hi - lo), "value": game.L("fps_0") if v == 0 else str(v),
		"act": adj.bind(1), "adj": adj, "setf": setf, "tip": _tip("s_fps") + " " + game.L("tip_fps_vsync")}


## How many steps one press moves a number: more while the key is held, 10 with Shift.
func _accel() -> int:
	var now := Time.get_ticks_msec()
	_adj_n = _adj_n + 1 if now - _adj_last < 200 else 0
	_adj_last = now
	if Input.is_key_pressed(KEY_SHIFT):
		return 10
	return 1 if _adj_n < 10 else (3 if _adj_n < 30 else 6)


## Bound as _cycle.bind(key, choices); Callable.bind appends, so dir comes first.
func _cycle(dir: int, key: String, choices: Array) -> void:
	var i := choices.find(game.cfg.get_v(key))
	game.set_setting(key, choices[posmod(i + dir, choices.size())])


func _build(name: String) -> Array:
	var out: Array = []
	match name:
		"title":
			var ws: Array = game.worlds()
			if not ws.is_empty():
				out.append(_btn(game.L("m_continue"), game.continue_run, {"note": ws[0].name}))
				out.append(_btn(game.L("m_worlds"), open.bind("worlds")))
			out.append(_btn(game.L("m_new_world"), _new_world))
			out.append(_btn(game.L("m_settings"), open.bind("settings")))
			if not OS.has_feature("web"):
				out.append(_btn(game.L("m_quit"), get_tree().quit))
		"pause":
			out.append(_btn(game.L("m_resume"), close))
			out.append(_btn(game.L("m_inventory"), open.bind("inventory")))
			out.append(_btn(game.L("m_map"), open.bind("map")))
			var pts := Skills.free_points(game.player)
			out.append(_btn(game.L("m_skills"), open.bind("skills"), {"note": game.L("sk_points") % pts} if pts > 0 else {}))
			out.append(_btn(game.L("m_moves"), open.bind("moves")))
			out.append(_btn(game.L("m_settings"), open.bind("settings")))
			out.append(_btn(game.L("m_quit_title"), game.show_title))
		"settings":
			out.append({"type": "tabs"})
			out.append_array(_settings_tab())
			out.append(_btn(game.L("m_back"), close))
		"new_world":
			out.append({"type": "text", "label": game.L("s_world_name"), "value": _nw.name, "tip": game.L("tip_world_name"),
				"act": _start_typing})
			out.append({"type": "value", "label": game.L("s_difficulty"), "value": game.L("diff_" + _nw.difficulty),
				"tip": game.L("diffd_" + _nw.difficulty), "act": _cycle_diff.bind(1), "adj": _cycle_diff})
			out.append(_btn(game.L("m_create"), _create_world))
			out.append(_btn(game.L("m_back"), close))
		"worlds":
			for w in game.worlds():
				out.append({"type": "world", "w": w, "act": _pick_world.bind(w)})
			if game.free_world_slot() >= 0:
				out.append(_btn(game.L("m_new_world"), _new_world))
			out.append(_btn(game.L("m_back"), close))
		"world":
			out.append(_btn(game.L("m_play"), game.play_world.bind(_world.get("slot", 0))))
			out.append(_btn(game.L("m_delete"), open.bind("confirm_delete")))
			out.append(_btn(game.L("m_back"), close))
		"confirm_delete":
			out.append(_btn(game.L("m_yes"), _delete_world))
			out.append(_btn(game.L("m_no"), close))
		"sign", "map", "moves":
			out.append(_btn(game.L("m_ok") if name == "sign" else game.L("m_back"), close))
		"inventory":
			out = Inventory.items(self)
		"shop":
			out = _shop_items()
		"sell":
			out = _sell_items()
		"skills":
			out = SkillTree.items(self)
	return out


func _new_world() -> void:
	if game.free_world_slot() < 0:
		game.sfx("error", -6.0)
		_message(game.L("worlds_full"))
		return
	_nw = {"name": "", "difficulty": "normal", "seed": randi()}
	open("new_world")
	_typing = true


func _start_typing() -> void:
	_typing = true
	game.sfx("menu_ok", -6.0)


func _create_world() -> void:
	var n: String = _nw.name.strip_edges()
	if n == "":
		game.sfx("error", -6.0)
		_message(game.L("world_name_empty"))
		sel = 0
		_typing = true
		return
	_typing = false
	game.create_world(n, _nw.difficulty, _nw.seed)


## Keys typed into the world name: letters are added, Backspace removes one,
## Enter, Tab, Esc or a click elsewhere finish. Returns true when the event was used.
func _type(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		_typing = false
		return false
	if not (event is InputEventKey and event.pressed):
		return event is InputEventKey
	var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if k in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB, KEY_UP, KEY_DOWN]:
		_typing = false
		if k != KEY_ESCAPE:
			_move(1)
		return true
	if k == KEY_BACKSPACE:
		if _nw.name != "":
			_nw.name = _nw.name.left(-1)
			game.sfx("menu_move", -14.0)
		return true
	var ch: int = event.unicode
	if ch >= 32 and ch != 127 and _nw.name.length() < NAME_MAX:
		_nw.name += String.chr(ch)
		game.sfx("menu_move", -14.0)
	return true


func _cycle_diff(dir: int) -> void:
	var ds: Array = game.DIFFICULTIES
	_nw.difficulty = ds[posmod(ds.find(_nw.difficulty) + dir, ds.size())]


func _pick_world(w: Dictionary) -> void:
	_world = w
	open("world")


func _delete_world() -> void:
	game.delete_world(_world.slot)
	close()
	close()
	if game.worlds().is_empty():
		close()


func _settings_tab() -> Array:
	var out: Array = []
	var cfg = game.cfg
	match tab:
		0:
			out.append(_choice("s_lang", T.LANG_NAMES[game.lang_idx], func(dir: int) -> void:
				game.set_setting("lang", T.LANGS[posmod(game.lang_idx + dir, T.LANGS.size())])))
			out.append(_toggle("s_hints", "hints"))
			out.append(_btn(game.L("m_reset_hints"), func() -> void:
				cfg.reset_hints()
				_message(game.L("hints_reset_done")), {"small": true, "tip": game.L("tip_reset_hints")}))
			out.append(_toggle("s_guide", "guide"))
			out.append(_toggle("s_damage_numbers", "damage_numbers"))
			out.append(_slider("s_shake", "shake", 0.0, 1.0, 0.01))
			out.append(_toggle("s_mouse_aim", "mouse_aim"))
		1:
			out.append(_choice("s_quality", game.L("q_" + cfg.get_v("quality")), _cycle.bind("quality", Settings.QUALITY_CHOICES)))
			var modes: Array = Settings.WINDOW_CHOICES if not OS.has_feature("web") else ["windowed", "borderless"]
			out.append(_choice("s_window", game.L("w_" + cfg.get_v("window")), _cycle.bind("window", modes)))
			out.append(_toggle("s_vsync", "vsync"))
			out.append(_fps_slider())
			out.append(_choice("s_zoom", game.L("zoom_%d" % cfg.get_v("zoom")), _cycle.bind("zoom", [0, 1, 2])))
			out.append(_toggle("s_lighting", "lighting"))
			out.append(_toggle("s_glow", "glow"))
			out.append(_toggle("s_scanlines", "scanlines"))
			out.append(_toggle("s_vignette", "vignette"))
			out.append(_slider("s_ui_scale", "ui_scale", 0.8, 1.3, 0.01))
			out.append(_toggle("s_show_fps", "show_fps"))
		2:
			out.append(_slider("s_master", "vol_master", 0.0, 1.0, 0.01))
			out.append(_slider("s_music", "vol_music", 0.0, 1.0, 0.01))
			out.append(_slider("s_sfx", "vol_sfx", 0.0, 1.0, 0.01))
			out.append(_slider("s_amb", "vol_amb", 0.0, 1.0, 0.01))
			out.append(_toggle("s_mute_unfocused", "mute_unfocused"))
		3:
			for a in Controls.ACTIONS:
				out.append({"type": "bind", "label": game.L("a_" + a), "action": a, "tip": game.L("tip_bind")})
			out.append(_btn(game.L("m_reset"), func() -> void:
				game.ctl.reset()
				game.cfg.set_v("binds", {}), {"small": true, "tip": game.L("tip_reset_binds")}))
	return out


func _shop_items() -> Array:
	var pr: Dictionary = game.shop_prop
	var p: Dictionary = game.player
	var out: Array = []
	for id in pr.get("stock", []):
		out.append({"type": "buy", "id": id, "price": Items.def(id).price, "act": _buy.bind(id)})
	var lvl: int = game.level_num
	out.append({"type": "buy", "id": "mend", "price": Items.service_price(p, "mend", lvl), "act": _buy.bind("mend"),
		"label": game.L("shop_mend"), "color": Color(0.5, 1.0, 0.6), "note": "%d / %d" % [p.hp, p.max_hp]})
	out.append({"type": "buy", "id": "vigor", "price": Items.service_price(p, "vigor", lvl), "act": _buy.bind("vigor"),
		"label": game.L("shop_vigor"), "color": Color(1.0, 0.35, 0.45), "note": game.L("shop_vigor_d") % p.up_hp})
	out.append({"type": "buy", "id": "whet", "price": Items.service_price(p, "whet", lvl), "act": _buy.bind("whet"),
		"label": game.L("shop_whet"), "color": Color(0.8, 0.85, 0.95), "note": game.L("shop_whet_d") % p.up_dmg})
	if p.up_spd < Items.HASTE_MAX:
		out.append({"type": "buy", "id": "haste", "price": Items.service_price(p, "haste", lvl), "act": _buy.bind("haste"),
			"label": game.L("shop_haste"), "color": Color(0.6, 0.9, 1.0), "note": game.L("shop_haste_d") % (p.up_spd * 5)})
	if Skills.spent(p) > 0:
		out.append({"type": "buy", "id": "forget", "price": Items.service_price(p, "forget", lvl), "act": _buy.bind("forget"),
			"label": game.L("shop_forget"), "color": Color(0.75, 0.6, 0.95), "note": game.L("shop_forget_d")})
	if not p.bag.is_empty():
		out.append(_btn(game.L("shop_sell"), open.bind("sell"), {"note": str(p.bag.size())}))
	out.append(_btn(game.L("m_leave"), close))
	return out


func _sell_items() -> Array:
	var out: Array = []
	for id in game.player.bag:
		out.append({"type": "buy", "id": id, "price": Items.sell_price(id), "act": _sell.bind(id), "sell": true})
	out.append(_btn(game.L("m_back"), close))
	return out


func _sell(id: String) -> void:
	var paid := Items.sell(game.player, id)
	if paid > 0:
		game.sfx("shard", 0.0, 0.8)
		game.sfx("buy", -6.0, 0.8)
		_message(game.L("shop_sold") % [_item_name(id), paid])


func _buy(id: String) -> void:
	var p: Dictionary = game.player
	var service: bool = id in ["mend", "vigor", "whet", "haste", "forget"]
	var price: int = Items.service_price(p, id, game.level_num) if service else Items.def(id).price
	if id == "mend" and p.hp >= p.max_hp:
		game.sfx("error", -6.0)
		_message(game.L("shop_full"))
		return
	if p.shards < price:
		game.sfx("error", -6.0)
		_message(game.L("shop_poor"))
		return
	p.shards -= price
	game.sfx("buy")
	match id:
		"mend":
			p.hp = p.max_hp
		"vigor":
			p.up_hp += 1
			Hero.refresh(p)
			p.hp = mini(p.max_hp, p.hp + 10)
		"whet":
			p.up_dmg += 1
			Hero.refresh(p)
		"haste":
			p.up_spd += 1
			Hero.refresh(p)
		"forget":
			Skills.forget_all(p)
			Hero.refresh(p)
			_message(game.L("shop_forgot"))
		_:
			game.shop_prop.stock.erase(id)
			var equipped := Items.give(p, id)
			Hero.refresh(p)
			game.item_found(id, equipped)


# ---------------------------------------------------------------- input

func _selectable(it: Dictionary) -> bool:
	return it.type != "slot" and it.type != "label"


func _move(dir: int, sound: bool = true) -> void:
	if items.is_empty():
		return
	for k in items.size():
		sel = posmod(sel + dir, items.size())
		if _selectable(items[sel]):
			break
	col = 0
	if sound:
		game.sfx("menu_move", -10.0)


func _activate() -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[sel]
	match it.type:
		"tabs":
			tab = posmod(tab + 1, TABS.size())
			game.sfx("menu_move", -8.0)
		"bind":
			_capture = {"action": it.action, "slot": col}
			game.sfx("menu_ok", -6.0)
		_:
			if it.has("act"):
				if it.type == "button":
					game.sfx("menu_ok", -6.0)
				it.act.call()


func _adjust(dir: int) -> void:
	if items.is_empty():
		return
	var it: Dictionary = items[sel]
	match it.type:
		"tabs":
			tab = posmod(tab + dir, TABS.size())
			game.sfx("menu_move", -8.0)
		"bind":
			col = clampi(col + dir, 0, 1)
			game.sfx("menu_move", -10.0)
		"value":
			it.adj.call(dir)
			game.sfx("menu_move", -8.0)
		"slider":
			it.adj.call(dir * _accel())
			game.sfx("menu_move", -12.0)


func _back() -> void:
	match top():
		"title":
			return
	close()


func handle(event: InputEvent) -> void:
	if event is InputEventMouse:
		_handle_mouse(event as InputEventMouse)
	elif event.is_pressed():
		_handle_button(event)


func _handle_mouse(event: InputEventMouse) -> void:
	_mouse = event.position
	# dragging a slider bar sets the value under the cursor
	if _dragging:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT) or sel >= items.size() or items[sel].type != "slider":
			_dragging = false
		elif event is InputEventMouseMotion and items[sel].has("bar"):
			var bar: Rect2 = items[sel].bar
			items[sel].setf.call(clampf((event.position.x - bar.position.x) / bar.size.x, 0.0, 1.0))
		return
	var i := _hover(event.position)
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if top() == "inventory" and i < 0 and Inventory.click(mb.position):
				return
			if (top() == "map" or top() == "moves") and i < 0:
				close()
			elif i >= 0:
				_click(items[i], mb.position)
		MOUSE_BUTTON_RIGHT:
			_back()
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var dir := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			if i >= 0 and items[i].type in ["slider", "value"]:
				_adjust(-dir)
			else:
				_move(dir)


func _click(it: Dictionary, pos: Vector2) -> void:
	if it.type == "slider" and it.has("bar") and it.bar.grow(8 * u).has_point(pos):
		it.setf.call(clampf((pos.x - it.bar.position.x) / it.bar.size.x, 0.0, 1.0))
		_dragging = true
		game.sfx("menu_move", -8.0)
	elif it.type == "value" and it.has("left") and it.has("adj"):
		_adjust(-1 if it.left.has_point(pos) else 1)
	elif it.type == "tabs":
		for k in it.tab_rects.size():
			if it.tab_rects[k].has_point(pos):
				tab = k
				game.sfx("menu_move", -8.0)
	else:
		_activate()


func _handle_button(event: InputEvent) -> void:
	var echo := event is InputEventKey and event.is_echo()
	var k := 0
	if event is InputEventKey:
		k = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var pad_back: bool = event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]
	if (k == KEY_ENTER or k == KEY_KP_ENTER) and not echo:
		_activate()
	elif ((k == KEY_ESCAPE or k == KEY_BACKSPACE) and not echo) or pad_back:
		_back()
	elif (top() == "inventory" and event.is_action_pressed("g_inventory")) or (top() == "map" and event.is_action_pressed("g_map")) \
			or (top() == "skills" and event.is_action_pressed("g_skills")):
		close()
	elif top() == "skills" and sel < items.size() and items[sel].type == "skill" and _dir_pressed(event) != Vector2.ZERO:
		SkillTree.step(self, _dir_pressed(event))
	elif top() == "inventory" and _dir_pressed(event) != Vector2.ZERO:
		SkillTree.step(self, _dir_pressed(event))
	elif top() == "inventory" and event.is_action_pressed("g_swap") and not echo:
		Inventory.second(self)
	elif top() == "inventory" and event.is_action_pressed("g_throw") and not echo:
		Inventory.reforge(self)
	elif event.is_action_pressed("g_pause") and not echo:
		_back()
	elif event.is_action_pressed("g_up", true):
		_move(-1)
	elif event.is_action_pressed("g_down", true):
		_move(1)
	elif event.is_action_pressed("g_left", true):
		_adjust(-1)
	elif event.is_action_pressed("g_right", true):
		_adjust(1)
	elif (event.is_action_pressed("g_jump") or event.is_action_pressed("g_interact")) and not echo:
		_activate()


func _dir_pressed(event: InputEvent) -> Vector2:
	for a in [["g_up", Vector2.UP], ["g_down", Vector2.DOWN], ["g_left", Vector2.LEFT], ["g_right", Vector2.RIGHT]]:
		if event.is_action_pressed(a[0], true):
			return a[1]
	return Vector2.ZERO


## Selects the item under the mouse; returns its index or -1.
func _hover(pos: Vector2) -> int:
	for i in items.size():
		var it: Dictionary = items[i]
		if it.has("rect") and it.rect.has_point(pos) and _selectable(it):
			if sel != i:
				sel = i
				game.sfx("menu_move", -14.0)
			if it.type == "bind":
				col = 1 if it.slots[1].has_point(pos) else 0
			return i
	return -1


## Called from main._input while waiting for a new binding or typing a name;
## returns true when the event was used.
func capture(event: InputEvent) -> bool:
	if _typing:
		return _type(event)
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return true
	if event is InputEventKey and event.is_echo():
		return true
	var a: String = _capture.action
	var slot: int = _capture.slot
	if event is InputEventKey:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_ESCAPE:
			_capture = {}
			game.sfx("menu_back", -6.0)
			return true
		if k == KEY_BACKSPACE or k == KEY_DELETE:
			game.ctl.rebind(a, slot, "")
			_finish_capture()
			return true
	var b := Controls.encode(event)
	if b != "":
		game.ctl.rebind(a, slot, b)
		_finish_capture()
	return true


func _finish_capture() -> void:
	_capture = {}
	game.cfg.set_v("binds", game.ctl.binds.duplicate(true))
	game.sfx("menu_ok", -4.0)


# ---------------------------------------------------------------- drawing

func _text(pos: Vector2, text: String, size: int, color: Color, f: Font = null) -> float:
	var fnt := f if f != null else font
	size = maxi(size, 4)
	draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if game.ui_check:
		_check(Rect2(pos.x, pos.y - size * 0.75, w, size * 0.95), text)
	return w


func _w(text: String, size: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 4)).x


## Reports text that leaves its panel or the window (debug --uicheck).
func _check(r: Rect2, text: String) -> void:
	var vp := get_viewport_rect()
	var box := _bounds if _bounds.has_area() else vp
	if not box.grow(1.0).encloses(r) or not vp.encloses(r):
		game.ui_issue("menu %s/%d" % [top(), tab], text)


## The largest size up to [size] (down to 65%) at which [text] fits in [max_w].
func _fit(text: String, size: int, max_w: float, f: Font = null) -> int:
	var s := size
	while s > int(size * 0.65) and _w(text, s, f) > max_w:
		s -= 1
	return s


## Draws [text] shrunk to fit [max_w], cut with "…" if even that is not enough.
func _text_fit(pos: Vector2, text: String, size: int, max_w: float, color: Color, f: Font = null) -> float:
	var s := _fit(text, size, max_w, f)
	var txt := text
	if _w(txt, s, f) > max_w:
		while txt.length() > 1 and _w(txt + "…", s, f) > max_w:
			txt = txt.substr(0, txt.length() - 1)
		txt += "…"
	return _text(pos, txt, s, color, f)


## Wrapped text; [pos] is the first baseline. Returns the height.
func _para(pos: Vector2, text: String, w: float, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, f: Font = null) -> float:
	var fnt := f if f != null else font
	draw_multiline_string(fnt, pos, text, align, w, size, -1, color)
	var sz := fnt.get_multiline_string_size(text, align, w, size)
	if game.ui_check:
		_check(Rect2(pos.x, pos.y - size * 0.75, minf(sz.x, w), sz.y - size * 0.25), text)
	return sz.y


func _para_h(text: String, w: float, size: int, f: Font = null) -> float:
	return (f if f != null else font).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, size).y


func _center(y: float, text: String, size: int, color: Color, f: Font = null) -> void:
	var vw := get_viewport_rect().size.x
	var max_w := (_bounds.size.x if _bounds.has_area() else vw) - 40 * u
	size = _fit(text, size, max_w, f)
	_text(Vector2((vw - _w(text, size, f)) * 0.5, y), text, size, color, f)


## A panel in a wrought-iron frame: a double rim, a crown of fence spikes
## along the top, crosses on the corners and a faint glow of the accent
## colour seeping down from the top.
func _panel(r: Rect2, accent: Color) -> void:
	_bounds = Rect2()
	draw_rect(r, Color(0.012, 0.01, 0.014, 0.93))
	for k in 8:
		draw_rect(Rect2(r.position.x, r.position.y + k * 6 * u, r.size.x, 6 * u), Color(accent.r, accent.g, accent.b, 0.05 * (1.0 - k / 8.0)))
	var iron := Color(0.4, 0.35, 0.33)
	var w := maxf(1.0, 1.4 * u)
	draw_rect(r, iron, false, w)
	draw_rect(r.grow(-5 * u), Color(accent.r, accent.g, accent.b, 0.3), false, maxf(1.0, u))
	var n := maxi(2, int(r.size.x / (26.0 * u)))
	for k in range(1, n):
		var x := r.position.x + r.size.x * k / n
		var h := (8.0 if k % 4 == 0 else 5.0) * u
		draw_colored_polygon(PackedVector2Array([Vector2(x - 2.4 * u, r.position.y), Vector2(x, r.position.y - h),
			Vector2(x + 2.4 * u, r.position.y)]), iron)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		_cross(corner, 7.0 * u, iron, Color(accent.r, accent.g, accent.b, 0.8))
	_bounds = r


## A small cross with a diamond at its heart.
func _cross(c: Vector2, size: float, col: Color, heart: Color) -> void:
	var w := maxf(1.0, 1.6 * u)
	draw_line(c - Vector2(0, size), c + Vector2(0, size * 1.3), col, w)
	draw_line(c - Vector2(size * 0.75, 0), c + Vector2(size * 0.75, 0), col, w)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2.5) * u, c + Vector2(2.5, 0) * u, c + Vector2(0, 2.5) * u,
		c + Vector2(-2.5, 0) * u]), heart)


## A menu heading between two thin iron lines that end in diamonds.
func _heading(y: float, text: String, size: int) -> void:
	_center(y, text, size, Color(0.95, 0.92, 0.86), bold)
	var vw := get_viewport_rect().size.x
	var tw := _w(text, _fit(text, size, (_bounds.size.x if _bounds.has_area() else vw) - 40 * u, bold), bold)
	var cy := y - size * 0.32
	var iron := Color(0.45, 0.38, 0.35)
	for side in [-1.0, 1.0]:
		var a: float = vw * 0.5 + side * (tw * 0.5 + 14 * u)
		var b: float = vw * 0.5 + side * (tw * 0.5 + 70 * u)
		draw_line(Vector2(a, cy), Vector2(b, cy), iron, maxf(1.0, u))
		draw_colored_polygon(PackedVector2Array([Vector2(b, cy - 3 * u), Vector2(b + side * 4 * u, cy), Vector2(b, cy + 3 * u),
			Vector2(b - side * 4 * u, cy)]), Color(0.6, 0.1, 0.1))


func _draw() -> void:
	if not active():
		return
	var vp := get_viewport_rect().size
	u = vp.y / 900.0 * float(game.cfg.get_v("ui_scale"))
	_bounds = Rect2()
	var name := top()
	var accent: Color = Color(0.8, 0.2, 0.2).lerp(game.biome.top, 0.2)
	if name != "title":
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55 if name != "dead" else 0.65))
	match name:
		"title":
			_draw_title(vp, accent)
		"pause":
			_draw_list(vp, game.L("paused"), accent, 360.0, _run_line())
		"new_world":
			_draw_list(vp, game.L("m_new_world"), accent, 640.0)
		"worlds":
			_draw_worlds(vp, accent)
		"world":
			_draw_list(vp, _world.get("name", ""), accent, 460.0, _world_line(_world))
		"confirm_delete":
			_draw_list(vp, game.L("m_delete"), accent, 560.0, game.L("confirm_delete") % _world.get("name", ""))
		"settings":
			_draw_settings(vp, accent)
		"moves":
			_draw_moves(vp, accent)
		"sign":
			_draw_sign(vp, accent)
		"inventory":
			Inventory.draw(self, vp, accent)
		"shop", "sell":
			_draw_shop(vp, accent)
		"skills":
			SkillTree.draw(self, vp, accent)
		"map":
			_draw_map(vp, accent)
	_bounds = Rect2()
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t * 2.0)
		_center(vp.y - 70 * u, _msg, int(16 * u), Color(1.0, 0.85, 0.5, a), bold)
	if name != "map":
		_center(vp.y - 22 * u, game.L("menu_hint"), int(12 * u), Color(0.5, 0.56, 0.54))
	_draw_tip(vp)


## The explanation of the selected option, in a box under the menu.
func _draw_tip(vp: Vector2) -> void:
	if items.is_empty() or sel >= items.size() or capturing():
		return
	var tip: String = items[sel].get("tip", "")
	if tip == "":
		return
	var fs := int(14 * u)
	var mouse: bool = game.ctl.device == "mouse" and items[sel].has("rect") and items[sel].rect.has_point(_mouse)
	var w := minf(vp.x - 60 * u, (440 if mouse else 760) * u)
	var h := _para_h(tip, w - 44 * u, fs) + 14 * u
	var r := Rect2((vp.x - w) * 0.5, vp.y - 44 * u - h, w, h)
	if mouse:
		# a tooltip next to the cursor, kept on screen
		r.position = _mouse + Vector2(18, 22) * u
		r.position.x = clampf(r.position.x, 8 * u, vp.x - w - 8 * u)
		if r.end.y > vp.y - 8 * u:
			r.position.y = _mouse.y - h - 12 * u
	draw_rect(r, Color(0.03, 0.035, 0.04, 0.96))
	draw_rect(r, Color(1.0, 0.85, 0.5, 0.45), false, maxf(1.0, u))
	_bounds = r
	_text(Vector2(r.position.x + 12 * u, r.position.y + 21 * u), "?", fs, Color(1.0, 0.85, 0.45), bold)
	_para(r.position + Vector2(32 * u, 21 * u), tip, w - 44 * u, fs, Color(0.88, 0.9, 0.86))


func _run_line() -> String:
	var secs := int(game.run_time)
	return game.L("stats") % [game.kills, game.player.get("shards", 0), "%d:%02d" % [secs / 60, secs % 60]]


## Draws a row of buttons/values; returns the bottom y.
func _draw_rows(x: float, y: float, w: float, row_h: float, from: int = 0) -> float:
	var fs := int(18 * u)
	# slider values share one column wide enough for the longest, so the bars line up
	var vcol := 70.0 * u
	for i in range(from, items.size()):
		if items[i].type == "slider":
			vcol = maxf(vcol, _w(items[i].value, int(fs * (0.85 if items[i].get("small", false) else 1.0))) + 16.0 * u)
	for i in range(from, items.size()):
		var it: Dictionary = items[i]
		var small: bool = it.get("small", false)
		var size := int(fs * (0.85 if small else 1.0))
		var r := Rect2(x, y, w, row_h)
		it.rect = r
		var on := i == sel
		if on:
			draw_rect(r, Color(1, 1, 1, 0.07))
			_text(Vector2(x + 8 * u, y + row_h * 0.68), "›", size, Color(1.0, 0.85, 0.45), bold)
		var lc := Color(1.0, 0.95, 0.85) if on else Color(0.78, 0.82, 0.8)
		match it.type:
			"button":
				var bf: Font = bold if on else font
				var note: String = it.get("note", "")
				var ns := int(size * 0.8)
				var bs := _fit(it.label, size, w - 60 * u - (_w("  ·  " + note, ns) if note != "" else 0.0), bf)
				var lw := _w(it.label, bs, bf) + (_w("  ·  " + note, ns) if note != "" else 0.0)
				var bx := x + (w - lw) * 0.5 if not small else x + 30 * u
				bx += _text(Vector2(bx, y + row_h * 0.68), it.label, bs, lc, bf)
				if note != "":
					_text(Vector2(bx, y + row_h * 0.68), "  ·  " + note, ns, Color(0.6, 0.62, 0.6))
			"value":
				var v: String = "‹  " + it.value + "  ›" if on else it.value
				var vs := _fit(v, size, w * 0.5, bold)
				var vw := _w(v, vs, bold)
				var vx := x + w - 20 * u - vw
				_text(Vector2(vx, y + row_h * 0.68), v, vs, Color(1.0, 0.85, 0.5) if on else lc, bold)
				# clicking the left half of the value steps back, the right half forward
				it.left = Rect2(vx - 12 * u, y, vw * 0.5 + 12 * u, row_h)
				_text_fit(Vector2(x + 30 * u, y + row_h * 0.68), it.label, size, w - 66 * u - vw, lc)
			"text":
				var typing := on and _typing
				var tv: String = it.value
				var tc := Color(1.0, 0.85, 0.5) if on else lc
				if tv == "" and not typing:
					tv = game.L("world_name_ph")
					tc = Color(0.5, 0.52, 0.5)
				var shown := tv + ("_" if typing and int(t * 2.0) % 2 == 0 else " ") if typing else tv
				var ts := _fit(shown, size, w * 0.55, bold)
				var tw := _w(shown, ts, bold)
				var box := Rect2(x + w - 30 * u - maxf(tw, w * 0.4), y + row_h * 0.12, maxf(tw, w * 0.4) + 16 * u, row_h * 0.76)
				draw_rect(box, Color(1, 1, 1, 0.08 if typing else 0.04))
				draw_rect(box, Color(1.0, 0.85, 0.5, 0.6) if typing else Color(1, 1, 1, 0.15), false, maxf(1.0, u))
				_text(Vector2(x + w - 22 * u - tw, y + row_h * 0.68), shown, ts, tc, bold)
				_text_fit(Vector2(x + 30 * u, y + row_h * 0.68), it.label, size, box.position.x - x - 40 * u, lc)
			"slider":
				var bw := minf(w * 0.32, w - 200.0 * u - vcol)
				_text_fit(Vector2(x + 30 * u, y + row_h * 0.68), it.label, size, w - 60 * u - vcol - bw, lc)
				var bar := Rect2(x + w - 20 * u - vcol - bw, y + row_h * 0.4, bw, row_h * 0.22)
				it.bar = bar
				draw_rect(bar, Color(1, 1, 1, 0.1))
				var fill := Color(1.0, 0.85, 0.5) if on else Color(0.6, 0.66, 0.62)
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(it.frac, 0.0, 1.0), bar.size.y)), fill)
				_text(Vector2(x + w - 20 * u - _w(it.value, size), y + row_h * 0.68), it.value, size, lc)
			"bind":
				_draw_bind(it, r, size, on, lc)
			"tabs":
				_draw_tabs(it, r, size, on)
		y += row_h
	return y


func _draw_bind(it: Dictionary, r: Rect2, size: int, on: bool, lc: Color) -> void:
	var binds: Array = game.ctl.binds[it.action]
	var sw := 150.0 * u
	_text_fit(Vector2(r.position.x + 30 * u, r.position.y + r.size.y * 0.68), it.label, size, r.size.x - 70 * u - 2 * (sw + 10 * u), lc)
	it.slots = []
	for k in 2:
		var sr := Rect2(r.end.x - 20 * u - (2 - k) * (sw + 10 * u), r.position.y + 4 * u, sw, r.size.y - 8 * u)
		it.slots.append(sr)
		var waiting: bool = not _capture.is_empty() and _capture.action == it.action and _capture.slot == k
		var hl := on and col == k
		draw_rect(sr, Color(1, 1, 1, 0.12 if hl else 0.05))
		draw_rect(sr, Color(1.0, 0.85, 0.5, 0.8) if hl else Color(1, 1, 1, 0.15), false, maxf(1.0, u))
		var label: String = "..." if waiting else Controls.bind_label(binds[k], game.mouse_names())
		if label == "":
			label = "—"
		var c := Color(1.0, 0.85, 0.45) if waiting and int(t * 4.0) % 2 == 0 else (Color(1, 0.95, 0.85) if hl else Color(0.75, 0.78, 0.76))
		var ls := _fit(label, size, sw - 12 * u, bold)
		_text(Vector2(sr.get_center().x - _w(label, ls, bold) * 0.5, sr.position.y + sr.size.y * 0.7), label, ls, c, bold)


func _draw_tabs(it: Dictionary, r: Rect2, size: int, on: bool) -> void:
	var n := TABS.size()
	var tw := r.size.x / n
	it.tab_rects = []
	for k in n:
		var tr := Rect2(r.position.x + k * tw, r.position.y, tw, r.size.y)
		it.tab_rects.append(tr)
		var label: String = game.L(TABS[k])
		var cur := k == tab
		if cur:
			draw_rect(Rect2(tr.position.x + 6 * u, tr.end.y - 3 * u, tw - 12 * u, 2 * u), Color(1.0, 0.85, 0.45))
		var c := Color(1.0, 0.9, 0.6) if cur else Color(0.6, 0.65, 0.63)
		if on and cur:
			c = Color(1, 1, 1)
		var ts := _fit(label, size, tw - 10 * u, bold)
		_text(Vector2(tr.get_center().x - _w(label, ts, bold) * 0.5, tr.position.y + tr.size.y * 0.66), label, ts,
			c, bold if cur else font)


func _draw_list(vp: Vector2, title: String, accent: Color, width: float, sub: String = "") -> void:
	var w := minf(vp.x - 40 * u, width * u)
	var row_h := 40.0 * u
	var fs := int(14 * u)
	var sub_h := _para_h(sub, w - 60 * u, fs) + 10 * u if sub != "" else 0.0
	var top_h := 80.0 * u + sub_h
	var h := top_h + items.size() * row_h + 26 * u
	var r := Rect2((vp.x - w) * 0.5, maxf(16 * u, (vp.y - 70 * u - h) * 0.5), w, h)
	_panel(r, accent)
	_heading(r.position.y + 52 * u, title, int(34 * u))
	if sub != "":
		_para(Vector2(r.position.x + 30 * u, r.position.y + 84 * u), sub, w - 60 * u, fs, Color(0.65, 0.72, 0.68),
			HORIZONTAL_ALIGNMENT_CENTER)
	_draw_rows(r.position.x + 20 * u, r.position.y + top_h, w - 40 * u, row_h)


func _draw_title(vp: Vector2, accent: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.35))
	var lines: Array = LOGO
	var maxlen := 0
	for l in lines:
		maxlen = maxi(maxlen, l.length())
	var fs := maxi(4, int(minf(vp.x * 0.62 / (maxlen * 0.61), 30.0 * u)))
	var lh := fs * 1.18
	var adv := bold.get_char_size("M".unicode_at(0), fs).x
	var x0 := (vp.x - maxlen * adv) * 0.5
	var y0 := vp.y * 0.2
	var shades := {"█": 1.0, "▓": 0.78, "▒": 0.55, "░": 0.36, "▄": 1.0, "▀": 1.0, "▌": 1.0, "▐": 1.0}
	for i in lines.size():
		var line: String = lines[i]
		for j in line.length():
			var ch := line[j]
			if ch == " ":
				continue
			var k := float(j) / maxlen
			var pulse := 0.85 + 0.15 * sin(t * 1.2 + k * 5.0 - i * 0.4)
			var c := Color(0.86, 0.1, 0.1).lerp(accent, 0.15) * float(shades.get(ch, 0.6)) * pulse
			c.a = 1.0
			draw_char(bold, Vector2(x0 + j * adv, y0 + i * lh), ch, fs, c)
	var y := y0 + lines.size() * lh + 34 * u
	_center(y, game.L("subtitle"), int(19 * u), Color(0.75, 0.7, 0.68))
	var w := minf(vp.x - 40 * u, 460.0 * u)
	var row_h := minf(42.0 * u, (vp.y - 90 * u - (y + 40 * u)) / maxf(1.0, items.size()))
	_draw_rows((vp.x - w) * 0.5, y + 40 * u, w, row_h)
	var pr: Dictionary = game.cfg.profile
	if pr.runs > 0:
		var best: String = game.L("best") % [pr.best_level, pr.get("best_xp", 1), pr.get("best_combo", 0)]
		_center(vp.y - 56 * u, best, int(13 * u), Color(0.55, 0.62, 0.58))
	# bottom left: the FPS counter sits in the bottom right corner
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	_text(Vector2(16 * u, vp.y - 22 * u), ver, int(12 * u), Color(0.4, 0.45, 0.43))


func _draw_settings(vp: Vector2, accent: Color) -> void:
	var w := minf(vp.x - 40 * u, 820.0 * u)
	var n := items.size()
	var row_h := minf(40.0 * u, (vp.y - 300.0 * u) / maxf(1.0, n))
	var h := 120.0 * u + n * row_h + (40.0 * u if tab == 3 else 0.0)
	var r := Rect2((vp.x - w) * 0.5, maxf(16 * u, (vp.y - 90 * u - h) * 0.5), w, h)
	_panel(r, accent)
	_heading(r.position.y + 50 * u, game.L("m_settings"), int(30 * u))
	var y := _draw_rows(r.position.x + 20 * u, r.position.y + 72 * u, w - 40 * u, row_h)
	if tab == 3:
		var note: String = game.L("press_key") if capturing() else game.L("pad_note")
		_center(y + 26 * u, note, int(12 * u), Color(1.0, 0.85, 0.5) if capturing() else Color(0.55, 0.62, 0.58))


func _draw_sign(vp: Vector2, _accent: Color) -> void:
	var w := minf(vp.x - 60 * u, 640.0 * u)
	var h := 230.0 * u
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, Color(0.85, 0.7, 0.45))
	var fs := int(18 * u)
	_para(r.position + Vector2(36 * u, 60 * u), game.sign_text, w - 72 * u, fs, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_rows(r.position.x + w * 0.3, r.end.y - 62 * u, w * 0.4, 40.0 * u)


func _item_name(id: String) -> String:
	return game.L("item_" + id)


## A framed item picture (icon_art.gd), centred in r; an empty frame for "".
func _draw_icon(r: Rect2, id: String, c: Color, on: bool = false) -> void:
	draw_rect(r, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), Color(c.r, c.g, c.b, 0.07 if not on else 0.14))
	draw_rect(r, Color(c.r, c.g, c.b, 0.55 if on else 0.3), false, maxf(1.0, u))
	if id != "":
		IconArt.draw(self, id, r.grow(-2 * u), c)


func _draw_shop(vp: Vector2, _accent: Color) -> void:
	var p: Dictionary = game.player
	var w := minf(vp.x - 40 * u, 780.0 * u)
	var row_h := 50.0 * u
	var h := 190.0 * u + items.size() * row_h
	var r := Rect2((vp.x - w) * 0.5, maxf(10 * u, (vp.y - h) * 0.5), w, h)
	var selling := top() == "sell"
	_panel(r, Color(0.85, 0.7, 0.95))
	_center(r.position.y + 46 * u, game.L("shop_sell" if selling else "act_shop"), int(28 * u), Color(0.95, 0.95, 0.9), bold)
	_center(r.position.y + 76 * u, game.L("shop_sell_greet" if selling else "shop_greet"), int(15 * u), Color(0.75, 0.7, 0.85))
	var money := "◆ %d" % p.shards
	_text(Vector2(r.end.x - 30 * u - _w(money, int(18 * u), bold), r.position.y + 46 * u), money, int(18 * u), Color(1.0, 0.85, 0.35), bold)
	var fs := int(17 * u)
	var y := r.position.y + 100 * u
	for i in items.size():
		var it: Dictionary = items[i]
		var rect := Rect2(r.position.x + 20 * u, y, w - 40 * u, row_h)
		it.rect = rect
		var on := i == sel
		draw_rect(rect.grow(-2 * u), Color(1, 1, 1, 0.09 if on else 0.03))
		if on:
			draw_rect(rect.grow(-2 * u), Color(1.0, 0.85, 0.5, 0.6), false, maxf(1.0, u))
		if it.type == "button":
			_center(y + row_h * 0.62, it.label, fs, Color(0.9, 0.92, 0.9), bold)
		else:
			var gc: Color = it.get("color", Items.def(it.id).get("color", Color.WHITE))
			var label: String = it.get("label", _item_name(it.id))
			_draw_icon(Rect2(rect.position + Vector2(6, 5) * u, Vector2(row_h * 1.2, row_h - 10 * u)), it.id, gc, on)
			var tx := rect.position.x + row_h * 1.2 + 18 * u
			var price := ("+◆ %d" if it.get("sell", false) else "◆ %d") % it.price
			var pc := Color(1.0, 0.85, 0.35) if p.shards >= it.price or it.get("sell", false) else Color(0.6, 0.35, 0.3)
			var pw := _w(price, fs, bold)
			_text(Vector2(rect.end.x - 16 * u - pw, y + row_h * 0.62), price, fs, pc, bold)
			var tw := rect.end.x - 32 * u - pw - tx
			_text_fit(Vector2(tx, y + row_h * 0.44), label, fs, tw, Color(1, 0.96, 0.88) if on else Color(0.82, 0.85, 0.83), bold)
			var desc: String = it.get("note", "")
			if not it.has("label"):
				desc = game.L("item_" + it.id + "_d")
			_text_fit(Vector2(tx, y + row_h * 0.82), desc, int(12 * u), tw, Color(0.6, 0.65, 0.63))
		y += row_h


func _draw_map(vp: Vector2, accent: Color) -> void:
	var lv = game.lv
	var w := minf(vp.x - 60 * u, 1040.0 * u)
	var h := minf(vp.y - 80 * u, 640.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, accent)
	_center(r.position.y + 44 * u, "%s · %s" % [game.biome_name(), game.L("level") % game.level_num], int(24 * u), accent, bold)
	var k := minf((w - 80 * u) / lv.w, (h - 150 * u) / lv.h)
	var size := Vector2(lv.w, lv.h) * k
	_map_rect = Rect2(r.position.x + (w - size.x) * 0.5, r.position.y + 70 * u + (h - 150 * u - size.y) * 0.5, size.x, size.y)
	draw_rect(_map_rect.grow(4 * u), Color(0, 0, 0, 0.5))
	_center(r.end.y - 30 * u, game.L("map_legend"), int(13 * u), Color(0.6, 0.66, 0.63))
	if not items.is_empty():
		items[0].rect = Rect2()


func _draw_map_content() -> void:
	if top() != "map" or game.lv == null:
		return
	var tex: ImageTexture = game.hud.map_texture()
	if tex == null:
		return
	_map_ci.draw_texture_rect(tex, _map_rect, false)
	Hud.draw_map_marks(_map_ci, _map_rect, u * 1.6, t, bold, game)


func _draw_moves(vp: Vector2, accent: Color) -> void:
	var w := minf(vp.x - 60 * u, 760.0 * u)
	var moves := [
		["move_triple", "%s %s %s" % [game.key("attack"), game.key("attack"), game.key("attack")]],
		["move_lunge", "%s → %s" % [game.key("dash"), game.key("attack")]],
		["move_rise", "%s + %s" % [game.key("up"), game.key("attack")]],
		["move_pogo", "%s + %s" % [game.key("down"), game.key("attack")]],
		["move_knife", game.key("throw")],
		["move_block", game.key("block")],
		["move_swap", game.key("swap")],
		["move_crit", ""],
	]
	# descriptions wrap, so every row is as tall as its text
	var dw := w - 72 * u
	var ds := int(14 * u)
	var h := 160.0 * u
	for m in moves:
		h += 34 * u + _para_h(game.L(m[0] + "_d"), dw, ds)
	var r := Rect2((vp.x - w) * 0.5, maxf(10 * u, (vp.y - 40 * u - h) * 0.5), w, h)
	_panel(r, accent)
	_heading(r.position.y + 48 * u, game.L("m_moves"), int(30 * u))
	var y := r.position.y + 90 * u
	for m in moves:
		var kw := 0.0
		if m[1] != "":
			kw = _w(m[1], int(16 * u), bold) + 16 * u
			_text(Vector2(r.end.x - 36 * u - _w(m[1], int(16 * u), bold), y), m[1], int(16 * u), Color(0.95, 0.92, 0.8), bold)
		_text_fit(Vector2(r.position.x + 36 * u, y), game.L(m[0]), int(18 * u), dw - kw, Color(1.0, 0.85, 0.45), bold)
		y += 34 * u + _para(Vector2(r.position.x + 36 * u, y + 24 * u), game.L(m[0] + "_d"), dw, ds, Color(0.72, 0.77, 0.74))
	_draw_rows(r.position.x + w * 0.3, r.end.y - 58 * u, w * 0.4, 40.0 * u)


const DIFF_COLORS := {"easy": Color(0.6, 0.85, 0.65), "normal": Color(0.85, 0.82, 0.7), "hard": Color(1.0, 0.55, 0.3),
	"nightmare": Color(1.0, 0.2, 0.2)}


func _world_line(w: Dictionary) -> String:
	var secs := int(w.get("time", 0.0))
	return game.L("world_info") % [w.get("level", 1), w.get("hero", 1), "%d:%02d" % [secs / 3600, (secs / 60) % 60]]


func _draw_worlds(vp: Vector2, accent: Color) -> void:
	var w := minf(vp.x - 40 * u, 700.0 * u)
	var row_h := 62.0 * u
	var n := 0
	for it in items:
		if it.type == "world":
			n += 1
	var h := 120.0 * u + n * row_h + (items.size() - n) * 40.0 * u
	var r := Rect2((vp.x - w) * 0.5, maxf(16 * u, (vp.y - 40 * u - h) * 0.5), w, h)
	_panel(r, accent)
	_heading(r.position.y + 50 * u, game.L("m_worlds"), int(30 * u))
	var y := r.position.y + 80 * u
	var fs := int(18 * u)
	for i in n:
		var it: Dictionary = items[i]
		var wd: Dictionary = it.w
		var rect := Rect2(r.position.x + 20 * u, y, w - 40 * u, row_h - 6 * u)
		it.rect = rect
		var on := i == sel
		draw_rect(rect, Color(1, 1, 1, 0.09 if on else 0.03))
		if on:
			draw_rect(rect, Color(1.0, 0.85, 0.5, 0.6), false, maxf(1.0, u))
		var dc: Color = DIFF_COLORS.get(wd.difficulty, Color.WHITE)
		var tag: String = game.L("diff_" + wd.difficulty).to_upper()
		var tw := _w(tag, int(13 * u), bold)
		_text(Vector2(rect.end.x - 16 * u - tw, rect.position.y + 24 * u), tag, int(13 * u), dc, bold)
		_text_fit(Vector2(rect.position.x + 16 * u, rect.position.y + 24 * u), wd.name, fs, rect.size.x - tw - 48 * u,
			Color(1, 0.96, 0.88) if on else Color(0.82, 0.85, 0.83), bold)
		_text_fit(Vector2(rect.position.x + 16 * u, rect.position.y + 46 * u), _world_line(wd), int(13 * u), rect.size.x - 32 * u,
			Color(0.6, 0.65, 0.63))
		y += row_h
	_draw_rows(r.position.x + 20 * u, y + 6 * u, w - 40 * u, 40.0 * u, n)

