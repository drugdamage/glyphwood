## Tutorial hints shown at the top of the screen. Each hint appears when it
## becomes relevant and disappears for good once the player does the thing.
## They can be turned off or reset in Settings → Game.
extends RefCounted

const Physics := preload("res://scripts/physics.gd")
const Level := preload("res://scripts/level.gd")


## Returns the id of the hint to show now, or "". Also marks finished hints.
static func update(g, dt: float) -> String:
	if not g.cfg.get_v("hints") or g.player.is_empty() or g.player.dead:
		return ""
	var p: Dictionary = g.player
	var just: Dictionary = g.ctl.just
	var h: Dictionary = g.hint_state
	var c := Physics.center(p)
	h.t = h.get("t", 0.0) + dt
	_done_if(g, "move", absf(c.x - g.lv.start.x) > 80.0)
	_done_if(g, "jump", just.jump)
	_done_if(g, "attack", just.attack)
	_done_if(g, "dash", just.dash)
	_done_if(g, "wall", p.sliding and just.jump)
	_done_if(g, "combo", p.atk_kind == "side" and p.combo == 2 and p.atk_t > 0.0)
	_done_if(g, "lunge", p.atk_kind == "lunge" and p.atk_t > 0.0)
	_done_if(g, "rise", p.atk_kind == "rise" and p.atk_t > 0.0)
	_done_if(g, "throw", just.throw)
	_done_if(g, "interact", just.interact)
	_done_if(g, "inventory", g.menu.is_open("inventory"))
	_done_if(g, "map", g.menu.is_open("map"))
	_done_if(g, "drop", just.jump and g.ctl.held.down)
	# timed hints disappear after a few seconds
	for id in ["down", "shield", "drop", "map", "elite", "guide", "lantern", "xp", "regen"]:
		if h.get("since_" + id, -1.0) >= 0.0:
			h["since_" + id] += dt
			if h["since_" + id] > 7.0:
				g.cfg.mark_hint(id)
	var near_enemy := false
	for e in g.enemies:
		if Physics.center(e).distance_to(c) < 170.0:
			near_enemy = true
			if e.kind == "shield":
				_start(h, "shield")
			if e.elite:
				_start(h, "elite")
	if g.kills >= 1:
		_start(h, "down")
	if p.on_floor and _on_oneway(g, p):
		_start(h, "drop")
	if g.rooms_seen >= 2:
		_start(h, "map")
	if h.t > 6.0 and g.cfg.get_v("guide"):
		_start(h, "guide")
	if g.checkpoint_prop.has("lit") and not g.checkpoint_prop.get("start", false):
		_start(h, "lantern")
	if g.kills >= 2:
		_start(h, "xp")
	if p.hp < p.max_hp * 0.7 and p.calm > 2.0:
		_start(h, "regen")
	var order := [
		["move", true], ["jump", h.t > 3.0], ["attack", near_enemy], ["wall", p.sliding],
		["interact", not g.near.is_empty()], ["guide", h.has("since_guide")], ["lantern", h.has("since_lantern")],
		["combo", g.kills >= 1], ["regen", h.has("since_regen")], ["xp", h.has("since_xp")],
		["inventory", g.items_found > 0], ["throw", p.ink >= 33.0], ["dash", h.t > 14.0],
		["lunge", g.cfg.hint_seen("dash") and g.kills >= 3], ["rise", g.kills >= 5],
		["shield", h.has("since_shield")], ["elite", h.has("since_elite")], ["down", h.has("since_down")],
		["drop", h.has("since_drop")], ["map", h.has("since_map")],
	]
	for o in order:
		if o[1] and not g.cfg.hint_seen(o[0]):
			return o[0]
	return ""


static func _done_if(g, id: String, cond: bool) -> void:
	if cond and not g.cfg.hint_seen(id):
		g.cfg.mark_hint(id)


static func _start(h: Dictionary, id: String) -> void:
	if not h.has("since_" + id):
		h["since_" + id] = 0.0


static func _on_oneway(g, p: Dictionary) -> bool:
	var T: float = 16.0
	var ty := int(floor((p.pos.y + p.size.y + 1.0) / T))
	return g.lv.at(int(floor(Physics.center(p).x / T)), ty) == Level.ONEWAY
