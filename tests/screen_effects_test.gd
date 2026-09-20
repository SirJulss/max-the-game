extends SceneTree
## godot --headless --path . --script tests/screen_effects_test.gd
const Effects := preload("res://src/presentation/screen_effects.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var world := Node2D.new()
	root.add_child(world)
	var actor := Node2D.new()
	actor.position = Vector2(420, 370)
	world.add_child(actor)
	var effects := Effects.new()
	world.add_child(effects)
	effects.set_process(false)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	world.add_child(ui_layer)
	var ui := Control.new()
	ui.position = Vector2(70, 24)
	ui_layer.add_child(ui)
	await process_frame
	effects.reset()
	_check(effects.camera.position == Vector2(640, 360), "Camera centers on the logical viewport")
	_check(root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), "Idle effect preserves original world coordinates")
	var ui_before := ui.get_global_transform_with_canvas()
	var world_before := actor.get_global_transform_with_canvas()
	effects.impulse(0.7)
	_check(effects.camera.offset != Vector2.ZERO, "An impact shakes immediately")
	_check(ui.get_global_transform_with_canvas().is_equal_approx(ui_before), "CanvasLayer HUD remains still during world shake")
	_check(not actor.get_global_transform_with_canvas().is_equal_approx(world_before), "The world moves during an impact")
	_check(effects.get_child_count() == 1 and effects.get_child(0) is Camera2D, "Screen effects create only the camera, with no runtime glow pass")
	var screen_position := actor.get_global_transform_with_canvas() * Vector2.ZERO
	var recovered_world := root.get_canvas_transform().affine_inverse() * screen_position
	_check(recovered_world.is_equal_approx(actor.global_position), "A screen aim coordinate resolves to the visibly shifted world target")
	var bounded := true
	var snapped := true
	for i in 200:
		effects.impulse(3.0)
		effects._process(0.03125)
		var offset: Vector2 = effects.camera.offset
		bounded = bounded and absf(offset.x) <= Effects.MAX_SHAKE and absf(offset.y) <= Effects.MAX_SHAKE
		snapped = snapped and offset == offset.round()
	_check(bounded and effects.trauma <= 1.0, "Repeated impulses remain bounded")
	_check(snapped, "Every camera offset uses whole logical pixels")
	for i in 60:
		effects._process(1.0 / 60.0)
	_check(effects.trauma == 0.0 and effects.camera.offset == Vector2.ZERO, "Shake settles completely within one second")
	effects.impulse(0.8)
	effects.reset()
	_check(effects.trauma == 0.0 and effects.camera.offset == Vector2.ZERO, "Reset immediately clears impact and camera offset")
	_check(root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), "Reset immediately restores the world canvas")
	effects.impulse(0.8)
	effects.set_enabled(false)
	_check(not effects.enabled and effects.camera.offset == Vector2.ZERO, "Disabling clears shake")
	_check(not Effects.FX.glow_enabled, "Disabling selects base Pixel Composer textures")
	effects.impulse(1.0)
	_check(effects.trauma == 0.0, "Disabled effects ignore new impacts")
	effects.set_enabled(true)
	_check(effects.enabled and effects.camera.offset == Vector2.ZERO, "Re-enabling starts with a still camera")
	_check(Effects.FX.glow_enabled, "Re-enabling selects Pixel Composer glow textures")
	effects.impulse(-1.0)
	effects.impulse(INF)
	effects.impulse(NAN)
	_check(effects.trauma == 0.0, "Invalid impulses do not poison camera coordinates")
	effects.impulse(0.5)
	var before_pause := [effects.trauma, effects.camera.offset]
	effects._process(0.0)
	effects._process(-1.0)
	effects._process(NAN)
	_check(before_pause == [effects.trauma, effects.camera.offset], "Invalid or zero time leaves effects unchanged")
	effects.reset()
	root.size = Vector2i(960, 540)
	await process_frame
	effects._process(0.01)
	_check(effects.camera.position == Vector2(640, 360), "Window resizing retains the logical center")
	_check(root.get_canvas_transform().is_equal_approx(Transform2D.IDENTITY), "Window resizing introduces no camera drift")
	world.queue_free()
	await process_frame
	print("SCREEN_EFFECTS_TEST: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)
