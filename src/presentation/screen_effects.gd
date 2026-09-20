extends Node
## Add once below the game root for pixel-snapped impact shake.
## Controls on CanvasLayer 1 or higher keep their original position.
## Reset before disabling processing for pause. The camera remains centered.
## Visible effects and their glow are imported Pixel Composer textures.

const FX := preload("res://src/presentation/pixel_fx.gd")
const MAX_SHAKE := 7.0
const TRAUMA_DECAY := 2.25
const SHAKE_RATE := 32.0

var enabled := true
var trauma := 0.0
var camera: Camera2D
var _logical_size := Vector2(1280, 720)
var _shake_clock := 0.0
var _shake_sample := 0

func _ready() -> void:
	_logical_size = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	camera = Camera2D.new()
	camera.name = "ImpactCamera"
	camera.position = _logical_size * 0.5
	camera.position_smoothing_enabled = false
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	add_child(camera)
	camera.make_current()

	reset()

func impulse(strength: float) -> void:
	if not enabled or not is_finite(strength) or strength <= 0.0:
		return
	trauma = minf(1.0, trauma + clampf(strength, 0.0, 1.0))
	# A new hit is felt immediately, including impacts just before a hit stop.
	_shake_clock = 0.0
	_sample_offset()
	_sync_canvas()

func set_enabled(value: bool) -> void:
	enabled = value
	FX.glow_enabled = value
	if not enabled:
		reset()

func reset() -> void:
	trauma = 0.0
	_shake_clock = 0.0
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
		_sync_canvas()

func _process(delta: float) -> void:
	if not enabled or delta <= 0.0 or not is_finite(delta):
		return
	trauma = maxf(0.0, trauma - minf(delta, 1.0) * TRAUMA_DECAY)
	if trauma <= 0.0:
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
	else:
		_shake_clock += delta
		if _shake_clock >= 1.0 / SHAKE_RATE:
			_shake_clock = fmod(_shake_clock, 1.0 / SHAKE_RATE)
			_sample_offset()
	_sync_canvas()

func _sample_offset() -> void:
	if not is_instance_valid(camera):
		return
	_shake_sample += 1
	var amplitude := MAX_SHAKE * pow(trauma, 1.3)
	# Deterministic, irregular samples avoid consuming the gameplay RNG.
	# No rotation or zoom: original pixel art and attack geometry stay legible.
	var wave := Vector2(sin(_shake_sample * 2.399 + 0.6), sin(_shake_sample * 4.193 + 1.4))
	camera.offset = (wave * amplitude).round()

func _sync_canvas() -> void:
	if not is_instance_valid(camera):
		return
	# The real camera transform keeps get_global_mouse_position() aim correct.
	camera.force_update_scroll()
