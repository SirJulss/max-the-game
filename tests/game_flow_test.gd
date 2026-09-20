extends SceneTree
## Integration: godot --headless --path . --script tests/game_flow_test.gd -- --test
## --test is mandatory: the actual game's persistence guard protects user data.

const GameScene = preload("res://src/run/game.gd")
var checks: int = 0
var failures: Array[String] = []
var game: Node2D

func _initialize() -> void:
	if not "--test" in OS.get_cmdline_user_args():
		push_error("This integration test requires -- --test to disable user save writes.")
		quit(2)
		return
	_run_tests.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run_tests() -> void:
	game = GameScene.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.arena.set_physics_process(false)
	_check(game.phase == "title" and not game.persistence_enabled, "Game opens on its title with test persistence disabled")
	game.begin_run()
	_check(game.phase == "apartment" and game.run.phase == "setup" and game.apartment_player.active, "New run begins with controllable Max in the apartment")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.pressed = true
	game._unhandled_input(interact)
	_check(game.phase == "apartment", "The computer cannot be used from across the apartment")
	game.apartment_player.position = Vector2(340, 355)
	game._unhandled_input(interact)
	_check(game.phase == "setup" and not game.apartment_player.active, "Using the nearby PC opens game selection")
	game.start_game("cozy")
	_check(game.phase == "stream" and game.run.phase == "stream" and game.stage.game_id == "cozy", "Chosen game binds the correct stream view")
	game._toggle_pause()
	var before: float = game.run.stream_time
	game._process(0.5)
	_check(game.paused and game.run.stream_time == before, "Pausing really stops streaming simulation")
	game._toggle_pause()
	game.stage.marker = 0.5
	game.stage.cooldown = 0.0
	before = game.run.viewers
	game.clip_moment()
	_check(game.run.viewers > before and game.run.clips_hit == 1, "The clip UI triggers actual model rewards")
	for i in 62:
		game._process(0.1)
	_check(game.run.current_event.is_empty() and not game.stage.frozen and game.run.stream_time > 6.0, "Minigames play continuously without narrative interruptions")
	game.bank_stream()
	_check(game.phase == "stream", "A stream cannot bank before16:00")
	_finish_stream()
	_check(game.phase == "shop" and game.run.phase == "shop" and is_equal_approx(game.run.stream_time, 64.0), "Completing the eight-hour shift automatically banks and opens the shop")
	var banked: int = game.total_banked
	game.bank_stream()
	_check(game.total_banked == banked, "Repeated bank input cannot duplicate UI accounting")
	game.run.donations = maxi(game.run.donations, 150)
	var offered_weapon: String = ""
	for offer in game.run.shop_offers():
		if offer.category == "WEAPON":
			offered_weapon = offer.id
	game.buy_upgrade(offered_weapon)
	_check(game.run.weapon == offered_weapon, "Shop purchase equips its guaranteed weapon offer")
	game._equip_weapon("keyboard")
	_check(game.run.weapon == "keyboard", "Shop loadout control can restore the default keyboard")
	game._equip_weapon(offered_weapon)
	var old_wallet: int = game.run.donations
	var old_reroll_cost: int = game.run.reroll_cost()
	game._reroll_shop()
	_check(game.run.donations == old_wallet - old_reroll_cost and game.run.shop_offers().size() == 4, "Shop reroll control charges once and replaces four offers")
	var shop_wallet: int = game.run.donations
	game.checkpoint = JSON.parse_string(JSON.stringify({"run": game.run.to_save(), "kills": game.run_kills, "banked": game.total_banked, "peak": game.stream_peak}))
	game.run.reset_run()
	game.resume_run()
	_check(game.phase == "shop" and game.run.weapon == offered_weapon and game.run.donations == shop_wallet, "Continue restores the exact shop, purchases, and wallet")
	for expected_day in range(1, 7):
		if expected_day > 1:
			game.show_apartment()
			_check(game.phase == "apartment" and game.apartment_player.active, "Each cleared day returns to a controllable apartment morning")
			game.show_setup()
			game.start_game(["cozy", "sweaty", "weird"][(expected_day - 1) % 3])
			_finish_stream()
		game.show_knock()
		_check(game.phase == "knock" and game.run.phase == "shop", "Door encounter waits until the player is ready")
		game.start_combat()
		_check(game.phase == "combat" and game.run.phase == "combat" and game.arena.active, "Answering the door begins actual arena combat")
		_check(game.arena.player.weapon == game.run.weapon, "Combat receives the selected loadout")
		if expected_day == 3 or expected_day == 6:
			_check(("modzilla" if expected_day == 3 else "algorithm") in game.arena.spawn_queue, "Boss days include their advertised boss")
		_clear_encounter()
		_check(game.phase == ("won" if expected_day == 6 else "reward"), "An arena clear advances to the right presentation phase")
		_check(game.run.phase == ("won" if expected_day == 6 else "setup"), "An arena clear advances the model exactly once")
		if expected_day < 6:
			_check(game.run.day == expected_day + 1, "Reward leads to the following day")
		await process_frame
	_check(game.profile.wins == 1 and game.run_kills > 50 and game.total_banked > 300, "Full six-day victory updates results and meta progression")
	_test_stream_inputs()
	game.show_title()
	game.begin_run()
	game.show_setup()
	game.start_game("sweaty")
	_finish_stream()
	game.show_knock()
	game.start_combat()
	game.arena.player.invulnerable = 0.0
	game.arena.player.take_damage(10000.0, Vector2.ZERO)
	_check(game.phase == "dead" and game.run.phase == "lost" and not game.arena.active, "Taking lethal damage reaches the loss screen and ends combat")
	game.show_title()
	_check(game.phase == "title", "A lost run can return to the title")
	game.queue_free()
	await process_frame
	# AudioServer releases stopped playbacks on its next mix, independently of
	# the very fast headless scene-tree frames used above.
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("GAME FLOW TESTS PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAME FLOW TESTS FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)

func _test_stream_inputs() -> void:
	game.begin_run()
	game.start_game("sweaty")
	game.stage.set_process(false)
	game.stage.marker = 0.0
	var shot := InputEventMouseButton.new()
	shot.button_index = MOUSE_BUTTON_LEFT
	shot.pressed = true
	shot.position = game.stage.get_global_transform_with_canvas() * game.stage.logical_to_local(game.stage._target_center(game.stage._target_index))
	game._unhandled_input(shot)
	_check(game.run.clips_hit == 1 and game.run.clip_streak == 1, "A viewport mouse click hits the scaled marked target independently of assist timing")
	var viewers_before: float = game.run.viewers
	game._unhandled_input(shot)
	_check(game.run.viewers == viewers_before and game.run.clip_streak == 1, "Repeated mouse events during recovery cannot farm or break a combo")
	for tick in 20:
		game._process(0.1)
		game.stage._process(0.1)
	shot.position = Vector2(20, 300)
	game._unhandled_input(shot)
	_check(game.run.clip_ready() and game.run.clip_streak == 1, "Clicking outside the monitor is ignored without a miss penalty")
	game._toggle_pause()
	shot.position = game.stage.get_global_transform_with_canvas() * game.stage.logical_to_local(game.stage._target_center(game.stage._target_index))
	game._unhandled_input(shot)
	_check(game.run.clip_streak == 1, "Paused stream input cannot award a hit")
	game._toggle_pause()
	game.begin_run()
	game.start_game("weird")
	game.stage.set_process(false)
	var verdict := InputEventKey.new()
	verdict.pressed = true
	verdict.keycode = KEY_A if game.stage.court_answer == "left" else KEY_D
	game._unhandled_input(verdict)
	_check(game.run.clip_streak == 1 and not game.stage.court_active, "Court directional keys resolve a case and award its streak exactly once")
	game._unhandled_input(verdict)
	_check(game.run.clips_hit == 1, "Repeated verdict input cannot answer a closed case")
	for tick in 20:
		game._process(0.1)
		game.stage._process(0.1)
	var case_time: float = game.stage.court_time_left
	game._toggle_pause()
	game.stage._process(20.0)
	game._process(20.0)
	_check(game.stage.court_time_left == case_time and game.run.clip_streak == 1, "Pause freezes an unanswered court case without a hidden miss")
	game._toggle_pause()
	var heat_before: float = game.run.heat
	for tick in 30:
		game.stage._process(0.1)
	_check(game.run.clip_streak == 0 and is_equal_approx(game.run.heat, heat_before + 3), "An expired case emits one real model miss and resets the combo")
	game.stage._process(0.2)
	_check(is_equal_approx(game.run.heat, heat_before + 3), "Expired case recovery cannot repeatedly charge the same miss")
	_check(game.labels["combo"].text.begins_with("COMBO 0"), "The compact HUD reflects the expired combo")

func _finish_stream() -> void:
	for i in 1400:
		if game.phase == "shop":
			return
		if game.run.can_end_stream():
			game.bank_stream()
			return
		if game.run.clip_ready():
			game.stage.marker = 0.5
			game.stage.cooldown = 0.0
			if game.run.game_id == "weird":
				game._stream_action(game.stage.court_answer)
			elif game.run.game_id == "sweaty":
				game._stream_action("click", game.stage.logical_to_local(game.stage._target_center(game.stage._target_index)))
			else:
				game.clip_moment()
		game._process(0.1)
		if game.phase == "stream":
			game.stage._process(0.1)
	_check(false, "Streaming did not reach the shop in bounded time")

func _clear_encounter() -> void:
	# This is a controlled damage fixture, not a claim that a novice can win.
	# It exercises the real spawn queue, hit resolution, KO rewards, boss and
	# clear signals, and model/UI transitions without depending on mouse position.
	game.arena.player.damage = 1000.0
	for i in 1800:
		if game.phase != "combat":
			return
		for enemy in game.arena.enemies.duplicate():
			if is_instance_valid(enemy) and not enemy.dead:
				enemy.spawn_time = 0.0
				enemy.position = game.arena.player.position + Vector2(38, 0)
		game.arena._attack(Vector2.RIGHT, "keyboard", 1)
		game.arena._physics_process(0.1)
		game.arena._process(0.1)
		game._process(0.1)
	_check(false, "An encounter failed to clear after its enemies were defeated")
