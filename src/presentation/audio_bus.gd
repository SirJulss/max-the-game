extends Node
## Reuses the project's music and supplies small, generated sound effects.

const MUSIC := {
	"title": "res://Assets/Sounds/Music/MaxLoop_Nostalgic_Keys.wav",
	"studio": "res://Assets/Sounds/Music/MaxBackgroundLofi.wav",
	"combat": "res://Assets/Sounds/Music/MaxFIghtingTrap.wav",
	"shop": "res://Assets/Sounds/Music/MaxLoop_Piano.wav",
	"reward": "res://Assets/Sounds/Music/MaxLoop_HopeP.wav",
	"boss": "res://Assets/Sounds/Music/Project_70.wav",
}

var muted := false
var music_mode := ""
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _fade: Tween
var _voice := 0
var _headless := false


func _ready() -> void:
	_initialize()


func _initialize() -> void:
	if is_instance_valid(_music):
		return
	_headless = DisplayServer.get_name() == "headless"
	_music = AudioStreamPlayer.new()
	_music.volume_db = -25.0
	add_child(_music)
	_music.finished.connect(_on_music_finished)
	for index in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -14.0
		add_child(player)
		_voices.append(player)
	for sound in ["click", "coin", "hit", "dash", "knock", "win", "lose", "clip"]:
		_sounds[sound] = _make_sound(sound)


func _on_music_finished() -> void:
	if is_instance_valid(_music) and _music.stream != null:
		_music.play()


func set_music(next_mode: String) -> void:
	_initialize()
	if next_mode == music_mode:
		return
	music_mode = next_mode
	if _headless:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var path: String = MUSIC.get(next_mode, MUSIC["studio"])
	_music.stream = load(path) as AudioStream
	_music.volume_db = -45.0 if not muted else -80.0
	_music.play()
	if not muted:
		_fade = create_tween()
		_fade.tween_property(_music, "volume_db", -26.0 if next_mode != "combat" else -25.0, 1.1)


func set_muted(value: bool) -> void:
	_initialize()
	muted = value
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_music.volume_db = -80.0 if muted else (-25.0 if music_mode == "combat" else -26.0)
	for player in _voices:
		player.volume_db = -80.0 if muted else -14.0


func sfx(sound: String) -> void:
	_initialize()
	if muted or _headless or not _sounds.has(sound):
		return
	var player: AudioStreamPlayer = _voices[_voice % _voices.size()]
	_voice += 1
	player.stream = _sounds[sound]
	player.pitch_scale = randf_range(0.96, 1.04) if sound in ["hit", "dash", "click"] else 1.0
	player.play()


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	for player in _voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_sounds.clear()


func _make_sound(sound: String) -> AudioStreamWAV:
	var duration := 0.1
	match sound:
		"coin": duration = 0.26
		"hit": duration = 0.17
		"dash": duration = 0.19
		"knock": duration = 0.43
		"win": duration = 0.75
		"lose": duration = 0.65
		"clip": duration = 0.35
	var rate := 22050
	var samples := int(duration * rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 714
	var previous_noise := 0.0
	var phase := 0.0
	for sample in samples:
		var t := float(sample) / float(rate)
		var progress := t / duration
		var envelope := minf(t * 400.0, 1.0) * pow(1.0 - progress, 2.0)
		var hz := 700.0
		var value := 0.0
		var noise := rng.randf_range(-1.0, 1.0)
		previous_noise = lerpf(previous_noise, noise, 0.2)
		match sound:
			"click":
				hz = 820.0 - progress * 300.0
				value = sin(TAU * t * hz) * 0.35
			"coin":
				hz = 988.0 if progress < 0.35 else 1318.5
				phase += TAU * hz / rate
				value = (sin(phase) + sin(phase * 2.0) * 0.2) * 0.45
			"hit":
				hz = 150.0 - progress * 85.0
				phase += TAU * hz / rate
				value = sin(phase) * 0.65 + previous_noise * 0.7
			"dash":
				value = previous_noise * 1.6 * sin(progress * PI)
			"knock":
				var knock_t := fmod(t, 0.19)
				envelope = exp(-knock_t * 34.0) * minf(knock_t * 700.0, 1.0)
				value = sin(knock_t * 150.0 * TAU) * 0.7 + previous_noise * 0.3
			"win":
				var notes := [523.25, 659.25, 783.99, 1046.5]
				hz = notes[mini(int(progress * 4.0), 3)]
				phase += TAU * hz / rate
				value = sin(phase) * 0.5 + sin(phase * 2.0) * 0.15
			"lose":
				hz = 360.0 - progress * 240.0
				phase += TAU * hz / rate
				value = sin(phase) * 0.5 + sin(phase * 0.5) * 0.2
			"clip":
				hz = 600.0 + floor(progress * 5.0) * 140.0
				phase += TAU * hz / rate
				value = sin(phase) * 0.45
		var pcm := int(clampf(value * envelope, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(sample * 2, pcm)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	return stream
