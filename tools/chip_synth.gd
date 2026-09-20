extends RefCounted
## Offline authoring only: deterministic pulse/triangle/noise synthesizer. Effects use an 8-bit
## amplitude grid in a 16-bit WAV container for consistent platform playback.
## PolyBLEP pulse edges, a low-pass and short fades keep the chip tone gentle.

const RATE := 22050
const RECIPES := {
	"click": {"seconds": 0.065, "from": 880.0, "to": 580.0, "duty": 0.125, "noise": 0.03, "gain": 0.7},
	"coin": {"seconds": 0.23, "notes": [987.77, 1318.51], "duty": 0.25, "decay": 0.6, "gain": 0.84},
	"clip": {"seconds": 0.29, "notes": [523.25, 659.25, 783.99, 1046.5], "duty": 0.25, "decay": 0.5},
	"hit": {"seconds": 0.085, "from": 210.0, "to": 62.0, "wave": "triangle", "noise": 0.55, "noise_from": 6200.0, "noise_to": 1400.0, "decay": 1.7},
	"swing": {"seconds": 0.095, "from": 330.0, "to": 100.0, "noise": 0.8, "noise_from": 3600.0, "noise_to": 700.0, "gain": 0.75},
	"shot": {"seconds": 0.095, "from": 1180.0, "to": 220.0, "duty": 0.125, "noise": 0.12, "decay": 1.3, "gain": 0.86},
	"dash": {"seconds": 0.14, "from": 240.0, "to": 850.0, "duty": 0.25, "noise": 0.7, "noise_from": 1000.0, "noise_to": 5800.0, "gain": 0.84},
	"hurt": {"seconds": 0.2, "from": 190.0, "to": 48.0, "duty": 0.5, "noise": 0.42, "noise_from": 3000.0, "noise_to": 500.0, "decay": 0.8},
	"kill": {"seconds": 0.14, "notes": [392.0, 587.33, 783.99], "duty": 0.125, "decay": 0.9, "gain": 0.86},
	"stomp": {"seconds": 0.24, "from": 112.0, "to": 32.0, "wave": "triangle", "noise": 0.55, "noise_from": 3800.0, "noise_to": 350.0, "cutoff": 3000.0},
	"slam": {"seconds": 0.33, "from": 160.0, "to": 30.0, "wave": "triangle", "noise": 0.7, "noise_from": 6500.0, "noise_to": 420.0, "cutoff": 3400.0, "decay": 0.85},
	"jet_launch": {"seconds": 0.32, "from": 110.0, "to": 980.0, "duty": 0.125, "noise": 0.5, "noise_from": 700.0, "noise_to": 4200.0, "attack": 0.012, "decay": 0.5, "gain": 0.88},
	"bottle_throw": {"seconds": 0.2, "from": 640.0, "to": 170.0, "wave": "triangle", "noise": 0.18, "noise_from": 1800.0, "noise_to": 550.0, "gain": 0.85},
	"bottle_break": {"seconds": 0.23, "from": 1760.0, "to": 440.0, "duty": 0.125, "noise": 0.85, "noise_from": 8800.0, "noise_to": 1600.0, "decay": 1.5, "cutoff": 4200.0},
	"special": {"seconds": 0.36, "notes": [196.0, 293.66, 392.0, 587.33, 783.99], "wave": "triangle", "noise": 0.2, "decay": 0.5},
	"start": {"seconds": 0.25, "notes": [261.63, 392.0, 523.25], "duty": 0.25, "decay": 0.5, "gain": 0.85},
	"knock": {"seconds": 0.43, "from": 135.0, "to": 90.0, "wave": "triangle", "noise": 0.4, "noise_from": 2100.0, "noise_to": 950.0, "pulses": 2, "decay": 1.6},
	"win": {"seconds": 0.64, "notes": [523.25, 659.25, 783.99, 1046.5], "duty": 0.25, "decay": 0.4, "gain": 0.92},
	"lose": {"seconds": 0.58, "notes": [392.0, 369.99, 293.66, 196.0], "wave": "triangle", "decay": 0.65, "gain": 0.92},
}

static func make(sound: String, gain: float = 0.22) -> AudioStreamWAV:
	var key: String = {"jetpack": "jet_launch", "bottle": "bottle_break"}.get(sound, sound)
	var spec: Dictionary = RECIPES.get(key, RECIPES["click"])
	var duration: float = spec["seconds"]
	var frames := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase := 0.0
	var noise_phase := 0.0
	var noise := 0.0
	var filtered := 0.0
	var lfsr := 0x4A3D
	var notes: Array = spec.get("notes", [])
	var attack: float = spec.get("attack", 0.003)
	var release: float = minf(0.025, duration * 0.3)
	var duty: float = spec.get("duty", 0.5)
	var noise_mix: float = spec.get("noise", 0.0)
	var alpha: float = 1.0 - exp(-TAU * float(spec.get("cutoff", 4600.0)) / RATE)
	var amplitude: float = clampf(gain, 0.0, 0.4) * float(spec.get("gain", 1.0))
	for index in frames:
		var t := float(index) / RATE
		var progress := float(index) / float(frames - 1)
		var hz: float = lerpf(float(spec.get("from", 440.0)), float(spec.get("to", 440.0)), progress)
		var envelope := minf(t / attack, 1.0) * minf((duration - t) / release, 1.0)
		envelope *= pow(1.0 - progress, float(spec.get("decay", 1.0)))
		if not notes.is_empty():
			var note_duration := duration / notes.size()
			var note_time := fmod(t, note_duration)
			hz = notes[mini(int(t / note_duration), notes.size() - 1)]
			# A brief fade between notes prevents hard frequency-change clicks.
			envelope *= minf(note_time / 0.002, 1.0) * minf((note_duration - note_time) / 0.007, 1.0)
		if spec.has("pulses"):
			var pulse_time := fmod(t, duration / int(spec["pulses"]))
			envelope *= minf(pulse_time / attack, 1.0) * exp(-pulse_time * 28.0)
		var increment := hz / RATE
		phase = fmod(phase + increment, 1.0)
		var tone := 0.0
		if spec.get("wave", "pulse") == "triangle":
			tone = roundf((1.0 - 4.0 * absf(phase - 0.5)) * 15.0) / 15.0
		else:
			tone = (1.0 if phase < duty else -1.0) + 1.0 - 2.0 * duty
			tone += _blep(phase, increment) - _blep(fmod(phase - duty + 1.0, 1.0), increment)
			tone /= 2.0 * maxf(duty, 1.0 - duty)
		noise_phase += lerpf(float(spec.get("noise_from", 4000.0)), float(spec.get("noise_to", 1200.0)), progress) / RATE
		if noise_phase >= 1.0:
			noise_phase -= 1.0
			var feedback := (lfsr ^ (lfsr >> 1)) & 1
			lfsr = (lfsr >> 1) | (feedback << 14)
			noise = float(lfsr & 15) / 7.5 - 1.0
		filtered += alpha * (lerpf(tone, noise, noise_mix) - filtered)
		var value := clampf(filtered * envelope * amplitude, -0.4, 0.4)
		# 256-step spacing gives signed 8-bit precision, with ample mix headroom.
		var pcm := roundi(value * 127.0) * 256
		bytes.encode_s16(index * 2, 0 if index == 0 or index == frames - 1 else pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	return stream

static func _blep(phase: float, increment: float) -> float:
	if phase < increment:
		var x := phase / increment
		return x + x - x * x - 1.0
	if phase > 1.0 - increment:
		var x := (phase - 1.0) / increment
		return x * x + x + x + 1.0
	return 0.0
