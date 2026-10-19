## Player settings and profile, stored in user://settings.cfg and user://profile.cfg.
## main.gd applies them (window, audio, effects) whenever a value changes.
extends RefCounted

const PATH := "user://settings.cfg"
const PROFILE_PATH := "user://profile.cfg"

const FPS_CHOICES := [30, 60, 120, 144, 240, 0]
const WINDOW_CHOICES := ["windowed", "borderless", "fullscreen"]

const DEFAULTS := {
	"lang": "",
	"hints": true,
	"damage_numbers": true,
	"shake": 1.0,
	"mouse_aim": true,
	"window": "windowed",
	"vsync": true,
	"fps": 0,
	"zoom": 1,
	"glow": true,
	"lighting": true,
	"scanlines": true,
	"vignette": true,
	"show_fps": false,
	"ui_scale": 1.0,
	"vol_master": 0.8,
	"vol_music": 0.6,
	"vol_sfx": 0.8,
	"vol_amb": 0.6,
	"mute_unfocused": true,
	"binds": {},
}

var values := {}
var profile := {"hints_seen": {}, "runs": 0, "wins": 0, "best_level": 0, "kills": 0, "best_time": 0.0}


func load_all() -> void:
	values = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("settings", k):
				var v = cf.get_value("settings", k)
				if typeof(v) == typeof(DEFAULTS[k]) or (DEFAULTS[k] is float and v is int):
					values[k] = v
	var pf := ConfigFile.new()
	if pf.load(PROFILE_PATH) == OK:
		for k in profile:
			if pf.has_section_key("profile", k):
				profile[k] = pf.get_value("profile", k)


func save() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)


func save_profile() -> void:
	var pf := ConfigFile.new()
	for k in profile:
		pf.set_value("profile", k, profile[k])
	pf.save(PROFILE_PATH)


func get_v(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_v(key: String, v: Variant) -> void:
	values[key] = v
	save()


func hint_seen(id: String) -> bool:
	return profile.hints_seen.has(id)


func mark_hint(id: String) -> void:
	profile.hints_seen[id] = true
	save_profile()


func reset_hints() -> void:
	profile.hints_seen = {}
	save_profile()
