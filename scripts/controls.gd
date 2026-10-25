## Input actions with one rebindable key (or mouse button) and one rebindable
## gamepad button each, per-frame held / just pressed / released state and the
## last used device (so hints show the right buttons and the mouse can aim).
extends RefCounted

const ACTIONS := ["left", "right", "up", "down", "jump", "attack", "dash", "throw", "block", "swap", "slot1", "slot2", "slot3",
	"interact", "inventory", "map", "skills", "pause"]

## Actions in Settings → Controls: the keys 1-3 pick a weapon, so the swap to
## the next one lives on the gamepad only.
const KEY_ACTIONS := ["left", "right", "up", "down", "jump", "attack", "dash", "throw", "block", "slot1", "slot2", "slot3",
	"interact", "inventory", "map", "skills", "pause"]

## Actions in Settings → Gamepad: moving always follows the left stick and the d-pad.
const PAD_ACTIONS := ["jump", "attack", "dash", "throw", "block", "swap", "interact", "inventory", "map", "skills", "pause"]

## One rebindable key per action: "k:<physical keycode>" or "m:<mouse button>".
const DEFAULTS := {
	"left": "k:%d" % KEY_A,
	"right": "k:%d" % KEY_D,
	"up": "k:%d" % KEY_W,
	"down": "k:%d" % KEY_S,
	"jump": "k:%d" % KEY_SPACE,
	"attack": "m:%d" % MOUSE_BUTTON_LEFT,
	"dash": "k:%d" % KEY_SHIFT,
	"throw": "k:%d" % KEY_F,
	"block": "m:%d" % MOUSE_BUTTON_RIGHT,
	"swap": "",
	"slot1": "k:%d" % KEY_1,
	"slot2": "k:%d" % KEY_2,
	"slot3": "k:%d" % KEY_3,
	"interact": "k:%d" % KEY_E,
	"inventory": "k:%d" % KEY_TAB,
	"map": "k:%d" % KEY_M,
	"skills": "k:%d" % KEY_T,
	"pause": "k:%d" % KEY_ESCAPE,
}

## One rebindable gamepad input per action: "j:<button>" or "a:<axis>:<sign>" (a trigger).
const PAD_DEFAULTS := {
	"jump": "j:%d" % JOY_BUTTON_A,
	"attack": "j:%d" % JOY_BUTTON_X,
	"dash": "j:%d" % JOY_BUTTON_RIGHT_SHOULDER,
	"throw": "j:%d" % JOY_BUTTON_Y,
	"block": "a:%d:1" % JOY_AXIS_TRIGGER_LEFT,
	"swap": "j:%d" % JOY_BUTTON_LEFT_STICK,
	"interact": "j:%d" % JOY_BUTTON_B,
	"inventory": "j:%d" % JOY_BUTTON_BACK,
	"map": "j:%d" % JOY_BUTTON_RIGHT_STICK,
	"skills": "j:%d" % JOY_BUTTON_LEFT_SHOULDER,
	"pause": "j:%d" % JOY_BUTTON_START,
}

## Moving on the gamepad: [d-pad button, [stick axis, sign]].
const PAD_MOVE := {
	"left": [JOY_BUTTON_DPAD_LEFT, [JOY_AXIS_LEFT_X, -1]],
	"right": [JOY_BUTTON_DPAD_RIGHT, [JOY_AXIS_LEFT_X, 1]],
	"up": [JOY_BUTTON_DPAD_UP, [JOY_AXIS_LEFT_Y, -1]],
	"down": [JOY_BUTTON_DPAD_DOWN, [JOY_AXIS_LEFT_Y, 1]],
}

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_DPAD_UP: "D-pad ↑",
	JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}

const AXIS_NAMES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}

const KEY_GLYPHS := {KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓"}

var binds := {}
var pads := {}
var held := {}
var just := {}
var released := {}
var _prev := {}
## "keys", "mouse" or "pad".
var device := "keys"
var mouse_pos := Vector2.ZERO
var mouse_moved_t := 99.0


func setup(saved: Dictionary, saved_pad: Dictionary) -> void:
	binds = _load(DEFAULTS, saved, ["k:", "m:"])
	pads = _load(PAD_DEFAULTS, saved_pad, ["j:", "a:"])
	for a in ACTIONS:
		held[a] = false
		just[a] = false
		released[a] = false
		_prev[a] = false
	_apply()


## The defaults with the saved bindings over them. Bindings saved as two keys
## per action (before 0.12) keep the first one.
static func _load(defaults: Dictionary, saved: Dictionary, kinds: Array) -> Dictionary:
	var out := defaults.duplicate()
	for a in saved:
		var v = saved[a]
		if v is Array:
			v = v[0] if not v.is_empty() and str(v[0]) != "" else (v[1] if v.size() > 1 else "")
		if out.has(a) and (str(v) == "" or str(v).substr(0, 2) in kinds):
			out[a] = str(v)
	# actions added after the bindings were saved keep their default only when
	# no saved action already uses it
	for a in out:
		if saved.has(a) or saved.is_empty():
			continue
		for other in saved:
			if other != a and out.get(other, "") == out[a]:
				out[a] = ""
	return out


func _apply() -> void:
	for a in ACTIONS:
		var name: String = "g_" + a
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, 0.35)
		for b in [binds.get(a, ""), pads.get(a, "")]:
			var ev := _event(b)
			if ev != null:
				InputMap.action_add_event(name, ev)
		if PAD_MOVE.has(a):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD_MOVE[a][0]
			InputMap.action_add_event(name, jb)
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_MOVE[a][1][0]
			jm.axis_value = PAD_MOVE[a][1][1]
			InputMap.action_add_event(name, jm)


static func _event(b: String) -> InputEvent:
	if b.begins_with("k:"):
		var k := InputEventKey.new()
		k.physical_keycode = int(b.substr(2)) as Key
		return k
	if b.begins_with("m:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(b.substr(2)) as MouseButton
		return m
	if b.begins_with("j:"):
		var j := InputEventJoypadButton.new()
		j.button_index = int(b.substr(2)) as JoyButton
		return j
	if b.begins_with("a:"):
		var parts := b.split(":")
		var ax := InputEventJoypadMotion.new()
		ax.axis = int(parts[1]) as JoyAxis
		ax.axis_value = float(parts[2])
		return ax
	return null


## Turns a captured event into a binding string, or "" if it can't be bound.
static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return "k:%d" % code
	if ev is InputEventMouseButton:
		return "m:%d" % (ev as InputEventMouseButton).button_index
	return ""


## Turns a captured gamepad event into a binding string, or "" if it can't be
## bound (a stick, or a trigger pressed only lightly).
static func encode_pad(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton and ev.pressed:
		var btn: int = (ev as InputEventJoypadButton).button_index
		return "" if btn in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN] else "j:%d" % btn
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		if m.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and m.axis_value > 0.6:
			return "a:%d:1" % m.axis
	return ""


## Binds an action (on the gamepad when [pad]). The same input is taken off any other action.
func rebind(action: String, b: String, pad: bool = false) -> void:
	var table: Dictionary = pads if pad else binds
	if b != "":
		for a in table:
			if table[a] == b:
				table[a] = ""
	table[action] = b
	_apply()


func reset() -> void:
	binds = DEFAULTS.duplicate()
	pads = PAD_DEFAULTS.duplicate()
	_apply()


func poll(dt: float) -> void:
	mouse_moved_t += dt
	for a in ACTIONS:
		held[a] = Input.is_action_pressed("g_" + a)


## Treats everything currently held as already handled (after closing a menu).
func swallow() -> void:
	for a in ACTIONS:
		held[a] = Input.is_action_pressed("g_" + a)
		_prev[a] = held[a]
		just[a] = false


func latch() -> void:
	for a in ACTIONS:
		just[a] = held[a] and not _prev[a]
		released[a] = _prev[a] and not held[a]
		_prev[a] = held[a]


## Presses and releases count once per frame: later steps of the same frame
## (see main._step_frame) see the keys as held only.
func consume_presses() -> void:
	for a in ACTIONS:
		just[a] = false
		released[a] = false


## Tracks which kind of device was used last.
func note_event(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed:
		device = "keys"
	elif ev is InputEventMouseButton and ev.pressed:
		device = "mouse"
		mouse_moved_t = 0.0
	elif ev is InputEventMouseMotion:
		mouse_pos = (ev as InputEventMouseMotion).position
		if (ev as InputEventMouseMotion).relative.length() > 4.0 and Engine.get_process_frames() > 30:
			device = "mouse"
			mouse_moved_t = 0.0
	elif ev is InputEventJoypadButton and ev.pressed:
		device = "pad"
	elif ev is InputEventJoypadMotion and absf((ev as InputEventJoypadMotion).axis_value) > 0.5:
		device = "pad"


## Short label of a binding string, e.g. "Space", "LMB", "←", "RB".
static func bind_label(b: String, lang_mouse: Array) -> String:
	if b.begins_with("k:"):
		var code := int(b.substr(2))
		if KEY_GLYPHS.has(code):
			return KEY_GLYPHS[code]
		var shown := KEY_NONE
		if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
		var s := OS.get_keycode_string(shown if shown != KEY_NONE else code as Key)
		return s if s != "" else "?"
	if b.begins_with("m:"):
		var btn := int(b.substr(2))
		if btn >= 1 and btn <= lang_mouse.size():
			return lang_mouse[btn - 1]
		return "M%d" % btn
	if b.begins_with("j:"):
		return PAD_NAMES.get(int(b.substr(2)), "B%d" % int(b.substr(2)))
	if b.begins_with("a:"):
		return AXIS_NAMES.get(int(b.split(":")[1]), "?")
	return ""


## Label for the action on the device the player is using right now.
func label(action: String, lang_mouse: Array) -> String:
	if device == "pad":
		if PAD_MOVE.has(action):
			return "L-stick"
		var p: String = pads.get(action, "")
		return bind_label(p, lang_mouse) if p != "" else "—"
	var b: String = binds.get(action, "")
	return bind_label(b, lang_mouse) if b != "" else "—"
