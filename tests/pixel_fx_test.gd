extends SceneTree
## Imported animation contract. The game must not silently ship missing VFX.
const FX := preload("res://src/presentation/pixel_fx.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	for kind in FX.KINDS:
		for suffix in ["", "_glow"]:
			var key: String = kind + suffix
			var sheet: Texture2D = FX.texture(key)
			check(sheet != null, "Pixel Composer export exists: " + key)
			if sheet == null:
				continue
			check(sheet.get_height() == 128 and sheet.get_width() % 128 == 0 and sheet.get_width() >= 1024, "Animation strip has at least eight square cells: " + key)
			var picture := sheet.get_image()
			if picture.is_compressed():
				picture.decompress()
			picture.convert(Image.FORMAT_RGBA8)
			var frames := sheet.get_width() / 128
			var identities := {}
			var visible_frames := 0
			for frame in frames:
				var cell := picture.get_region(Rect2i(frame * 128, 0, 128, 128))
				identities[hash(cell.get_data())] = true
				if not cell.is_invisible():
					visible_frames += 1
			check(identities.size() >= 4, "Pixel Composer frames contain genuine visual development: " + key)
			check(visible_frames >= 4 and picture.get_pixel(0, 0).a < 0.05, "Effect has visible frames on a transparent canvas: " + key)
	print("PIXEL FX TESTS: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)
