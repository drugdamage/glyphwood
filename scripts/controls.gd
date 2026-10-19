## Input actions with rebindable keyboard and mouse bindings, fixed gamepad
## bindings, per-frame held / just pressed / released state and the last used
## device (so hints show the right buttons and the mouse can aim).
extends RefCounted

const ACTIONS := ["left", "right", "up", "down", "jump", "attack", "dash", "throw", "heal", "interact", "inventory", "map", "pause"]

## Two rebindable slots per action. "k:<physical keycode>" or "m:<mouse button>".
const DEFAULTS := {
	"left": ["k:%d" % KEY_A, "k:%d" % KEY_LEFT],
	"right": ["k:%d" % KEY_D, "k:%d" % KEY_RIGHT],
	"up": ["k:%d" % KEY_W, "k:%d" % KEY_UP],
	"down": ["k:%d" % KEY_S, "k:%d" % KEY_DOWN],
	"jump": ["k:%d" % KEY_SPACE, "k:%d" % KEY_Z],
	"attack": ["k:%d" % KEY_J, "m:%d" % MOUSE_BUTTON_LEFT],
	"dash": ["k:%d" % KEY_SHIFT, "m:%d" % MOUSE_BUTTON_RIGHT],
	"throw": ["k:%d" % KEY_K, "k:%d" % KEY_F],
	"heal": ["k:%d" % KEY_Q, "k:%d" % KEY_H],
	"interact": ["k:%d" % KEY_E, ""],
	"inventory": ["k:%d" % KEY_TAB, "k:%d" % KEY_I],
	"map": ["k:%d" % KEY_M, ""],
	"pause": ["k:%d" % KEY_ESCAPE, "k:%d" % KEY_P],
}

## Gamepad: [buttons], [[axis, sign]].
const PAD := {
	"left": [[JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1]]],
	"right": [[JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1]]],
	"up": [[JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1]]],
	"down": [[JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1]]],
	"jump": [[JOY_BUTTON_A], []],
	"attack": [[JOY_BUTTON_X], []],
	"dash": [[JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1]]],
	"throw": [[JOY_BUTTON_Y], []],
	"heal": [[JOY_BUTTON_LEFT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1]]],
	"interact": [[JOY_BUTTON_B], []],
	"inventory": [[JOY_BUTTON_BACK], []],
	"map": [[JOY_BUTTON_RIGHT_STICK], []],
	"pause": [[JOY_BUTTON_START], []],
}

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "D-pad ↑",
	JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}

const KEY_GLYPHS := {KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓"}

var binds := {}
var held := {}
var just := {}
var released := {}
var _prev := {}
## "keys", "mouse" or "pad".
var device := "keys"
var mouse_pos := Vector2.ZERO
var mouse_moved_t := 99.0


func setup(saved: Dictionary) -> void:
	binds = DEFAULTS.duplicate(true)
	for a in saved:
		if binds.has(a) and saved[a] is Array and saved[a].size() == 2:
			binds[a] = [str(saved[a][0]), str(saved[a][1])]
	for a in ACTIONS:
		held[a] = false
		just[a] = false
		released[a] = false
		_prev[a] = false
	_apply()


func _apply() -> void:
	for a in ACTIONS:
		var name: String = "g_" + a
		if InputMap.has_action(name):
			InputMap.erase_action(name)
		InputMap.add_action(name, 0.35)
		for b in binds[a]:
			var ev := _event(b)
			if ev != null:
				InputMap.action_add_event(name, ev)
		for btn in PAD[a][0]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = btn
			InputMap.action_add_event(name, jb)
		for ax in PAD[a][1]:
			var jm := InputEventJoypadMotion.new()
			jm.axis = ax[0]
			jm.axis_value = ax[1]
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


## Binds slot (0/1) of an action. The same input is removed from other actions.
func rebind(action: String, slot: int, b: String) -> void:
	if b != "":
		for a in ACTIONS:
			for i in 2:
				if binds[a][i] == b:
					binds[a][i] = ""
	binds[action][slot] = b
	_apply()


func reset() -> void:
	binds = DEFAULTS.duplicate(true)
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


## Short label of a binding string, e.g. "Space", "LMB", "←".
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
	return ""


## Label for the action on the device the player is using right now.
func label(action: String, lang_mouse: Array) -> String:
	if device == "pad":
		var btns: Array = PAD[action][0]
		if action in ["left", "right"]:
			return "L-stick"
		if action == "dash":
			return "RB"
		return PAD_NAMES.get(btns[0], "?") if not btns.is_empty() else "?"
	var b: Array = binds[action]
	if device == "mouse":
		for x in b:
			if str(x).begins_with("m:"):
				return bind_label(x, lang_mouse)
	for x in b:
		if str(x) != "":
			return bind_label(x, lang_mouse)
	return "—"
