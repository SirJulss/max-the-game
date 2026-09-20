extends SceneTree
## godot --headless --path . --script tests/stream_stage_test.gd
## Exercises the actual visible hit geometry, recovery and court deadlines.
const Stage := preload("res://src/ui/stream_stage.gd")
var checks := 0
var failures: Array[String] = []
var stages: Array[Control] = []
var timeouts := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)

func _stage(id: String, dimensions := Vector2(850, 478)) -> Control:
	var stage := Stage.new()
	stage.game_id = id
	stage.size = dimensions
	root.add_child(stage)
	stage.set_process(false)
	stages.append(stage)
	return stage

func _advance(stage: Control, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var step := minf(0.2, remaining)
		stage._process(step)
		remaining -= step

func _run() -> void:
	var farm = _stage("cozy")
	farm.marker = Stage.COZY_ZONE.x
	_check(farm.clip() == 0.5, "Left visible ripe-zone edge normalizes to model success")
	_check(farm.attempts == 1 and farm.action_count == 1, "A harvest counts once")
	_check(farm.clip() == -1.0 and farm.attempts == 1, "Rapid repeat input cannot farm rewards")
	farm.play_action_feedback(true)
	_check(farm.action_count == 1, "Duplicate parent feedback cannot duplicate harvested crops")
	farm.cooldown = 0
	farm.marker = Stage.COZY_ZONE.y
	_check(farm.resolve_action("primary") == 0.5, "Right visible ripe-zone edge succeeds")
	farm.cooldown = 0
	farm.marker = Stage.COZY_ZONE.x - 0.01
	_check(farm.clip() == 0.0, "A crop outside the visible ripe zone misses")
	farm.cooldown = 0
	_check(farm.resolve_action("left") == -1.0, "Unrelated direction input is ignored by farming")
	_check(farm.resolve_action("click", Vector2.ZERO) == -1.0, "Monitor chrome is not a harvest button")
	farm.marker = 0.5
	_check(farm.resolve_action("click", farm.logical_to_local(Vector2(300, 180))) == 0.5, "Clicking inside the farm can harvest")
	farm.frozen = true
	var before := [farm.elapsed, farm.cooldown, farm.marker]
	farm._process(20)
	_check(before == [farm.elapsed, farm.cooldown, farm.marker], "Pause freezes animation, timing and recovery")
	_check(farm.clip() == -1.0, "Paused farming cannot resolve input")

	for dimensions in [Vector2(425, 239), Vector2(850, 478), Vector2(1062.5, 597.5)]:
		var ranked = _stage("sweaty", dimensions)
		ranked.elapsed = 1.73
		ranked.marker = 0.02
		var center: Vector2 = ranked._target_center(ranked._target_index)
		_check(ranked.resolve_action("click", ranked.logical_to_local(center)) == 0.5, "Aimed click hits the actual moving target at scale %s" % dimensions)
		_check(ranked.resolve_action("click", ranked.logical_to_local(center)) == -1.0, "Ranked repeat clicks respect recovery")
		ranked.cooldown = 0
		center = ranked._target_center(ranked._target_index)
		_check(ranked.resolve_action("click", ranked.logical_to_local(center + Vector2(Stage.SHOT_RADIUS - 0.5, 0))) == 0.5, "Visible pink target edge is clickable at scale %s" % dimensions)
		ranked.cooldown = 0
		center = ranked._target_center(ranked._target_index)
		_check(ranked.resolve_action("click", ranked.logical_to_local(center + Vector2(Stage.SHOT_RADIUS + 3, 0))) == 0.0, "A click outside the pink ring misses")
		ranked.cooldown = 0
		_check(ranked.resolve_action("click", Vector2.ZERO) == -1.0, "Ranked ignores clicks on the monitor bezel")
		_check(ranked.resolve_action("click", ranked.logical_to_local(Vector2(300, 360))) == -1.0, "Ranked does not shoot the assist HUD")
		ranked.marker = 0.5
		_check(ranked.clip() == 0.5, "Space aim assist hits in its visible green zone")
		ranked.cooldown = 0
		ranked.marker = 0.1
		_check(ranked.clip() == 0.0, "Space aim assist misses outside its visible green zone")
		ranked.cooldown = 0
		ranked._target_index = 0
		ranked.elapsed = 3.0 * PI / (2.0 * 1.7)
		center = ranked._target_center(0)
		_check(ranked.resolve_action("click", ranked.logical_to_local(center + Vector2(0, -Stage.SHOT_RADIUS + 0.5))) == 0.5, "Top rim remains clickable at the target's highest bob")

	var court = _stage("weird")
	_check(court.court_answer == "right", "Opening bread evidence clearly asks for BONK")
	_check(court.resolve_action("left") == 0.0, "Freeing the bread thief gives a wrong verdict")
	_check(court.resolve_action("right") == -1.0, "A judged case cannot be answered twice")
	_advance(court, Stage.ACTION_COOLDOWN + 0.01)
	_check(court.court_active and court.court_answer == "left", "A new flower case starts after recovery")
	_check(is_equal_approx(court.court_time_left, Stage.COURT_WINDOW), "Recovery never steals time from the next case")
	_check(court.resolve_action("left") == 0.5, "Freeing the flower carrier succeeds")
	_advance(court, Stage.ACTION_COOLDOWN + 0.01)
	_check(court.resolve_action("click", court.logical_to_local(Stage.COURT_LEFT.get_center())) == 0.5, "Court's painted left button is genuinely clickable")
	var small_court = _stage("weird", Vector2(425, 239))
	_check(small_court.resolve_action("click", small_court.logical_to_local(Stage.COURT_RIGHT.get_center())) == 0.5, "Court click coordinates stay correct when scaled")

	var deadline = _stage("weird")
	deadline.timed_out.connect(func(): timeouts += 1)
	deadline.frozen = true
	deadline._process(30.0)
	_check(timeouts == 0 and deadline.court_time_left == Stage.COURT_WINDOW, "Paused court evidence cannot time out")
	_check(deadline.resolve_action("right") == -1.0, "Paused court cannot answer evidence")
	deadline.frozen = false
	_advance(deadline, Stage.COURT_WINDOW - 0.01)
	_check(timeouts == 0, "A case does not expire before the displayed deadline")
	deadline._process(0.02)
	_check(timeouts == 1 and deadline.attempts == 1 and not deadline.court_active, "One unanswered case emits exactly one timeout miss")
	deadline._process(0.5)
	_check(timeouts == 1 and deadline.attempts == 1, "Timeout recovery cannot emit duplicate misses")
	_advance(deadline, deadline.cooldown + 0.001)
	_check(deadline.court_active and deadline.court_time_left == Stage.COURT_WINDOW, "Court resumes with a fresh complete reaction window")
	_advance(deadline, Stage.COURT_WINDOW - 0.01)
	_check(deadline.resolve_action(deadline.court_answer) == 0.5, "A correct answer immediately before the deadline is accepted")
	deadline._process(0.1)
	_check(timeouts == 1, "Answered cases cannot subsequently emit timeout penalties")
	var stalled = _stage("weird")
	stalled._process(30.0)
	_check(stalled.elapsed == 1.0, "Stage elapsed time matches the model's one-second stall clamp")
	_check(is_equal_approx(stalled.court_time_left, Stage.COURT_WINDOW - 1.0) and stalled.attempts == 0, "A stalled application never silently expires a fresh case")

	for stage in stages:
		stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("STREAM STAGE TESTS PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("STREAM STAGE TESTS FAILED: %d/%d" % [failures.size(), checks])
		quit(1)
