extends RefCounted
## Runtime playback uses imported WAV assets; synthesis is an authoring step.
const DIRECTORY := "res://Assets/Sounds/FX/"
static var _sounds: Dictionary = {}

static func sound(key: String) -> AudioStreamWAV:
	key = {"jetpack": "jet_launch", "bottle": "bottle_break"}.get(key, key)
	if not _sounds.has(key):
		var path := DIRECTORY + key + ".wav"
		if not ResourceLoader.exists(path):
			return null
		_sounds[key] = load(path) as AudioStreamWAV
	return _sounds[key]
