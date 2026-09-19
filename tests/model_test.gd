extends SceneTree
## Run: godot --headless --path . --script tests/model_test.gd

const RunModel = preload("res://src/run/run_data.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_state_and_shift()
	_test_shop_and_stats()
	_test_overtime_and_loss()
	_test_save_roundtrip()
	_test_full_runs()
	if failures.is_empty():
		print("MODEL TESTS PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MODEL TESTS FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish_shift(run, clips: bool = false) -> void:
	for i in 1400:
		if run.can_end_stream():
			return
		if clips and run.clip_ready():
			run.try_clip(0.5)
		run.tick_stream(0.1)
	_check(false, "Eight-hour stream failed to finish within the bounded simulation")

func _test_state_and_shift() -> void:
	var run = RunModel.new()
	_check(run.day == 1 and run.phase == "setup" and run.donations == 20, "A new run starts at day one with seed money")
	_check(run.end_stream() == 0 and run.try_clip(0.5).is_empty(), "Setup cannot generate income")
	run.begin_stream("does-not-exist")
	_check(run.phase == "setup", "Unknown game does not begin a stream")
	run.begin_stream("cozy")
	_check(run.phase == "stream" and run.game_id == "cozy", "A valid game starts streaming")
	var before: float = run.viewers
	run.tick_stream(-1.0)
	run.tick_stream(NAN)
	_check(run.viewers == before, "Invalid time cannot change viewers")
	_check(run.try_clip(0.5).begins_with("CLEAN CLIP"), "A well-timed clip succeeds")
	before = run.viewers
	_check(run.try_clip(0.5).is_empty() and run.viewers == before, "Clip cooldown prevents spam")
	for i in 7:
		run.tick_stream(1.0)
	_check(run.current_event.is_empty(), "Streaming has no interrupting narrative decisions")
	var previous_time: float = run.stream_time
	before = run.viewers
	run.tick_stream(1.0)
	_check(run.stream_time > previous_time and run.viewers > before, "The clock and viewer simulation continue uninterrupted")
	_check(run.choose_event(0).is_empty(), "The retired decision API grants no rewards")
	run.viewers = run.goal
	_check(not run.can_end_stream() and run.end_stream() == 0, "Reaching a goal cannot end the eight-hour shift early")
	_finish_shift(run)
	var wallet: int = run.donations
	var income: int = run.end_stream()
	_check(income > 20 and run.phase == "shop" and run.donations == wallet + income, "Banking the stream pays donors and a goal bonus")
	_check(run.end_stream() == 0 and run.donations == wallet + income, "A stream deposits exactly once")
	_check(run.current_event.is_empty(), "Banking clears any pending event")
	_check(run.shop_offers().size() == 4, "Every first-day shop contains four offers")

func _test_shop_and_stats() -> void:
	var run = RunModel.new()
	run.begin_stream("sweaty")
	_finish_shift(run)
	run.end_stream()
	var wallet: int = run.donations
	_check(not run.buy_upgrade("medkit") and run.donations == wallet, "A full-health medkit purchase is refused without charging")
	_check(not run.buy_upgrade("not-an-upgrade"), "Unknown purchases are refused")
	run.hp = 30.0
	_check(run.buy_upgrade("medkit") and is_equal_approx(run.hp, 75.0), "Healing restores 45 HP")
	_check(not run.buy_upgrade("medkit"), "Healing is limited to once per shop")
	run.donations = 1000
	var offered_weapon: String = ""
	for offer in run.shop_offers():
		if offer.category == "WEAPON":
			offered_weapon = offer.id
	_check(not offered_weapon.is_empty() and run.buy_upgrade(offered_weapon) and run.combat_stats()["weapon"] == offered_weapon, "The guaranteed weapon offer equips on purchase")
	_check(not run.buy_upgrade(offered_weapon), "An upgrade cannot be purchased twice from one offer")
	wallet = run.donations
	var initial_reroll: int = run.reroll_cost()
	_check(run.reroll_shop() and run.donations == wallet - initial_reroll and run.reroll_cost() == initial_reroll + 4, "Rerolls spend currency and become more expensive")
	_check(not run.buy_upgrade("medkit"), "Rerolling cannot restock the daily heal")
	var second_weapon: String = "capslock" if offered_weapon == "banhammer" else "banhammer"
	_check(run.buy_upgrade(second_weapon) and run.combat_stats()["weapon"] == second_weapon, "Rerolling offers the remaining unowned weapon")
	_check(run.equip_weapon("banhammer") and run.equip_weapon("keyboard"), "Owned weapons and the starting keyboard can be re-equipped for free")
	# Directly seed a build to verify independent combat/stream integrations.
	run.upgrades = {"protein": 2, "rage_drive": 1, "sneakers": 2, "armor": 1, "vampire": 1, "hater_bonds": 2, "security": 2, "thorns": 1, "vitality": 1, "tip_jar": 1, "webcam": 1, "fiber": 1, "fan_club": 1}
	run.heat = 100.0
	var stats: Dictionary = run.combat_stats()
	_check(is_equal_approx(float(stats["damage"]), 1.36 * 1.30), "Heat and base-damage upgrades multiply into one supplied damage value")
	_check(stats["max_hp"] == 122.0 and stats["armor"] == 2, "Health and armor bonuses reach combat")
	_check(stats["lifesteal"] == 4 and stats["bounty"] == 6 and stats["security"] == 2 and stats["thorns"] == 6, "Build effects expose their intended combat units")
	_check(is_equal_approx(float(stats["dash_cooldown"]), 0.7744) and is_equal_approx(run.viewer_multiplier(), 1.43), "Movement and growth stacks combine consistently")
	run.start_combat()
	_check(not run.reroll_shop(), "Combat cannot reroll shop inventory")
	_check(not run.equip_weapon("capslock"), "Equipment cannot change mid-fight")
	_check(not run.buy_upgrade("medkit"), "Combat cannot purchase shop offers")
	var fans_before: int = run.loyalty_fans
	wallet = run.donations
	_check(not run.finish_combat(35, 40.0) and run.day == 2 and run.phase == "setup", "An ordinary clear starts the next day")
	_check(run.donations == wallet + 35 and run.hp == 56.0 and run.loyalty_fans == fans_before + roundi(float(RunModel.GOALS[1]) * 0.08), "Combat payout and Redemption Arc scale to tomorrow's audience and apply once")
	wallet = run.donations
	run.finish_combat(999, 100.0)
	_check(run.donations == wallet and run.day == 2, "A duplicate combat callback cannot grant a second reward")
	run.reset_run("spicy")
	_check(run.combat_stats()["max_hp"] == 90.0 and run.combat_stats()["bounty"] == 2 and run.donation_multiplier() == 1.25, "Ragebait sidegrade trades health for money and risk")
	run.reset_run("cozy")
	_check(run.combat_stats()["armor"] == 1 and is_equal_approx(run.combat_stats()["damage"], 0.88) and run.viewer_multiplier() == 1.15, "Comfort sidegrade trades damage for growth and armor")

func _test_overtime_and_loss() -> void:
	var run = RunModel.new()
	run.begin_stream("weird")
	for i in 640:
		if run.viewers >= run.goal:
			break
		if run.clip_ready():
			run.try_clip(0.5)
		run.tick_stream(0.1)
	var heat_before: float = run.heat
	var income_before: float = run.stream_donations
	for i in 900:
		run.tick_stream(0.1)
	_check(run.force_end_ready() and is_equal_approx(run.stream_time, RunModel.STREAM_LIMIT), "The eight-hour shift finishes after64 seconds")
	_check(run.heat > heat_before and run.stream_donations > income_before, "Continuing after a goal earns more money and heat")
	_check(run.heat <= 160.0 and run.hype <= 100.0 and run.enemy_budget() <= 23, "Audience excitement and encounter size remain bounded")
	var capped_income: float = run.stream_donations
	run.tick_stream(1.0)
	_check(run.stream_donations == capped_income, "The cap cannot generate free idle income")
	run.end_stream()
	run.start_combat()
	var wallet: int = run.donations
	_check(not run.finish_combat(100, 0.0) and run.phase == "lost" and run.donations == wallet, "Defeat grants no combat reward and ends the run")
	_check(run.to_save().is_empty(), "A finished or defeated run cannot become a continue checkpoint")
	var idle_run = RunModel.new()
	idle_run.begin_stream("cozy")
	_finish_shift(idle_run)
	_check(idle_run.viewers < idle_run.goal and idle_run.can_end_stream(), "Missing the viewer goal still allows the shift to finish")
	var raw_income: int = floori(idle_run.stream_donations)
	_check(idle_run.end_stream() == raw_income and idle_run.phase == "shop", "A missed goal pays earned donations without the goal bonus")

func _test_save_roundtrip() -> void:
	var run = RunModel.new()
	run.reset_run("spicy")
	var setup_save: Dictionary = run.to_save()
	var setup_restored = RunModel.new()
	_check(setup_restored.load_save(setup_save) and setup_restored.starting_perk == "spicy", "Initial checkpoint reloads with its sidegrade")
	run.begin_stream("weird")
	_check(run.to_save().is_empty(), "Midstream progress is not serialized as a safe checkpoint")
	_finish_shift(run, true)
	run.end_stream()
	run.hp = 35.0
	run.buy_upgrade("medkit")
	run.reroll_shop()
	var saved: Dictionary = run.to_save()
	# Exercise JSON's numeric conversion and the full 64-bit RNG string.
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var restored = RunModel.new()
	_check(restored.load_save(json_copy), "Shop checkpoint survives a real JSON round trip")
	_check(restored.donations == run.donations and is_equal_approx(restored.hp, run.hp) and is_equal_approx(restored.heat, run.heat), "Currency, sustain, and combat risk survive reload")
	_check(restored.shop_offers() == run.shop_offers(), "Reload preserves exact shop inventory, price, and sold state")
	_check(restored.reroll_cost() == run.reroll_cost(), "Reload preserves reroll costs")
	_check(restored.end_stream() == 0 and not restored.buy_upgrade("medkit"), "Reload cannot replay the bank or a sold heal")
	run.start_combat()
	restored.start_combat()
	run.finish_combat(20, 50.0)
	restored.finish_combat(20, 50.0)
	run.begin_stream("cozy")
	restored.begin_stream("cozy")
	_finish_shift(run)
	_finish_shift(restored)
	run.end_stream()
	restored.end_stream()
	_check(restored.shop_offers() == run.shop_offers(), "Restored RNG produces the same following day's choices")
	var stable: Dictionary = restored.to_save()
	for field in ["hp", "heat", "hype", "donations", "goal"]:
		var bad: Dictionary = stable.duplicate(true)
		bad[field] = "garbage"
		_check(not restored.load_save(bad) and restored.to_save() == stable, "Invalid %s save fails without mutating current state" % field)
	var invalid: Dictionary = stable.duplicate(true)
	invalid["upgrades"] = {"delete_the_game": 1}
	_check(not restored.load_save(invalid), "Unknown upgrades in a checkpoint are rejected")
	invalid = stable.duplicate(true)
	invalid["day"] = 7
	_check(not restored.load_save(invalid), "Out-of-range saved days are rejected")
	invalid = stable.duplicate(true)
	invalid["offer_ids"] = ["medkit", "medkit"]
	_check(not restored.load_save(invalid), "Duplicate shop offers are rejected")
	invalid = stable.duplicate(true)
	invalid["version"] = []
	_check(not restored.load_save(invalid), "Corrupted nonnumeric save version is rejected safely")
	invalid = stable.duplicate(true)
	invalid["day"] = 2.5
	_check(not restored.load_save(invalid), "Fractional saved days are rejected")
	invalid = stable.duplicate(true)
	invalid["day"] = {}
	_check(not restored.load_save(invalid), "Corrupted day data is rejected safely")

func _test_full_runs() -> void:
	for game in RunModel.GAMES:
		for perk in ["", "spicy", "cozy"]:
			var run = RunModel.new()
			run.reset_run(perk)
			var times: Array[float] = []
			for target_day in range(1, 7):
				run.begin_stream(str(game["id"]))
				_finish_shift(run, true)
				times.append(snappedf(run.stream_time, 0.1))
				_check(is_equal_approx(run.stream_time, RunModel.STREAM_LIMIT) and run.viewers >= run.goal, "Every unupgraded game/perk can meet its goal through active play in one complete shift")
				run.end_stream()
				_check(run.shop_offers().size() == 4, "Shops remain complete across all six days")
				run.start_combat()
				var victory: bool = run.finish_combat(25 + target_day * 5, 60.0)
				_check(victory == (target_day == 6), "Only clearing day six wins the run")
			_check(run.phase == "won" and run.day == 6 and run.donations > 200, "All game/perk combinations complete the complete six-day economy")
			print("BALANCE %s / %s: stream seconds %s, total wallet $%d" % [str(game["id"]), perk if not perk.is_empty() else "base", str(times), run.donations])
