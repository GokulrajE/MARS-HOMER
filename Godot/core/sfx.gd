extends RefCounted
## Original, synthesized capture and miss sounds. Every game has its own voice so a session
## never sounds the same twice: Space Shooter booms, Match Catch plays a marimba run, Ping Pong
## pings, Diamond Catcher shimmers, Table Wiping squeaks clean, Reef Runner and Fish Rescue
## bloop, Character Flight picks up a coin, Bubble Sparkle pops and chimes. Misses are soft
## and low on purpose: they tell the patient "try the next one", never "wrong".
## Each capture comes in several pitch variants that are picked at random.
const RATE = 22050
const PENTATONIC = [1.0, 1.122, 1.26, 1.498, 1.682]
static var cache: Dictionary = {}

## A note: t start, d duration, f0 -> f1 glide (Hz), wave, vol, decay speed, vibrato depth.
static func note(t: float, d: float, f0: float, f1: float, wave: String, vol: float, decay: float = 5.0, vibrato: float = 0.0) -> Dictionary:
	return {"t": t, "d": d, "f0": f0, "f1": f1, "wave": wave, "vol": vol, "decay": decay, "vibrato": vibrato}

static func render(notes: Array, length: float) -> AudioStreamWAV:
	var count = int(length * RATE)
	var mix = PackedFloat32Array()
	mix.resize(count)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for item in notes:
		var start = int(item.t * RATE)
		var span = int(item.d * RATE)
		var phase = 0.0
		var low = 0.0
		for i in span:
			var at = start + i
			if at >= count: break
			var u = float(i) / maxf(1.0, span)
			var hz = item.f0 * pow(maxf(item.f1, 1.0) / maxf(item.f0, 1.0), u)
			if item.vibrato > 0.0: hz *= 1.0 + item.vibrato * sin(TAU * 6.0 * i / RATE)
			phase += TAU * hz / RATE
			var s = 0.0
			match item.wave:
				"sine": s = sin(phase)
				"bell": s = sin(phase) + 0.45 * sin(phase * 2.76) + 0.2 * sin(phase * 5.4)
				"tri": s = asin(sin(phase)) * 0.6366
				"square": s = 1.0 if sin(phase) >= 0.0 else -1.0
				"noise":
					# One-pole low-pass keeps the noise soft instead of hissy.
					low += (rng.randf_range(-1.0, 1.0) - low) * clampf(hz / 8000.0, 0.02, 1.0)
					s = low * 3.0
			var envelope = minf(float(i) / (RATE * 0.004), 1.0) * exp(-item.decay * u)
			mix[at] += s * envelope * item.vol
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in count: data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

## The sound for a captured target in `game`; variant picks the pitch (random when negative).
static func capture(game: String, variant: int = -1) -> AudioStreamWAV:
	var pick = variant if variant >= 0 else randi() % PENTATONIC.size()
	return cached(game + ":capture:" + str(pick), func(): return build_capture(game, PENTATONIC[pick % PENTATONIC.size()]))

static func miss(game: String, variant: int = -1) -> AudioStreamWAV:
	var pick = variant if variant >= 0 else randi() % 2
	return cached(game + ":miss:" + str(pick), func(): return build_miss(game, 1.0 + 0.12 * (pick % 2)))

static func cached(key: String, builder: Callable) -> AudioStreamWAV:
	if not cache.has(key): cache[key] = builder.call()
	return cache[key]

static func build_capture(game: String, p: float) -> AudioStreamWAV:
	match game:
		"MC": # marimba run up a triad
			return render([note(0.0, 0.22, 523.0 * p, 523.0 * p, "bell", 0.34, 6.0), note(0.07, 0.22, 659.0 * p, 659.0 * p, "bell", 0.32, 6.0), note(0.14, 0.4, 784.0 * p, 784.0 * p, "bell", 0.34, 5.0)], 0.6)
		"PP": # table-tennis ping
			return render([note(0.0, 0.3, 1320.0 * p, 1320.0 * p, "sine", 0.4, 7.0), note(0.0, 0.18, 1980.0 * p, 1980.0 * p, "sine", 0.18, 9.0)], 0.32)
		"DC": # crystal shimmer
			return render([note(0.0, 0.7, 1568.0 * p, 1568.0 * p, "bell", 0.2, 4.0, 0.004), note(0.05, 0.7, 2093.0 * p, 2093.0 * p, "bell", 0.16, 4.5, 0.004), note(0.1, 0.7, 2637.0 * p, 2637.0 * p, "bell", 0.12, 5.0, 0.004)], 0.85)
		"TW": # clean squeak and swish
			return render([note(0.0, 0.26, 600.0 * p, 1500.0 * p, "sine", 0.3, 4.0), note(0.0, 0.3, 3200.0, 5200.0, "noise", 0.16, 6.0)], 0.34)
		"TT", "FR": # water bloop
			return render([note(0.0, 0.16, 280.0 * p, 820.0 * p, "sine", 0.42, 5.0), note(0.11, 0.2, 420.0 * p, 1100.0 * p, "sine", 0.3, 5.0)], 0.34)
		"CB": # coin pickup
			return render([note(0.0, 0.08, 988.0 * p, 988.0 * p, "square", 0.12, 1.5), note(0.08, 0.34, 1319.0 * p, 1319.0 * p, "square", 0.12, 4.5)], 0.45)
		"BS": # pop then a chime
			return render([note(0.0, 0.1, 700.0, 180.0, "sine", 0.4, 6.0), note(0.0, 0.08, 2400.0, 800.0, "noise", 0.2, 7.0), note(0.07, 0.6, 1046.0 * p, 1046.0 * p, "bell", 0.2, 4.5)], 0.75)
		"FW": # sparkly burst
			return render([note(0.0, 0.5, 1800.0 * p, 700.0 * p, "noise", 0.22, 5.0), note(0.02, 0.5, 880.0 * p, 880.0 * p, "bell", 0.2, 5.0)], 0.55)
		_: # Space Shooter and anything else: a punchy low boom with a bright top
			return render([note(0.0, 0.4, 150.0 * p, 40.0, "sine", 0.55, 4.0), note(0.0, 0.3, 1400.0, 200.0, "noise", 0.32, 5.5), note(0.0, 0.12, 900.0 * p, 400.0, "square", 0.08, 5.0)], 0.45)

static func build_miss(game: String, p: float) -> AudioStreamWAV:
	match game:
		"MC": # wooden bonk
			return render([note(0.0, 0.2, 190.0 * p, 120.0, "tri", 0.45, 6.0), note(0.0, 0.03, 1600.0, 1000.0, "noise", 0.2, 3.0)], 0.24)
		"PP": # gentle womp-womp
			return render([note(0.0, 0.2, 330.0 * p, 240.0, "tri", 0.4, 3.0), note(0.2, 0.28, 262.0 * p, 170.0, "tri", 0.4, 3.5)], 0.5)
		"DC": # dull glass tink, falling
			return render([note(0.0, 0.3, 740.0 * p, 420.0, "bell", 0.2, 6.0)], 0.32)
		"TW": # soft slide down
			return render([note(0.0, 0.32, 520.0 * p, 240.0, "sine", 0.3, 3.5), note(0.0, 0.25, 1200.0, 500.0, "noise", 0.08, 5.0)], 0.34)
		"TT", "FR": # muffled blub
			return render([note(0.0, 0.2, 230.0 * p, 130.0, "sine", 0.42, 4.5), note(0.16, 0.18, 190.0 * p, 110.0, "sine", 0.3, 4.5)], 0.36)
		"CB": # airy whoosh
			return render([note(0.0, 0.4, 900.0, 220.0, "noise", 0.26, 4.0), note(0.0, 0.3, 440.0 * p, 200.0, "sine", 0.18, 4.0)], 0.42)
		"BS":
			return render([note(0.0, 0.3, 300.0 * p, 200.0, "sine", 0.25, 5.0)], 0.32)
		_: # Space Shooter: a low descending thud
			return render([note(0.0, 0.38, 200.0 * p, 70.0, "tri", 0.5, 3.5), note(0.0, 0.2, 500.0, 120.0, "noise", 0.18, 5.0)], 0.4)
