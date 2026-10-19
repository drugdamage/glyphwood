## Menus drawn with glyphs: title, pause, settings (game, video, audio,
## controls with rebinding), inventory, merchant, map, sign, death and victory.
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


func setup(g, f: Font, b: Font) -> void:
	game = g
	font = f
	bold = b


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
	game.ctl.swallow()
	game.sfx("menu_back", -4.0)


func close_all() -> void:
	stack.clear()
	game.ctl.swallow()
	_capture = {}
	sel = 0


func active() -> bool:
	return not stack.is_empty()


func is_open(name: String) -> bool:
	return stack.has(name)


func top() -> String:
	return stack[-1] if not stack.is_empty() else ""


func capturing() -> bool:
	return not _capture.is_empty()


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


func _message(text: String) -> void:
	_msg = text
	_msg_t = 2.5


# ---------------------------------------------------------------- content

func _btn(label: String, act: Callable, extra: Dictionary = {}) -> Dictionary:
	var d := {"type": "button", "label": label, "act": act}
	d.merge(extra)
	return d


func _toggle(label: String, key: String) -> Dictionary:
	var v: bool = game.cfg.get_v(key)
	var flip := func(_dir: int = 0) -> void: game.set_setting(key, not game.cfg.get_v(key))
	return {"type": "value", "label": game.L(label), "value": game.L("on" if v else "off"), "act": flip, "adj": flip}


func _choice(label: String, value: String, adj: Callable) -> Dictionary:
	return {"type": "value", "label": game.L(label), "value": value, "act": adj.bind(1), "adj": adj}


func _slider(label: String, key: String, lo: float, hi: float, step: float) -> Dictionary:
	var v: float = game.cfg.get_v(key)
	var adj := func(dir: int) -> void: game.set_setting(key, clampf(snappedf(game.cfg.get_v(key) + dir * step, step), lo, hi))
	var setf := func(f: float) -> void: game.set_setting(key, clampf(snappedf(lerpf(lo, hi, f), step), lo, hi))
	return {"type": "slider", "label": game.L(label), "frac": (v - lo) / (hi - lo), "value": "%d%%" % int(round(v * 100.0)),
		"act": adj.bind(1), "adj": adj, "setf": setf}


## Bound as _cycle.bind(key, choices); Callable.bind appends, so dir comes first.
func _cycle(dir: int, key: String, choices: Array) -> void:
	var i := choices.find(game.cfg.get_v(key))
	game.set_setting(key, choices[posmod(i + dir, choices.size())])


func _build(name: String) -> Array:
	var out: Array = []
	match name:
		"title":
			if game.has_save():
				out.append(_btn(game.L("m_continue"), game.continue_run))
			out.append(_btn(game.L("m_new"), _new_game))
			out.append(_btn(game.L("m_settings"), open.bind("settings")))
			if not OS.has_feature("web"):
				out.append(_btn(game.L("m_quit"), get_tree().quit))
		"pause":
			out.append(_btn(game.L("m_resume"), close))
			out.append(_btn(game.L("m_inventory"), open.bind("inventory")))
			out.append(_btn(game.L("m_map"), open.bind("map")))
			out.append(_btn(game.L("m_settings"), open.bind("settings")))
			out.append(_btn(game.L("m_quit_title"), game.show_title))
		"settings":
			out.append({"type": "tabs"})
			out.append_array(_settings_tab())
			out.append(_btn(game.L("m_back"), close))
		"confirm_new":
			out.append(_btn(game.L("m_yes"), game.new_run))
			out.append(_btn(game.L("m_no"), close))
		"dead":
			out.append(_btn(game.L("m_try_again"), game.new_run))
			out.append(_btn(game.L("m_title"), game.show_title))
		"victory":
			out.append(_btn(game.L("m_deeper"), game.continue_deeper))
			out.append(_btn(game.L("m_title"), game.show_title))
		"sign", "map":
			out.append(_btn(game.L("m_ok") if name == "sign" else game.L("m_back"), close))
		"inventory":
			out = _inventory_items()
		"shop":
			out = _shop_items()
	return out


func _new_game() -> void:
	if game.has_save():
		open("confirm_new")
	else:
		game.new_run()


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
				_message(game.L("hints_reset_done")), {"small": true}))
			out.append(_toggle("s_damage_numbers", "damage_numbers"))
			out.append(_slider("s_shake", "shake", 0.0, 1.0, 0.1))
			out.append(_toggle("s_mouse_aim", "mouse_aim"))
		1:
			var modes: Array = Settings.WINDOW_CHOICES if not OS.has_feature("web") else ["windowed", "borderless"]
			out.append(_choice("s_window", game.L("w_" + cfg.get_v("window")), _cycle.bind("window", modes)))
			out.append(_toggle("s_vsync", "vsync"))
			var fps: int = cfg.get_v("fps")
			out.append(_choice("s_fps", game.L("fps_0") if fps == 0 else str(fps), _cycle.bind("fps", Settings.FPS_CHOICES)))
			out.append(_choice("s_zoom", game.L("zoom_%d" % cfg.get_v("zoom")), _cycle.bind("zoom", [0, 1, 2])))
			out.append(_toggle("s_lighting", "lighting"))
			out.append(_toggle("s_glow", "glow"))
			out.append(_toggle("s_scanlines", "scanlines"))
			out.append(_toggle("s_vignette", "vignette"))
			out.append(_slider("s_ui_scale", "ui_scale", 0.8, 1.3, 0.05))
			out.append(_toggle("s_show_fps", "show_fps"))
		2:
			out.append(_slider("s_master", "vol_master", 0.0, 1.0, 0.05))
			out.append(_slider("s_music", "vol_music", 0.0, 1.0, 0.05))
			out.append(_slider("s_sfx", "vol_sfx", 0.0, 1.0, 0.05))
			out.append(_slider("s_amb", "vol_amb", 0.0, 1.0, 0.05))
			out.append(_toggle("s_mute_unfocused", "mute_unfocused"))
		3:
			for a in Controls.ACTIONS:
				out.append({"type": "bind", "label": game.L("a_" + a), "action": a})
			out.append(_btn(game.L("m_reset"), func() -> void:
				game.ctl.reset()
				game.cfg.set_v("binds", {}), {"small": true}))
	return out


func _inventory_items() -> Array:
	var p: Dictionary = game.player
	var out: Array = []
	out.append({"type": "item", "id": p.weapon, "group": "weapon"})
	for i in Items.CHARM_SLOTS:
		if i < p.charms.size():
			out.append({"type": "item", "id": p.charms[i], "group": "charm"})
		else:
			out.append({"type": "slot", "group": "charm"})
	for id in p.bag:
		out.append({"type": "item", "id": id, "group": "bag"})
	for it in out:
		if it.type == "item":
			it.act = _equip.bind(it.id)
	return out


func _equip(id: String) -> void:
	var p: Dictionary = game.player
	if Items.toggle(p, id):
		Hero.refresh(p)
		game.sfx("menu_ok")
	else:
		game.sfx("error", -6.0)
		if Items.def(id).slot == "charm":
			_message(game.L("inv_full"))


func _shop_items() -> Array:
	var pr: Dictionary = game.shop_prop
	var p: Dictionary = game.player
	var out: Array = []
	for id in pr.get("stock", []):
		out.append({"type": "buy", "id": id, "price": Items.def(id).price, "act": _buy.bind(id)})
	out.append({"type": "buy", "id": "flask", "price": Items.FLASK_PRICE, "act": _buy.bind("flask"),
		"label": game.L("shop_flask"), "glyph": "[+]", "color": Color(0.5, 1.0, 0.6),
		"note": "%d/%d" % [p.flasks, p.max_flasks]})
	out.append({"type": "buy", "id": "heart", "price": Items.HEART_PRICE, "act": _buy.bind("heart"),
		"label": game.L("shop_heart"), "glyph": "♥", "color": Color(1.0, 0.35, 0.45), "note": "%d/%d" % [p.hp, p.max_hp]})
	out.append(_btn(game.L("m_leave"), close))
	return out


func _buy(id: String) -> void:
	var p: Dictionary = game.player
	var price: int = Items.FLASK_PRICE if id == "flask" else (Items.HEART_PRICE if id == "heart" else Items.def(id).price)
	if (id == "flask" and p.flasks >= p.max_flasks) or (id == "heart" and p.hp >= p.max_hp):
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
		"flask":
			p.flasks += 1
		"heart":
			p.hp += 1
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
		"value", "slider":
			it.adj.call(dir)
			game.sfx("menu_move", -8.0)


func _back() -> void:
	match top():
		"title":
			return
		"dead", "victory":
			return
	close()


func handle(event: InputEvent) -> void:
	if event is InputEventMouse:
		_handle_mouse(event as InputEventMouse)
	elif event.is_pressed():
		_handle_button(event)


func _handle_mouse(event: InputEventMouse) -> void:
	_mouse = event.position
	var i := _hover(event.position)
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if top() == "map" and i < 0:
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
	if it.type == "slider" and it.has("bar") and it.bar.grow(6).has_point(pos):
		it.setf.call(clampf((pos.x - it.bar.position.x) / it.bar.size.x, 0.0, 1.0))
		game.sfx("menu_move", -8.0)
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
	elif (top() == "inventory" and event.is_action_pressed("g_inventory")) or (top() == "map" and event.is_action_pressed("g_map")):
		close()
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


## Called from main._input while waiting for a new binding.
func capture(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed():
		return
	if event is InputEventKey and event.is_echo():
		return
	var a: String = _capture.action
	var slot: int = _capture.slot
	if event is InputEventKey:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_ESCAPE:
			_capture = {}
			game.sfx("menu_back", -6.0)
			return
		if k == KEY_BACKSPACE or k == KEY_DELETE:
			game.ctl.rebind(a, slot, "")
			_finish_capture()
			return
	var b := Controls.encode(event)
	if b != "":
		game.ctl.rebind(a, slot, b)
		_finish_capture()


func _finish_capture() -> void:
	_capture = {}
	game.cfg.set_v("binds", game.ctl.binds.duplicate(true))
	game.sfx("menu_ok", -4.0)


# ---------------------------------------------------------------- drawing

func _text(pos: Vector2, text: String, size: int, color: Color, f: Font = null) -> float:
	var fnt := f if f != null else font
	size = maxi(size, 4)
	draw_string(fnt, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 4)).x


func _w(text: String, size: int, f: Font = null) -> float:
	return (f if f != null else font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(size, 4)).x


func _center(y: float, text: String, size: int, color: Color, f: Font = null) -> void:
	_text(Vector2((get_viewport_rect().size.x - _w(text, size, f)) * 0.5, y), text, size, color, f)


## A panel with a glyph frame.
func _panel(r: Rect2, accent: Color) -> void:
	draw_rect(r, Color(0.015, 0.02, 0.022, 0.9))
	var fs := int(14 * u)
	var c := Color(accent.r, accent.g, accent.b, 0.55)
	draw_rect(r.grow(-4 * u), Color(accent.r, accent.g, accent.b, 0.18), false, maxf(1.0, u))
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var g := "+"
		_text(corner + Vector2(-_w(g, fs, bold) * 0.5, fs * 0.35), g, fs, c, bold)
	var step := 14.0 * u
	var x := r.position.x + step
	while x < r.end.x - step * 0.5:
		_text(Vector2(x - 3 * u, r.position.y + fs * 0.35), "-", fs, c * 0.8, font)
		_text(Vector2(x - 3 * u, r.end.y + fs * 0.35), "-", fs, c * 0.8, font)
		x += step


func _draw() -> void:
	if not active():
		return
	var vp := get_viewport_rect().size
	u = vp.y / 900.0 * float(game.cfg.get_v("ui_scale"))
	var name := top()
	var accent: Color = Color(0.8, 0.2, 0.2).lerp(game.biome.top, 0.2)
	if name != "title":
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55 if name != "dead" else 0.65))
	match name:
		"title":
			_draw_title(vp, accent)
		"pause":
			_draw_list(vp, game.L("paused"), accent, 360.0, _run_line())
		"confirm_new":
			_draw_list(vp, game.L("m_new"), accent, 520.0, game.L("confirm_new"))
		"settings":
			_draw_settings(vp, accent)
		"dead":
			_draw_end(vp, game.L("died"), Color(1.0, 0.32, 0.28), game.L("died_sub") % [game.biome_name(), game.level_num])
		"victory":
			_draw_end(vp, game.L("victory"), Color(1.0, 0.85, 0.4), game.L("victory_sub"))
		"sign":
			_draw_sign(vp, accent)
		"inventory":
			_draw_inventory(vp, accent)
		"shop":
			_draw_shop(vp, accent)
		"map":
			_draw_map(vp, accent)
	if _msg_t > 0.0:
		var a := minf(1.0, _msg_t * 2.0)
		_center(vp.y - 70 * u, _msg, int(16 * u), Color(1.0, 0.85, 0.5, a), bold)
	if name != "map":
		_center(vp.y - 22 * u, game.L("menu_hint"), int(12 * u), Color(0.5, 0.56, 0.54))


func _run_line() -> String:
	var secs := int(game.run_time)
	return game.L("stats") % [game.kills, game.player.get("shards", 0), "%d:%02d" % [secs / 60, secs % 60]]


## Draws a row of buttons/values; returns the bottom y.
func _draw_rows(x: float, y: float, w: float, row_h: float, from: int = 0) -> float:
	var fs := int(18 * u)
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
				var lw := _w(it.label, size, bold if on else font)
				var bx := x + (w - lw) * 0.5 if not small else x + 30 * u
				_text(Vector2(bx, y + row_h * 0.68), it.label, size, lc, bold if on else font)
			"value":
				_text(Vector2(x + 30 * u, y + row_h * 0.68), it.label, size, lc)
				var v: String = "‹  " + it.value + "  ›" if on else it.value
				_text(Vector2(x + w - 20 * u - _w(v, size, bold), y + row_h * 0.68), v, size, Color(1.0, 0.85, 0.5) if on else lc, bold)
			"slider":
				_text(Vector2(x + 30 * u, y + row_h * 0.68), it.label, size, lc)
				var bw := w * 0.32
				var bar := Rect2(x + w - 90 * u - bw, y + row_h * 0.4, bw, row_h * 0.22)
				it.bar = bar
				draw_rect(bar, Color(1, 1, 1, 0.1))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * it.frac, bar.size.y)), Color(1.0, 0.85, 0.5) if on else Color(0.6, 0.66, 0.62))
				_text(Vector2(x + w - 20 * u - _w(it.value, size), y + row_h * 0.68), it.value, size, lc)
			"bind":
				_draw_bind(it, r, size, on, lc)
			"tabs":
				_draw_tabs(it, r, size, on)
		y += row_h
	return y


func _draw_bind(it: Dictionary, r: Rect2, size: int, on: bool, lc: Color) -> void:
	_text(Vector2(r.position.x + 30 * u, r.position.y + r.size.y * 0.68), it.label, size, lc)
	var binds: Array = game.ctl.binds[it.action]
	var sw := 150.0 * u
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
		_text(Vector2(sr.get_center().x - _w(label, size, bold) * 0.5, sr.position.y + sr.size.y * 0.7), label, size, c, bold)


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
		_text(Vector2(tr.get_center().x - _w(label, size, bold) * 0.5, tr.position.y + tr.size.y * 0.66), label, size,
			c, bold if cur else font)


func _draw_list(vp: Vector2, title: String, accent: Color, width: float, sub: String = "") -> void:
	var w := width * u
	var row_h := 40.0 * u
	var h := 130.0 * u + items.size() * row_h
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, accent)
	_center(r.position.y + 52 * u, title, int(34 * u), Color(0.95, 0.95, 0.9), bold)
	if sub != "":
		_center(r.position.y + 82 * u, sub, int(14 * u), Color(0.65, 0.72, 0.68))
	_draw_rows(r.position.x + 20 * u, r.position.y + 105 * u, w - 40 * u, row_h)


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
	var w := 380.0 * u
	_draw_rows((vp.x - w) * 0.5, y + 40 * u, w, 42.0 * u)
	var pr: Dictionary = game.cfg.profile
	if pr.runs > 0:
		_center(vp.y - 56 * u, game.L("best") % [pr.runs, pr.wins, pr.best_level], int(13 * u), Color(0.55, 0.62, 0.58))
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	_text(Vector2(vp.x - _w(ver, int(12 * u)) - 16 * u, vp.y - 22 * u), ver, int(12 * u), Color(0.4, 0.45, 0.43))


func _draw_settings(vp: Vector2, accent: Color) -> void:
	var w := minf(vp.x - 40 * u, 820.0 * u)
	var n := items.size()
	var row_h := minf(40.0 * u, (vp.y - 230.0 * u) / maxf(1.0, n))
	var h := 120.0 * u + n * row_h + (40.0 * u if tab == 3 else 0.0)
	var r := Rect2((vp.x - w) * 0.5, maxf(20 * u, (vp.y - h) * 0.5), w, h)
	_panel(r, accent)
	_center(r.position.y + 50 * u, game.L("m_settings"), int(30 * u), Color(0.95, 0.95, 0.9), bold)
	var y := _draw_rows(r.position.x + 20 * u, r.position.y + 72 * u, w - 40 * u, row_h)
	if tab == 3:
		var note: String = game.L("press_key") if capturing() else game.L("pad_note")
		_center(y + 26 * u, note, int(12 * u), Color(1.0, 0.85, 0.5) if capturing() else Color(0.55, 0.62, 0.58))


func _draw_end(vp: Vector2, title: String, color: Color, sub: String) -> void:
	var y := vp.y * 0.36
	_center(y, title, int(62 * u), color, bold)
	_center(y + 48 * u, sub, int(18 * u), Color(0.88, 0.9, 0.88))
	_center(y + 80 * u, _run_line(), int(16 * u), Color(0.62, 0.7, 0.66))
	var w := 380.0 * u
	_draw_rows((vp.x - w) * 0.5, y + 120 * u, w, 42.0 * u)


func _draw_sign(vp: Vector2, _accent: Color) -> void:
	var w := minf(vp.x - 60 * u, 640.0 * u)
	var h := 230.0 * u
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, Color(0.85, 0.7, 0.45))
	var fs := int(18 * u)
	draw_multiline_string(font, r.position + Vector2(36 * u, 60 * u), game.sign_text, HORIZONTAL_ALIGNMENT_CENTER, w - 72 * u, fs, -1,
		Color(0.95, 0.9, 0.8))
	_draw_rows(r.position.x + w * 0.3, r.end.y - 62 * u, w * 0.4, 40.0 * u)


func _item_name(id: String) -> String:
	return game.L("item_" + id)


func _draw_inventory(vp: Vector2, accent: Color) -> void:
	var p: Dictionary = game.player
	var w := minf(vp.x - 40 * u, 980.0 * u)
	var h := minf(vp.y - 60 * u, 640.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, accent)
	_center(r.position.y + 48 * u, game.L("m_inventory"), int(30 * u), Color(0.95, 0.95, 0.9), bold)
	var fs := int(17 * u)
	var row_h := 36.0 * u
	var lx := r.position.x + 30 * u
	var cw := w * 0.46
	var rx := r.position.x + w * 0.52
	var y := r.position.y + 90 * u
	_text(Vector2(lx, y), game.L("inv_weapon").to_upper(), int(13 * u), Color(0.6, 0.66, 0.63), bold)
	_text(Vector2(rx, y), game.L("inv_bag").to_upper(), int(13 * u), Color(0.6, 0.66, 0.63), bold)
	var ly := y + 10 * u
	var by := y + 10 * u
	var charm_header := false
	for i in items.size():
		var it: Dictionary = items[i]
		var rect: Rect2
		if it.group == "bag":
			rect = Rect2(rx, by, cw, row_h)
			by += row_h
		else:
			if it.group == "charm" and not charm_header:
				charm_header = true
				ly += 24 * u
				_text(Vector2(lx, ly), game.L("inv_charms").to_upper(), int(13 * u), Color(0.6, 0.66, 0.63), bold)
				ly += 10 * u
			rect = Rect2(lx, ly, cw, row_h)
			ly += row_h
		it.rect = rect
		var on := i == sel
		draw_rect(rect.grow(-2 * u), Color(1, 1, 1, 0.09 if on else 0.03))
		if on:
			draw_rect(rect.grow(-2 * u), Color(1.0, 0.85, 0.5, 0.6), false, maxf(1.0, u))
		if it.type == "slot":
			_text(Vector2(rect.position.x + 50 * u, rect.position.y + row_h * 0.66), game.L("inv_empty"), fs, Color(0.4, 0.43, 0.42))
			continue
		var d: Dictionary = Items.def(it.id)
		_text(Vector2(rect.position.x + 14 * u, rect.position.y + row_h * 0.68), d.glyph, int(fs * 1.2), d.color, bold)
		_text(Vector2(rect.position.x + 50 * u, rect.position.y + row_h * 0.66), _item_name(it.id), fs,
			Color(1, 0.96, 0.88) if on else Color(0.8, 0.84, 0.82), bold if on else font)
	if p.bag.is_empty():
		_text(Vector2(rx + 20 * u, by + row_h * 0.66), game.L("inv_empty"), fs, Color(0.4, 0.43, 0.42))
	# details of the selected item
	var dy := r.end.y - 150 * u
	draw_line(Vector2(r.position.x + 24 * u, dy - 14 * u), Vector2(r.end.x - 24 * u, dy - 14 * u), Color(1, 1, 1, 0.1), maxf(1.0, u))
	if sel < items.size() and items[sel].type == "item":
		var id: String = items[sel].id
		var d2: Dictionary = Items.def(id)
		_text(Vector2(lx, dy + 10 * u), _item_name(id), int(20 * u), d2.color, bold)
		_text(Vector2(lx, dy + 38 * u), game.L("item_" + id + "_d"), int(15 * u), Color(0.8, 0.84, 0.82))
		if d2.slot == "weapon":
			var ws := "%s %d   %s ×%.2f   %s ×%.2f" % [game.L("stat_dmg"), d2.dmg, game.L("stat_speed"), d2.speed, game.L("stat_reach"), d2.reach]
			_text(Vector2(lx, dy + 64 * u), ws, int(14 * u), Color(0.65, 0.72, 0.68))
		var action := ""
		if items[sel].group == "charm":
			action = game.L("inv_unequip")
		elif items[sel].group == "bag":
			action = game.L("inv_equip")
		if action != "":
			var hint := "[Enter] " + action
			_text(Vector2(r.end.x - 30 * u - _w(hint, int(14 * u), bold), dy + 10 * u), hint, int(14 * u), Color(1.0, 0.85, 0.5), bold)
	var st: Dictionary = p.st
	var summary := "%s %d/%d    %s %d    %s ×%.2f    %s %d/%d    ◆ %d" % [
		game.L("stat_hp"), p.hp, p.max_hp, game.L("stat_dmg"), int(st.dmg * st.dmg_mult), game.L("stat_speed"), st.speed,
		game.L("stat_flasks"), p.flasks, p.max_flasks, p.shards]
	_text(Vector2(lx, r.end.y - 30 * u), summary, int(14 * u), Color(0.7, 0.76, 0.73))


func _draw_shop(vp: Vector2, _accent: Color) -> void:
	var p: Dictionary = game.player
	var w := minf(vp.x - 40 * u, 760.0 * u)
	var row_h := 44.0 * u
	var h := 190.0 * u + items.size() * row_h
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, Color(0.85, 0.7, 0.95))
	_center(r.position.y + 46 * u, game.L("act_shop"), int(28 * u), Color(0.95, 0.95, 0.9), bold)
	_center(r.position.y + 76 * u, game.L("shop_greet"), int(15 * u), Color(0.75, 0.7, 0.85))
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
			_text(Vector2(rect.get_center().x - _w(it.label, fs, bold) * 0.5, y + row_h * 0.64), it.label, fs, Color(0.9, 0.92, 0.9), bold)
		else:
			var glyph: String = it.get("glyph", Items.def(it.id).get("glyph", "?"))
			var gc: Color = it.get("color", Items.def(it.id).get("color", Color.WHITE))
			var label: String = it.get("label", _item_name(it.id))
			_text(Vector2(rect.position.x + 14 * u, y + row_h * 0.66), glyph, int(fs * 1.1), gc, bold)
			_text(Vector2(rect.position.x + 60 * u, y + row_h * 0.45), label, fs, Color(1, 0.96, 0.88) if on else Color(0.82, 0.85, 0.83), bold)
			var desc: String = it.get("note", "")
			if it.has("label") == false:
				desc = game.L("item_" + it.id + "_d")
			_text(Vector2(rect.position.x + 60 * u, y + row_h * 0.85), desc, int(12 * u), Color(0.6, 0.65, 0.63))
			var price := "◆ %d" % it.price
			var pc := Color(1.0, 0.85, 0.35) if p.shards >= it.price else Color(0.6, 0.35, 0.3)
			_text(Vector2(rect.end.x - 16 * u - _w(price, fs, bold), y + row_h * 0.64), price, fs, pc, bold)
		y += row_h


func _draw_map(vp: Vector2, accent: Color) -> void:
	var lv = game.lv
	var w := minf(vp.x - 60 * u, 980.0 * u)
	var h := minf(vp.y - 80 * u, 600.0 * u)
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	_panel(r, accent)
	_center(r.position.y + 44 * u, "%s · %s" % [game.biome_name(), game.L("level") % game.level_num], int(24 * u), accent, bold)
	var cell := minf((w - 80 * u) / lv.gw, (h - 150 * u) / lv.gh * D.ROOM_W / D.ROOM_H)
	var cw := cell
	var ch := cell * D.ROOM_H / D.ROOM_W
	var ox: float = r.position.x + (w - cw * lv.gw) * 0.5
	var oy: float = r.position.y + 70 * u + (h - 150 * u - ch * lv.gh) * 0.5
	var p: Dictionary = game.player
	var pc := Physics.center(p)
	for room in lv.rooms:
		if room == null or not room.seen:
			continue
		var rr := Rect2(ox + room.gx * cw + 4 * u, oy + room.gy * ch + 4 * u, cw - 8 * u, ch - 8 * u)
		draw_rect(rr, Color(accent.r, accent.g, accent.b, 0.12))
		draw_rect(rr, Color(accent.r, accent.g, accent.b, 0.7), false, maxf(1.0, 1.5 * u))
		var link := Color(accent.r, accent.g, accent.b, 0.8)
		if room.r:
			draw_line(Vector2(rr.end.x, rr.get_center().y + ch * 0.18), Vector2(rr.end.x + 8 * u, rr.get_center().y + ch * 0.18), link, 3 * u)
		if room.l:
			draw_line(Vector2(rr.position.x, rr.get_center().y + ch * 0.18), Vector2(rr.position.x - 8 * u, rr.get_center().y + ch * 0.18),
				link, 3 * u)
		if room.d >= 0:
			var dx: float = rr.position.x + (room.d + 2.0) / D.ROOM_W * rr.size.x
			draw_line(Vector2(dx, rr.end.y), Vector2(dx, rr.end.y + 8 * u), link, 3 * u)
		var mark: String = game.hud._room_mark(room)
		if room.kind == "treasure" or room.kind == "vault":
			mark = "C"
			for prp in game.props:
				if prp.kind == "chest" and not prp.open and rr.grow(8 * u).has_point(_map_pt(prp.pos, ox, oy, cw, ch)):
					mark = "C"
		if mark != "":
			var fs := int(22 * u)
			_text(Vector2(rr.get_center().x - _w(mark, fs, bold) * 0.5, rr.get_center().y + fs * 0.35), mark, fs, Color(1.0, 0.9, 0.6), bold)
	var me := _map_pt(pc, ox, oy, cw, ch)
	if int(t * 3.0) % 2 == 0:
		_text(me - Vector2(_w("@", int(20 * u), bold) * 0.5, -7 * u), "@", int(20 * u), Color(1, 1, 1), bold)
	_center(r.end.y - 30 * u, game.L("map_legend"), int(13 * u), Color(0.6, 0.66, 0.63))
	if not items.is_empty():
		items[0].rect = Rect2()


func _map_pt(wp: Vector2, ox: float, oy: float, cw: float, ch: float) -> Vector2:
	return Vector2(ox + wp.x / D.TILE / D.ROOM_W * cw, oy + wp.y / D.TILE / D.ROOM_H * ch)
