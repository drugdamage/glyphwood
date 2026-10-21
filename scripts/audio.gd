## Procedural audio: every sound effect, music track and ambience loop is
## synthesised at startup (no audio files). Music and ambience are rendered on
## a background thread so the game never stalls.
extends Node

const RATE := 22050
const SFX_VOICES := 14

## Music: bpm, root (Hz), scale (semitones), chord progression (scale degrees), style.
const TRACKS := {
	"title": {"bpm": 56, "root": 98.0, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 5, 6, 4], "style": "bells", "bars": 8},
	"wood": {"bpm": 72, "root": 110.0, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 0, 4, 0, 5, 6, 4], "style": "calm", "bars": 16},
	"hollow": {"bpm": 64, "root": 82.41, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 5, 0, 6], "style": "bells", "bars": 8},
	"ember": {"bpm": 96, "root": 130.81, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 3, 4], "style": "drive", "bars": 8},
	"mire": {"bpm": 60, "root": 73.42, "scale": [0, 2, 3, 5, 7, 8, 10], "prog": [0, 3, 0, 4, 0, 3, 5, 4], "style": "pluck", "bars": 16},
	"cathedral": {"bpm": 54, "root": 65.41, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 5, 3, 4, 0, 5, 6, 4], "style": "bells", "bars": 16},
	"crypt": {"bpm": 66, "root": 92.5, "scale": [0, 1, 3, 5, 6, 8, 10], "prog": [0, 1, 0, 5], "style": "calm", "bars": 8},
	"boss": {"bpm": 136, "root": 110.0, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 0, 5, 6], "style": "boss", "bars": 8},
}

var sfx := {}
var tracks := {}
var ambience := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _music_old: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _want_music := ""
var _want_amb := ""
var _fade := 1.0
var _duck := 0.0
var _rng := RandomNumberGenerator.new()
var _pending: Array = []
var _thread: Thread


func setup() -> void:
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music = _player("Music")
	_music_old = _player("Music")
	_amb = _player("Ambience")
	_rng.seed = 1234
	_make_sfx()
	_pending = ["title", "wood", "hollow", "ember", "boss", "mire", "cathedral", "crypt"]
	_thread = Thread.new()
	_thread.start(_render_queue, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func set_volumes(master: float, music: float, fx: float, amb: float) -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", fx)
	_set_bus("Ambience", amb)


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


func set_muted(m: bool) -> void:
	AudioServer.set_bus_mute(0, m)


# ---------------------------------------------------------------- playback

func play(name: String, vol_db: float = 0.0, pitch: float = 1.0, vary: float = 0.06) -> void:
	if not sfx.has(name):
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = sfx[name]
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-vary, vary)))
	p.play()


func music(name: String) -> void:
	_want_music = name


func ambient(name: String) -> void:
	_want_amb = name


## 0..1, lowers music while menus are open.
func duck(amount: float) -> void:
	_duck = amount


func _process(dt: float) -> void:
	var cur := ""
	if _music.stream != null:
		cur = _music.get_meta("track", "")
	if _want_music != cur and (_want_music == "" or tracks.has(_want_music)):
		_music_old.stream = _music.stream
		_music_old.volume_db = _music.volume_db
		if _music.playing:
			_music_old.play(_music.get_playback_position())
		_music.stop()
		_music.stream = tracks.get(_want_music)
		_music.set_meta("track", _want_music)
		_fade = 0.0
		if _music.stream != null:
			_music.play()
	_fade = minf(1.0, _fade + dt * 0.5)
	var duck_db := -9.0 * _duck
	_music.volume_db = linear_to_db(maxf(_fade, 0.001)) + duck_db
	if _music_old.playing:
		_music_old.volume_db = linear_to_db(maxf(1.0 - _fade, 0.001)) + duck_db
		if _fade >= 1.0:
			_music_old.stop()
	var acur: String = _amb.get_meta("amb", "")
	if _want_amb != acur and (_want_amb == "" or ambience.has(_want_amb)):
		_amb.stream = ambience.get(_want_amb)
		_amb.set_meta("amb", _want_amb)
		if _amb.stream != null:
			_amb.play()
		else:
			_amb.stop()


# ---------------------------------------------------------------- helpers

static func _wav(buf: PackedFloat32Array, loop: bool = false, gain: float = 1.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := clampf(buf[i] * gain, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Frequency sweep tone. wave: 0 sine, 1 square, 2 saw, 3 triangle.
static func _tone(b: PackedFloat32Array, f0: float, f1: float, amp: float, wave: int, start: float = 0.0,
		dur: float = -1.0, attack: float = 0.004, curve: float = 4.0) -> void:
	var s0 := int(start * RATE)
	var n := b.size() - s0 if dur < 0.0 else mini(int(dur * RATE), b.size() - s0)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := lerpf(f0, f1, t)
		ph = fmod(ph + f / RATE, 1.0)
		var v := 0.0
		match wave:
			0: v = sin(ph * TAU)
			1: v = 1.0 if ph < 0.5 else -1.0
			2: v = ph * 2.0 - 1.0
			_: v = 1.0 - absf(ph * 4.0 - 2.0)
		var env := minf(1.0, float(i) / (attack * RATE)) * pow(1.0 - t, curve)
		b[s0 + i] += v * amp * env


## Filtered noise burst. cutoff 0..1 (one-pole low-pass coefficient), hp removes lows.
func _noise(b: PackedFloat32Array, amp: float, cutoff0: float, cutoff1: float, start: float = 0.0,
		dur: float = -1.0, hp: float = 0.0, curve: float = 3.0) -> void:
	var s0 := int(start * RATE)
	var n := b.size() - s0 if dur < 0.0 else mini(int(dur * RATE), b.size() - s0)
	var lp := 0.0
	var lo := 0.0
	for i in n:
		var t := float(i) / float(n)
		var c := lerpf(cutoff0, cutoff1, t)
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * c
		lo += (lp - lo) * 0.02
		var v := lp - lo * hp
		b[s0 + i] += v * amp * minf(1.0, float(i) / 40.0) * pow(1.0 - t, curve)


# ---------------------------------------------------------------- effects

func _make_sfx() -> void:
	var b := _buf(0.12)
	_tone(b, 260, 620, 0.32, 1, 0, -1, 0.002, 2.0)
	_noise(b, 0.15, 0.5, 0.2, 0, 0.05)
	sfx.jump = _wav(b)

	b = _buf(0.1)
	_noise(b, 0.7, 0.25, 0.05)
	_tone(b, 120, 50, 0.4, 0)
	sfx.land = _wav(b)

	b = _buf(0.05)
	_noise(b, 0.35, 0.35, 0.1)
	sfx.step = _wav(b)

	b = _buf(0.22)
	_noise(b, 0.6, 0.15, 0.6, 0, -1, 1.0, 1.5)
	sfx.dash = _wav(b)

	b = _buf(0.13)
	_noise(b, 0.55, 0.2, 0.75, 0, -1, 1.0, 2.0)
	_tone(b, 900, 500, 0.06, 2)
	sfx.swing = _wav(b)

	b = _buf(0.16)
	_noise(b, 0.8, 0.7, 0.1)
	_tone(b, 180, 60, 0.6, 0)
	_tone(b, 1400, 700, 0.12, 1, 0, 0.03)
	sfx.hit = _wav(b)

	b = _buf(0.32)
	_noise(b, 0.6, 0.6, 0.05)
	_tone(b, 420, 70, 0.3, 1, 0, -1, 0.002, 1.5)
	sfx.kill = _wav(b)

	b = _buf(0.3)
	_tone(b, 240, 90, 0.4, 2, 0, -1, 0.002, 1.5)
	_noise(b, 0.6, 0.5, 0.1, 0, 0.2)
	sfx.hurt = _wav(b)

	b = _buf(0.18)
	_tone(b, 1568, 1568, 0.22, 0, 0, -1, 0.001, 3.0)
	_tone(b, 2352, 2352, 0.1, 0, 0, -1, 0.001, 4.0)
	sfx.shard = _wav(b)

	b = _buf(0.3)
	_tone(b, 660, 660, 0.25, 3, 0, 0.12)
	_tone(b, 990, 990, 0.25, 3, 0.1, 0.2)
	sfx.heart = _wav(b)

	b = _buf(0.6)
	for i in 5:
		_tone(b, 440.0 * pow(1.26, i), 440.0 * pow(1.26, i), 0.16, 0, i * 0.07, 0.35, 0.01, 2.0)
	_noise(b, 0.08, 0.6, 0.6, 0, -1, 1.0, 2.0)
	sfx.heal = _wav(b)

	b = _buf(0.7)
	_noise(b, 0.4, 0.08, 0.02, 0, 0.25)
	_tone(b, 90, 70, 0.3, 2, 0, 0.25)
	for i in 4:
		_tone(b, 880.0 * pow(1.19, i), 880.0 * pow(1.19, i), 0.14, 0, 0.2 + i * 0.07, 0.4, 0.002, 3.0)
	sfx.chest = _wav(b)

	b = _buf(0.9)
	for i in 3:
		var f: float = 523.25 * [1.0, 1.26, 1.5][i]
		_tone(b, f, f, 0.2, 3, i * 0.11, 0.7, 0.005, 2.5)
		_tone(b, f * 2.0, f * 2.0, 0.06, 0, i * 0.11, 0.5)
	sfx.item = _wav(b)

	b = _buf(1.0)
	_noise(b, 0.5, 0.03, 0.12, 0, -1, 0.0, 1.5)
	_tone(b, 330, 660, 0.15, 0, 0.1, 0.8, 0.2, 2.0)
	sfx.door = _wav(b)

	b = _buf(0.04)
	_tone(b, 1800, 1800, 0.15, 1, 0, -1, 0.001, 3.0)
	sfx.menu_move = _wav(b)

	b = _buf(0.14)
	_tone(b, 880, 880, 0.18, 1, 0, 0.06)
	_tone(b, 1320, 1320, 0.18, 1, 0.06, 0.08)
	sfx.menu_ok = _wav(b)

	b = _buf(0.12)
	_tone(b, 660, 330, 0.18, 1)
	sfx.menu_back = _wav(b)

	b = _buf(0.14)
	_tone(b, 1200, 2400, 0.12, 0)
	_noise(b, 0.3, 0.3, 0.7, 0, -1, 1.0, 2.0)
	sfx.throw = _wav(b)

	b = _buf(0.18)
	_tone(b, 900, 250, 0.2, 1, 0, -1, 0.002, 2.0)
	sfx.fire = _wav(b)

	b = _buf(0.7)
	_noise(b, 1.0, 0.5, 0.02, 0, -1, 0.0, 2.0)
	_tone(b, 90, 30, 0.7, 0, 0, -1, 0.002, 2.0)
	sfx.explode = _wav(b)

	b = _buf(0.3)
	for f in [1870.0, 2730.0, 3410.0]:
		_tone(b, f, f, 0.12, 0, 0, -1, 0.001, 5.0)
	_noise(b, 0.2, 0.9, 0.5, 0, 0.03)
	sfx.clink = _wav(b)

	b = _buf(0.14)
	_tone(b, 300, 900, 0.25, 3, 0, -1, 0.002, 2.0)
	sfx.pogo = _wav(b)

	b = _buf(1.3)
	_tone(b, 70, 55, 0.45, 2, 0, -1, 0.15, 1.2)
	_tone(b, 105, 82, 0.25, 2, 0, -1, 0.15, 1.2)
	_noise(b, 0.4, 0.1, 0.04, 0, -1, 0.0, 1.0)
	sfx.roar = _wav(b)

	b = _buf(0.5)
	_noise(b, 1.0, 0.3, 0.02, 0, -1, 0.0, 2.5)
	_tone(b, 70, 35, 0.8, 0)
	sfx.slam = _wav(b)

	b = _buf(0.6)
	for f in [220.0, 331.0, 497.0]:
		_tone(b, f, f * 0.98, 0.15, 2, 0, -1, 0.001, 3.0)
	_noise(b, 0.4, 0.4, 0.1, 0, 0.1)
	sfx.gate = _wav(b)

	b = _buf(0.4)
	for i in 5:
		_noise(b, 0.6, 0.5, 0.1, i * 0.06, 0.12)
	sfx.crumble = _wav(b)

	b = _buf(1.4)
	for f in [261.6, 329.6, 392.0, 523.3]:
		_tone(b, f, f, 0.1, 3, 0, -1, 0.3, 1.5)
		_tone(b, f * 1.005, f * 1.005, 0.06, 0, 0, -1, 0.3, 1.5)
	sfx.shrine = _wav(b)

	b = _buf(0.3)
	_tone(b, 1320, 1320, 0.15, 0, 0, 0.1)
	_tone(b, 1760, 1760, 0.15, 0, 0.08, 0.2)
	sfx.buy = _wav(b)

	b = _buf(0.16)
	_tone(b, 140, 120, 0.25, 1)
	sfx.error = _wav(b)

	b = _buf(0.3)
	_noise(b, 0.6, 0.6, 0.1, 0, -1, 1.0, 2.0)
	sfx.splash = _wav(b)

	b = _buf(0.1)
	_noise(b, 0.4, 0.4, 0.2, 0, -1, 0.5, 2.0)
	_tone(b, 400, 700, 0.12, 3)
	sfx.wall = _wav(b)

	b = _buf(0.2)
	_tone(b, 1250, 1250, 0.14, 1, 0, 0.06)
	_tone(b, 1250, 1250, 0.14, 1, 0.1, 0.06)
	sfx.tele = _wav(b)

	b = _buf(1.6)
	for i in 4:
		var f := 220.0 * pow(0.84, i)
		_tone(b, f, f * 0.97, 0.22, 2, i * 0.28, 0.6, 0.01, 1.5)
	sfx.death = _wav(b)

	b = _buf(1.8)
	for i in 6:
		var f: float = 392.0 * [1.0, 1.26, 1.5, 2.0, 1.5, 2.0][i]
		_tone(b, f, f, 0.18, 3, i * 0.13, 0.9 if i == 5 else 0.3, 0.005, 2.0)
	sfx.victory = _wav(b)
	# a funeral bell: a low strike with inharmonic partials that ring on
	b = _buf(1.4)
	for pr in [[1.0, 0.3], [2.4, 0.14], [3.0, 0.1], [4.2, 0.06]]:
		_tone(b, 196.0 * pr[0], 196.0 * pr[0] * 0.995, pr[1], 0, 0, -1, 0.002, 2.5)
	sfx.bell = _wav(b)


# ---------------------------------------------------------------- music

## Runs on the background thread: renders every track, then the ambience
## loops, handing each one to the main thread as soon as it is ready.
func _render_queue() -> void:
	for name in _pending:
		var buf: PackedFloat32Array = _compose(name)
		_store.call_deferred(true, name, _wav(buf, true, 0.8))
	for name in ["wood", "hollow", "ember", "mire", "cathedral", "crypt"]:
		_store.call_deferred(false, name, _wav(_make_ambience(name), true, 0.9))


func _store(is_track: bool, name: String, w: AudioStreamWAV) -> void:
	if is_track:
		tracks[name] = w
	else:
		ambience[name] = w


func _freq(tr: Dictionary, degree: int, octave: int) -> float:
	var sc: Array = tr.scale
	var o := octave + int(floor(float(degree) / sc.size()))
	var semi: int = sc[posmod(degree, sc.size())] + 12 * o
	return tr.root * pow(2.0, semi / 12.0)


func _compose(name: String) -> PackedFloat32Array:
	var tr: Dictionary = TRACKS[name]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var beat := 60.0 / float(tr.bpm)
	var bar := beat * 4.0
	var bars: int = tr.bars
	var total := bar * bars
	var b := _buf(total)
	var style: String = tr.style
	var prog: Array = tr.prog
	for bi in bars:
		var deg: int = prog[bi % prog.size()]
		var t0 := bi * bar
		# pad chord
		var pad_amp := 0.05 if style == "boss" else 0.075
		for k in 3:
			_pad(b, t0, bar * 1.05, _freq(tr, deg + k * 2, 1), pad_amp, total)
		# bass
		if style == "boss" or style == "drive":
			for e in 8:
				var bf := _freq(tr, deg, -1 if style == "drive" else 0)
				if e % 4 == 3:
					bf = _freq(tr, deg + 4, -1 if style == "drive" else 0)
				_pluck(b, t0 + e * beat * 0.5, bf, beat * 0.5, 0.3, total, 0.97, rng)
		else:
			_bass(b, t0, _freq(tr, deg, 0), bar * 0.95, 0.16, total)
		# arpeggio / melody
		match style:
			"pluck", "calm":
				var steps := 8 if style == "pluck" else 4
				for e in steps:
					if rng.randf() < (0.8 if style == "pluck" else 0.6):
						var d: int = deg + [0, 2, 4, 7, 4, 2, 7, 9][(e + bi) % 8]
						_pluck(b, t0 + e * bar / steps, _freq(tr, d, 2), bar / steps * 2.0, 0.17, total, 0.996, rng)
				if rng.randf() < 0.6:
					var md: int = deg + [4, 7, 9, 11][rng.randi_range(0, 3)]
					_bell(b, t0 + beat * rng.randi_range(0, 3), _freq(tr, md, 3), 1.6, 0.05, total)
			"bells":
				for e in 4:
					if rng.randf() < 0.55:
						var d2: int = deg + [0, 2, 4, 6, 7][rng.randi_range(0, 4)]
						_bell(b, t0 + e * beat + rng.randf() * 0.1, _freq(tr, d2, 2), 2.5, 0.07, total)
			"drive", "boss":
				for e in 8:
					if rng.randf() < 0.55:
						var d3: int = deg + [0, 2, 4, 7][rng.randi_range(0, 3)]
						_pluck(b, t0 + e * beat * 0.5, _freq(tr, d3, 2), beat, 0.11, total, 0.994, rng)
		# drums
		if style == "boss" or style == "drive":
			for q in 4:
				_kick(b, t0 + q * beat, 0.5 if style == "boss" else 0.35, total)
				if q % 2 == 1:
					_snare(b, t0 + q * beat, 0.22 if style == "boss" else 0.12, total)
				for h in 2:
					_hat(b, t0 + q * beat + h * beat * 0.5, 0.06, total)
		elif style == "bells" and bi % 2 == 0:
			_kick(b, t0, 0.2, total)
	_reverb(b, 0.32 if style != "boss" else 0.18)
	return b


## Adds a note, wrapping around the loop end so tails continue at the start.
static func _wrap_add(b: PackedFloat32Array, idx: int, v: float) -> void:
	var n := b.size()
	b[idx % n] += v


func _pluck(b: PackedFloat32Array, start: float, f: float, dur: float, amp: float, _total: float, decay: float,
		rng: RandomNumberGenerator) -> void:
	var period := maxi(2, int(RATE / f))
	var ring := PackedFloat32Array()
	ring.resize(period)
	var lp := 0.0
	for i in period:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
		ring[i] = lp
	var s0 := int(start * RATE)
	var n := int((dur + 0.6) * RATE)
	var idx := 0
	for i in n:
		var cur := ring[idx]
		var nxt := ring[(idx + 1) % period]
		ring[idx] = (cur + nxt) * 0.5 * decay
		_wrap_add(b, s0 + i, cur * amp)
		idx = (idx + 1) % period


static func _pad(b: PackedFloat32Array, start: float, dur: float, f: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int((dur + 0.8) * RATE)
	var att := 0.5 * RATE
	var rel_at := dur * RATE
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var inc1 := f / RATE
	var inc2 := f * 1.004 / RATE
	var inc3 := f * 2.0 / RATE
	for i in n:
		p1 += inc1
		p2 += inc2
		p3 += inc3
		var env := minf(1.0, i / att)
		if i > rel_at:
			env *= maxf(0.0, 1.0 - (i - rel_at) / (0.8 * RATE))
		var v := sin(p1 * TAU) + sin(p2 * TAU) * 0.8 + sin(p3 * TAU) * 0.15
		_wrap_add(b, s0 + i, v * amp * env)


static func _bass(b: PackedFloat32Array, start: float, f: float, dur: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		ph = fmod(ph + f / RATE, 1.0)
		var tri := 1.0 - absf(ph * 4.0 - 2.0)
		var env := minf(1.0, i / 200.0) * (1.0 - float(i) / n)
		_wrap_add(b, s0 + i, tri * amp * env)


static func _bell(b: PackedFloat32Array, start: float, f: float, dur: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 2.5) * minf(1.0, i / 30.0)
		var v := sin(t * f * TAU) + sin(t * f * 2.76 * TAU) * 0.35 + sin(t * f * 5.4 * TAU) * 0.12 * exp(-t * 6.0)
		_wrap_add(b, s0 + i, v * amp * env)


static func _kick(b: PackedFloat32Array, start: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int(0.25 * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += lerpf(130.0, 40.0, sqrt(t)) / RATE
		_wrap_add(b, s0 + i, sin(ph * TAU) * amp * pow(1.0 - t, 2.0))


func _snare(b: PackedFloat32Array, start: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int(0.18 * RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.6
		_wrap_add(b, s0 + i, (lp + sin(t * 0.18 * 190.0 * TAU) * 0.4) * amp * pow(1.0 - t, 3.0))


func _hat(b: PackedFloat32Array, start: float, amp: float, _total: float) -> void:
	var s0 := int(start * RATE)
	var n := int(0.05 * RATE)
	var prev := 0.0
	for i in n:
		var x := _rng.randf_range(-1.0, 1.0)
		_wrap_add(b, s0 + i, (x - prev) * amp * (1.0 - float(i) / n))
		prev = x


## Two feedback delays run twice around the loop so the tail wraps seamlessly.
func _reverb(b: PackedFloat32Array, mix: float) -> void:
	var n := b.size()
	var d1 := int(0.137 * RATE)
	var d2 := int(0.229 * RATE)
	var wet := PackedFloat32Array()
	wet.resize(n)
	for pass_i in 2:
		for i in n:
			wet[i] = b[i] * 0.5 + wet[(i - d1 + n) % n] * 0.45 + wet[(i - d2 + n) % n] * 0.3
	for i in n:
		b[i] = b[i] + wet[i] * mix


func _make_ambience(name: String) -> PackedFloat32Array:
	var b := _buf(8.0)
	var n := b.size()
	var lp := 0.0
	var lp2 := 0.0
	# two passes so the filtered noise loops without a seam
	for pass_i in 2:
		for i in n:
			var t := float(i) / RATE
			var swell := 0.6 + 0.4 * sin(t / 8.0 * TAU)
			match name:
				"wood":
					lp += (randf_range(-1.0, 1.0) - lp) * 0.06
					lp2 += (lp - lp2) * 0.5
					if pass_i == 1:
						b[i] = lp2 * 0.5 * swell
				"hollow", "cathedral":
					lp += (randf_range(-1.0, 1.0) - lp) * 0.012
					if pass_i == 1:
						b[i] = lp * 1.2 * swell + sin(t * (55.0 if name == "hollow" else 41.2) * TAU) * 0.035
				"mire":
					lp += (randf_range(-1.0, 1.0) - lp) * 0.03
					lp2 += (lp - lp2) * 0.3
					if pass_i == 1:
						b[i] = lp2 * 0.7 * swell
				"crypt":
					# a thin wind that howls through the vaults
					lp += (randf_range(-1.0, 1.0) - lp) * (0.04 + 0.03 * sin(t / 8.0 * TAU * 2.0))
					if pass_i == 1:
						b[i] = lp * 1.1 * swell
				_:
					lp += (randf_range(-1.0, 1.0) - lp) * 0.02
					if pass_i == 1:
						b[i] = lp * 1.3 * swell
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"wood":
			for k in 7:
				var t0 := rng.randf_range(0.0, 7.5)
				var f := rng.randf_range(2200.0, 3600.0)
				for c in rng.randi_range(2, 4):
					_tone(b, f, f * 1.25, 0.05, 0, t0 + c * 0.11, 0.07, 0.005, 2.0)
		"mire":
			# frogs croaking in the reeds
			for k in 9:
				var t2 := rng.randf_range(0.0, 7.4)
				var f3 := rng.randf_range(110.0, 190.0)
				for c in rng.randi_range(2, 3):
					_tone(b, f3, f3 * 0.8, 0.09, 0, t2 + c * 0.16, 0.1, 0.004, 1.0)
		"cathedral":
			# water dripping from the vaults
			for k in 10:
				var t3 := rng.randf_range(0.0, 7.6)
				var f4 := rng.randf_range(1400.0, 2400.0)
				_tone(b, f4, f4 * 0.6, 0.07, 0, t3, 0.06, 0.001, 2.0)
		"crypt":
			# ice cracking somewhere
			for k in 12:
				var i1 := int(rng.randf_range(0.0, 7.9) * RATE)
				for j in 60:
					b[(i1 + j) % n] += rng.randf_range(-0.35, 0.35) * (1.0 - j / 60.0) * (1.0 if j % 7 < 3 else 0.2)
		"hollow":
			for k in 6:
				var t1 := rng.randf_range(0.0, 7.5)
				var f2 := rng.randf_range(900.0, 1500.0)
				_tone(b, f2 * 1.4, f2, 0.08, 0, t1, 0.12, 0.001, 3.0)
				_tone(b, f2 * 1.4, f2, 0.025, 0, t1 + 0.3, 0.12, 0.001, 3.0)
		_:
			for k in 40:
				var i0 := int(rng.randf_range(0.0, 7.9) * RATE)
				for j in 30:
					b[(i0 + j) % n] += rng.randf_range(-0.25, 0.25) * (1.0 - j / 30.0)
	return b
