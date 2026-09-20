extends SceneTree
## Generated effects only. Original music is loaded and played without alteration.
## Optional preview: --script tests/audio_test.gd -- --preview=/absolute/file.wav
const Synth := preload("res://tools/chip_synth.gd")
const Audio := preload("res://src/presentation/audio_bus.gd")
const SoundBank := preload("res://src/presentation/sound_bank.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _run() -> void:
	var identities: Dictionary = {}
	for key in Synth.RECIPES:
		var stream: AudioStreamWAV = Synth.make(key)
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--export-dir="):
				var directory := argument.trim_prefix("--export-dir=")
				DirAccess.make_dir_recursive_absolute(directory)
				check(Synth.make(key, 0.24).save_to_wav(directory.path_join(key + ".wav")) == OK, "Authoring WAV exported: " + key)
		var imported := SoundBank.sound(key)
		check(imported != null and imported.data == Synth.make(key, 0.24).data, "Runtime plays the exported WAV unchanged: " + key)
		var expected_frames := roundi(float(Synth.RECIPES[key]["seconds"]) * Synth.RATE)
		check(stream.mix_rate == Synth.RATE and not stream.stereo and stream.data.size() == expected_frames * 2, "%s has its specified duration and mono PCM format" % key)
		check(is_finite(stream.get_length()) and stream.get_length() > 0.04 and stream.get_length() < 0.8, "%s has a finite short duration" % key)
		var quantized := true
		var peak := 0
		var energy := 0.0
		for index in stream.data.size() / 2:
			var pcm := stream.data.decode_s16(index * 2)
			quantized = quantized and pcm % 256 == 0
			peak = maxi(peak, absi(pcm))
			energy += float(pcm) * pcm
		check(quantized and peak > 512 and peak < 12000 and energy > 0, "%s is audible 8-bit precision with headroom and no clipping" % key)
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16(stream.data.size() - 2) == 0, "%s starts and ends at silence" % key)
		var fade_peak := 0
		for index in 20:
			fade_peak = maxi(fade_peak, absi(stream.data.decode_s16(index * 2)))
			fade_peak = maxi(fade_peak, absi(stream.data.decode_s16(stream.data.size() - (index + 1) * 2)))
		check(fade_peak < peak, "%s has a short fade instead of hard playback edges" % key)
		check(stream.data == Synth.make(key).data, "%s noise and pitch synthesis are reproducible" % key)
		identities[hash(stream.data)] = true
	check(identities.size() == Synth.RECIPES.size(), "Every named action has a distinct waveform")
	check(Synth.make("jetpack").data == Synth.make("jet_launch").data and Synth.make("bottle").data == Synth.make("bottle_break").data, "Compatibility sound names resolve to the new effects")
	var bus := Audio.new()
	root.add_child(bus)
	check(bus._sounds.size() == 8, "UI audio bus builds all existing sound keys")
	check(bus._sounds["coin"] == SoundBank.sound("coin"), "UI audio bus uses the imported sound bank")
	for path in Audio.MUSIC.values():
		check(ResourceLoader.exists(path), "Original music remains available: " + path.get_file())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			_write_preview(argument.trim_prefix("--preview="))
	bus.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("AUDIO TESTS PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _write_preview(path: String) -> void:
	var data := PackedByteArray()
	var gap := PackedByteArray()
	gap.resize(roundi(Synth.RATE * 0.22) * 2)
	for key in ["click", "coin", "clip", "hit", "shot", "dash", "jet_launch", "slam", "bottle_throw", "bottle_break", "win"]:
		data.append_array(Synth.make(key, 0.3).data)
		data.append_array(gap)
	var preview := AudioStreamWAV.new()
	preview.format = AudioStreamWAV.FORMAT_16_BITS
	preview.mix_rate = Synth.RATE
	preview.data = data
	var error := preview.save_to_wav(path)
	check(error == OK, "Preview WAV exported")
	if error == OK:
		print("SFX PREVIEW: " + path)
