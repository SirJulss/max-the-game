extends Node
## Reuses the project's music and plays imported chiptune WAV effects.

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
	return preload("res://src/presentation/sound_bank.gd").sound(sound)
