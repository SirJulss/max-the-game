extends Node2D
## The complete run: choose a game, stream, shop, answer the door, survive.
const RunModel = preload("res://src/run/run_data.gd")
const Backdrop = preload("res://src/presentation/world_backdrop.gd")
const Sound = preload("res://src/presentation/audio_bus.gd")
const Arena = preload("res://src/combat/combat_arena.gd")
const Stage = preload("res://src/ui/stream_stage.gd")
const ScreenEffects = preload("res://src/presentation/screen_effects.gd")
const BG := Color("111624")
const PANEL := Color("1b2235")
const BORDER := Color("35415b")
const TEXT := Color("f3f3fa")
const DIM := Color("a7b2ca")
const MINT := Color("75f2c0")
const PURPLE := Color("ad97ff")
const PINK := Color("ff779e")
const GOLD := Color("ffd08a")
const BUTTON_NORMAL = preload("res://Assets/UI/Button.png")
const BUTTON_HOVER = preload("res://Assets/UI/ButtonH.png")
const BUTTON_PRESSED = preload("res://Assets/UI/ButtonI..png")
const UI_FONT = preload("res://Assets/Fonts/Tiny5-Regular.ttf")
const SAVE_PATH := "user://run_v1.json"
const PROFILE_PATH := "user://profile_v1.json"

var run = RunModel.new()
var backdrop: Node2D
var sound: Node
var arena: Node2D
var ui: Control
var overlay: Control
var toast_label: Label
var phase := "title"
var paused := false
var muted := false
var selected_perk := ""
var profile := {"best_day": 0, "wins": 0, "runs": 0, "peak": 0}
var checkpoint: Dictionary = {}
var labels: Dictionary = {}
var bars: Dictionary = {}
var choice_buttons: Array[Button] = []
var bank_button: Button
var clip_button: Button
var stage: Control
var event_id := ""
var chat_lines: Array[String] = []
var chat_clock := 0.0
var toast_time := 0.0
var goal_announced := false
var stream_peak := 0
var encounter_reward := 0
var previous_day := 1
var run_kills := 0
var total_banked := 0
var music_button: Button
var persistence_enabled := not "--test" in OS.get_cmdline_user_args()
var apartment_player: Player
var screen_fx: Node
var effects_enabled := true

func _ready() -> void:
	ThemeDB.fallback_font = UI_FONT
	_register_inputs()
	_load_profile()
	backdrop = Backdrop.new()
	add_child(backdrop)
	sound = Sound.new()
	add_child(sound)
	arena = Arena.new()
	add_child(arena)
	arena.cleared.connect(_combat_cleared)
	arena.defeated.connect(_defeated)
	arena.feedback.connect(_combat_feedback)
	apartment_player = Arena.PLAYER_SCENE.instantiate()
	apartment_player.top_level = false
	apartment_player.allow_combat = false
	add_child(apartment_player)
	apartment_player.visible = false
	screen_fx = ScreenEffects.new()
	add_child(screen_fx)
	screen_fx.set_enabled(effects_enabled)
	arena.impact.connect(_combat_impact)
	var canvas := CanvasLayer.new()
	canvas.layer = 1
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel_theme := Theme.new()
	pixel_theme.default_font = UI_FONT
	pixel_theme.default_font_size = 20
	ui.theme = pixel_theme
	canvas.add_child(ui)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.theme = pixel_theme
	canvas.add_child(overlay)
	toast_label = _label(overlay, "", Rect2(180, 682, 920, 30), 15, MINT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(Color("101523"), BORDER, 10))
	toast_label.visible = false
	show_title()

func _register_inputs() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"dash": [KEY_SPACE, KEY_SHIFT], "sprint": [KEY_SHIFT],
		"attack": [KEY_J], "special": [KEY_K], "interact": [KEY_E]
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action in ["attack", "special"]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT if action == "attack" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast_label.visible = toast_time > 0
	if paused:
		return
	if phase == "apartment":
		labels["interact"].text = "E  /  STREAM" if apartment_player.position.distance_to(Vector2(340, 355)) < 100 else "PC  ←"
	elif phase == "stream":
		run.tick_stream(delta)
		stream_peak = maxi(stream_peak, int(run.viewers))
		_update_stream()
		if run.force_end_ready():
			bank_stream()
	elif phase == "combat" and is_instance_valid(arena.player):
		var player = arena.player
		labels["hp"].text = "%d / %d HP" % [ceili(player.hp), int(player.max_hp)]
		bars["hp"].value = 100.0 * player.hp / player.max_hp
		labels["dash"].text = "SPACE  " + ("DASH" if player.dash_remaining <= 0 else "%.1fs" % player.dash_remaining)
		labels["pulse"].text = "RMB  " + ("PULSE" if player.special_remaining <= 0 else "%.1fs" % player.special_remaining)
		labels["kills"].text = "%d KOs" % arena.kills
		var boss_visible: bool = arena.boss_max_hp > 0 and arena.boss_hp > 0
		bars["boss"].visible = boss_visible
		labels["boss"].visible = boss_visible
		if boss_visible:
			bars["boss"].value = arena.boss_hp / arena.boss_max_hp * 100.0
			labels["boss"].text = arena.boss_name.split("•")[0].strip_edges()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif event.keycode == KEY_M:
			_toggle_mute()
		elif event.keycode == KEY_ESCAPE and phase != "title":
			_toggle_pause()
		elif not paused and phase == "apartment" and event.keycode == KEY_E:
			if apartment_player.position.distance_to(Vector2(340, 355)) < 100:
				show_setup()
		elif not paused and phase == "stream":
			if event.keycode == KEY_SPACE:
				clip_moment()
			elif event.keycode in [KEY_A, KEY_LEFT]:
				_stream_action("left")
			elif event.keycode in [KEY_D, KEY_RIGHT]:
				_stream_action("right")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not paused and phase == "stream" and is_instance_valid(stage):
			_stream_action("click", stage.get_global_transform_with_canvas().affine_inverse() * event.position)

func _clear_ui() -> void:
	screen_fx.reset()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	labels.clear()
	bars.clear()
	choice_buttons.clear()
	stage = null
	bank_button = null
	clip_button = null
	toast_time = 0

func show_title() -> void:
	phase = "title"
	paused = false
	arena.set_active(false)
	arena.visible = false
	apartment_player.set_active(false)
	apartment_player.visible = false
	_clear_ui()
	backdrop.set_mode("title", 1, 0)
	sound.set_music("title")
	checkpoint = _read_json(SAVE_PATH)
	if not checkpoint.get("run", {}) is Dictionary:
		checkpoint = {}
	_label(ui, "A VERY ONLINE ACTION ROGUELITE", Rect2(666, 109, 570, 28), 15, MINT)
	_label(ui, "MAX", Rect2(655, 137, 580, 105), 96, TEXT)
	_label(ui, "CHAT HAS HANDS", Rect2(663, 240, 560, 56), 38, PURPLE)
	_label(ui, "Stream. Shop. Survive.", Rect2(669, 328, 516, 40), 23, DIM)
	var y := 414.0
	if not checkpoint.is_empty():
		_button(ui, "CONTINUE  /  DAY %d" % int(checkpoint.get("run", {}).get("day", 1)), Rect2(669, y, 500, 54), resume_run, MINT)
		y += 65
	_button(ui, "GO LIVE  //  NEW RUN", Rect2(669, y, 500, 54), _choose_starting_style, PURPLE)
	_button(ui, "HOW TO SURVIVE", Rect2(669, y + 66, 240, 43), _show_help, PANEL)
	_button(ui, "QUIT", Rect2(924, y + 66, 245, 43), func(): get_tree().quit(), PANEL)
	_label(ui, "6 DAYS  /  2 BOSSES  /  ZERO GRASS TOUCHED", Rect2(668, 621, 530, 27), 13, DIM)
	_label(ui, "BEST DAY  %d     RUNS  %d     WINS  %d" % [profile.best_day, profile.runs, profile.wins], Rect2(58, 650, 575, 24), 14, DIM)
	_global_buttons()

func begin_run() -> void:
	run.reset_run(selected_perk)
	run_kills = 0
	total_banked = 0
	stream_peak = 0
	profile.runs += 1
	_save_profile()
	sound.sfx("click")
	show_apartment()

func resume_run() -> void:
	if checkpoint.get("run", {}) is Dictionary and run.load_save(checkpoint.get("run", {})):
		run_kills = int(checkpoint.get("kills", 0))
		total_banked = int(checkpoint.get("banked", 0))
		stream_peak = int(checkpoint.get("peak", 0))
		if run.phase == "shop":
			show_shop()
		else:
			show_apartment()
	else:
		begin_run()

func show_apartment() -> void:
	phase = "apartment"
	arena.set_active(false)
	arena.visible = false
	_clear_ui()
	backdrop.set_mode("apartment", run.day, _equipment_level())
	sound.set_music("studio")
	apartment_player.visible = true
	apartment_player.bounds = Rect2(130, 305, 1030, 300)
	apartment_player.position = Vector2(780, 500)
	apartment_player.configure(run.combat_stats())
	apartment_player.set_active(true)
	_header("08:00", "")
	labels["interact"] = _label(ui, "PC  ←", Rect2(254, 341, 213, 37), 20, MINT)
	labels["interact"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer("WASD  /  MOVE                         E  /  USE PC")
	_save_checkpoint()

func show_setup() -> void:
	phase = "setup"
	arena.set_active(false)
	arena.visible = false
	apartment_player.set_active(false)
	_clear_ui()
	backdrop.set_mode("apartment", run.day, _equipment_level())
	sound.set_music("studio")
	_dim_room()
	_header("08:00  /  SELECT GAME", "")
	_label(ui, "SELECT GAME", Rect2(56, 189, 1140, 45), 40, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var accents := [MINT, PINK, GOLD]
	for i in RunModel.GAMES.size():
		var game: Dictionary = RunModel.GAMES[i]
		var x := 56.0 + i * 398
		_panel(ui, Rect2(x, 266, 376, 251), Color("11181d"), accents[i])
		_label(ui, str(game.get("ui_name", game.name)).to_upper(), Rect2(x + 22, 294, 334, 54), 31, TEXT)
		_label(ui, game.get("short_stats", game.subtitle), Rect2(x + 22, 355, 330, 60), 23, accents[i])
		_label(ui, {"cozy": "TIMING / SPACE", "sweaty": "AIM / MOUSE", "weird": "VERDICT / A + D"}.get(game.id, ""), Rect2(x + 22, 422, 330, 24), 17, DIM)
		_button(ui, "PLAY", Rect2(x + 20, 452, 336, 43), start_game.bind(game.id), accents[i])
	_button(ui, "BACK", Rect2(490, 554, 300, 44), show_apartment, PANEL)
	_save_checkpoint()

func _dim_room() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.035, 0.72)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

func start_game(id: String) -> void:
	run.begin_stream(id)
	phase = "stream"
	apartment_player.set_active(false)
	apartment_player.visible = false
	_clear_ui()
	backdrop.set_mode("apartment", run.day, _equipment_level())
	_dim_room()
	_header("LIVE", "")
	stage = Stage.new()
	stage.position = Vector2(46, 144)
	stage.size = Vector2(850, 478)
	stage.game_id = run.game_id
	ui.add_child(stage)
	stage.timed_out.connect(_stream_timeout)
	_panel(ui, Rect2(935, 144, 297, 478), Color("11181d"), BORDER)
	labels["timer"] = _label(ui, "08:00", Rect2(962, 160, 248, 60), 48, TEXT)
	_label(ui, "VIEWERS", Rect2(962, 237, 242, 25), 22, DIM)
	labels["viewers"] = _label(ui, "0", Rect2(958, 270, 251, 41), 36, MINT)
	bars["viewers"] = _bar(ui, Rect2(963, 322, 243, 9), MINT)
	labels["goal"] = _label(ui, "GOAL  " + _number(run.goal), Rect2(963, 343, 243, 28), 19, DIM)
	_label(ui, "DONATIONS", Rect2(962, 395, 241, 23), 22, DIM)
	labels["donations"] = _label(ui, "$0", Rect2(958, 425, 249, 42), 38, GOLD)
	labels["heat"] = _label(ui, "HEAT  0", Rect2(963, 499, 243, 28), 22, PINK)
	bars["heat"] = _bar(ui, Rect2(963, 537, 243, 8), PINK)
	labels["combo"] = _label(ui, "COMBO 0", Rect2(963, 565, 243, 31), 20, PURPLE)
	if run.game_id != "weird":
		clip_button = _button(ui, "SPACE / PLAY", Rect2(232, 637, 474, 41), clip_moment, MINT)
	_label(ui, str(run.game.get("ui_name", run.game.name)).to_upper(), Rect2(62, 108, 835, 30), 22, TEXT)
	_update_stream()
	sound.sfx("click")

func _update_stream() -> void:
	var minutes: int = 8 * 60 + mini(480, int(run.stream_time / RunModel.STREAM_LIMIT * 480.0))
	labels["timer"].text = "%02d:%02d" % [minutes / 60, minutes % 60]
	labels["viewers"].text = _number(run.viewers)
	bars["viewers"].value = run.viewers / run.goal * 100.0
	labels["goal"].text = ("GOAL HIT" if run.viewers >= run.goal else "GOAL  " + _number(run.goal))
	labels["donations"].text = "$%d" % int(run.stream_donations)
	labels["combo"].text = "COMBO %d  +%d%%" % [run.clip_streak, roundi((run.streak_multiplier() - 1.0) * 100)]
	labels["heat"].text = "HEAT  %d" % int(run.heat)
	bars["heat"].value = run.heat / 160.0 * 100.0
	stage.frozen = false
	stage.cooldown = run.clip_cooldown
	if is_instance_valid(clip_button):
		clip_button.disabled = not run.clip_ready()
		clip_button.text = stage.primary_label() if run.clip_ready() else "..."
	for button in choice_buttons:
		button.disabled = not run.clip_ready()

func clip_moment() -> void:
	_stream_action("primary")

func _stream_action(action: String, local_position: Vector2 = Vector2.ZERO) -> void:
	if phase != "stream" or paused or not run.current_event.is_empty() or not run.clip_ready():
		return
	var value: float = stage.resolve_action(action, local_position)
	if value < 0:
		return
	_record_stream_action(value)

func _stream_timeout() -> void:
	if phase == "stream" and not paused and run.clip_ready():
		_record_stream_action(0.0)

func _record_stream_action(value: float) -> void:
	var viewers_before: float = run.viewers
	var tips_before: float = run.stream_donations
	var result: String = run.try_clip(value)
	if result.is_empty():
		return
	var success := value >= 0.4 and value <= 0.6
	_toast("+%d VIEWERS  +$%.1f" % [roundi(run.viewers - viewers_before), run.stream_donations - tips_before] if success else "MISS  /  +3 HEAT", MINT if success else GOLD)
	sound.sfx("clip" if success else "click")
	_update_stream()

func choose_event(choice: int) -> void:
	if phase != "stream" or paused or run.current_event.is_empty():
		return
	var result: String = run.choose_event(choice)
	_toast(result, MINT)
	_add_chat("clip_goblin", result)
	sound.sfx("coin")
	_update_stream()

func bank_stream() -> void:
	if phase != "stream" or not run.can_end_stream():
		return
	var earned: int = run.end_stream()
	total_banked += earned
	show_shop()
	_toast("16:00  /  +$%d" % earned, GOLD)
	sound.sfx("coin")

func show_shop() -> void:
	phase = "shop"
	apartment_player.set_active(false)
	apartment_player.visible = false
	_clear_ui()
	backdrop.set_mode("apartment", run.day, _equipment_level())
	sound.set_music("shop")
	_dim_room()
	_header("16:00 / SHOP", "")
	_label(ui, "ITEMS", Rect2(53, 169, 889, 43), 38, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var offers: Array = run.shop_offers()
	for i in mini(offers.size(), 4):
		var offer: Dictionary = offers[i]
		var x := 48.0 + i * 228
		_panel(ui, Rect2(x, 237, 214, 289), Color("101619"), Color("3c5443"))
		var icon = preload("res://src/ui/item_icon.gd").new()
		icon.item_id = offer.id
		icon.position = Vector2(x + 76, 258)
		icon.size = Vector2(64, 64)
		ui.add_child(icon)
		_label(ui, str(offer.get("ui_name", offer.name)), Rect2(x + 14, 335, 187, 52), 25, TEXT)
		var info := _label(ui, str(offer.get("short_stats", offer.description)), Rect2(x + 14, 400, 186, 57), 21, MINT)
		info.tooltip_text = offer.description
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		var caption: String = "$%d" % int(offer.cost)
		if offer.get("sold", false):
			caption = "SOLD"
		elif offer.id == "medkit" and run.hp >= float(run.combat_stats().max_hp):
			caption = "FULL HP"
		var b := _button(ui, caption, Rect2(x + 14, 470, 186, 37), buy_upgrade.bind(offer.id), MINT)
		b.disabled = not bool(offer.get("affordable", false))
	_panel(ui, Rect2(984, 181, 247, 381), Color("101619"), BORDER)
	_label(ui, "STATS", Rect2(1005, 198, 201, 37), 30, TEXT)
	var stats: Dictionary = run.combat_stats()
	var rows: Array = [
		["HP", "%d/%d" % [stats.hp, stats.max_hp]],
		["DAMAGE", "%d%%" % int(stats.damage * 100)],
		["ATK SPEED", "%d%%" % int(stats.attack_speed * 100)],
		["ARMOR", str(stats.armor)],
		["MOVE", "%d%%" % int(stats.move_speed * 100)],
		["VIEWERS", "%d%%" % int(run.viewer_multiplier() * 100)],
		["DONATIONS", "%d%%" % int(run.donation_multiplier() * 100)],
		["HEAT", str(int(run.heat))]
	]
	for i in rows.size():
		_label(ui, rows[i][0], Rect2(1004, 249 + i * 35, 142, 27), 18, DIM)
		var value := _label(ui, rows[i][1], Rect2(1118, 249 + i * 35, 91, 27), 20, MINT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var reroll := _button(ui, "REROLL  $%d" % run.reroll_cost(), Rect2(347, 552, 300, 43), _reroll_shop, MINT)
	reroll.disabled = run.donations < run.reroll_cost()
	var owned: Array = run.owned_weapons()
	for i in owned.size():
		var weapon_id: String = owned[i]
		var button := _button(ui, ("> " if run.weapon == weapon_id else "") + weapon_id.to_upper(), Rect2(49 + i * 302, 624, 286, 34), _equip_weapon.bind(weapon_id), MINT)
		button.add_theme_font_size_override("font_size", 18)
	_button(ui, "NEXT  >", Rect2(984, 601, 247, 58), show_knock, MINT)
	_save_checkpoint()

func buy_upgrade(id: String) -> void:
	if phase != "shop":
		return
	if run.buy_upgrade(id):
		sound.sfx("coin")
		show_shop()
		_toast("ITEM BOUGHT", GOLD)
	else:
		_toast("CAN'T BUY", PINK)

func _equip_weapon(id: String) -> void:
	if run.equip_weapon(id):
		sound.sfx("click")
		show_shop()

func show_knock() -> void:
	phase = "knock"
	_clear_ui()
	backdrop.set_mode("yard", run.day, _equipment_level())
	backdrop.set_door_alert(true)
	sound.sfx("knock")
	_header("KNOCK KNOCK", "")
	_panel(ui, Rect2(415, 353, 450, 233), Color("101619"), PINK)
	_label(ui, "HATERS OUTSIDE", Rect2(443, 374, 396, 42), 34, TEXT)
	_label(ui, "WASD  MOVE     LMB  ATTACK
SPACE  DASH     RMB  PULSE", Rect2(443, 431, 396, 63), 22, DIM)
	_button(ui, "FIGHT", Rect2(443, 512, 395, 46), start_combat, MINT)

func start_combat() -> void:
	phase = "combat"
	_clear_ui()
	backdrop.set_door_alert(false)
	sound.set_music("boss" if run.day % 3 == 0 else "combat")
	arena.visible = true
	arena.process_mode = Node.PROCESS_MODE_INHERIT
	var stats: Dictionary = run.start_combat()
	arena.start_encounter(run.day, run.heat, stats)
	_header("DEFEND YOUR FRONT YARD", "Your moderation policy is now physical.")
	labels["hp"] = labels["header_hp"]
	bars["hp"] = _bar(ui, Rect2(42, 95, 204, 8), MINT)
	labels["kills"] = _label(ui, "0 HATERS MUTED", Rect2(974, 112, 250, 24), 15, GOLD)
	labels["boss"] = _label(ui, "", Rect2(400, 112, 480, 24), 16, PINK)
	labels["boss"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bars["boss"] = _bar(ui, Rect2(430, 141, 420, 9), PINK)
	labels["dash"] = _label(ui, "SPACE  DASH", Rect2(58, 648, 330, 28), 15, MINT)
	labels["pulse"] = _label(ui, "RMB / K  TOUCH GRASS", Rect2(393, 648, 439, 28), 15, PURPLE)
	_label(ui, "WASD   /   LMB", Rect2(1006, 648, 223, 28), 20, DIM)

func _combat_feedback(message: String) -> void:
	if phase == "combat" and ("ENRAGED" in message or "MODZILLA" in message or "ALGORITHM" in message):
		_toast(message.split("•")[0].strip_edges(), GOLD)

func _combat_impact(strength: float) -> void:
	if phase == "combat" and not paused:
		screen_fx.impulse(strength)

func _combat_cleared(reward: int) -> void:
	if phase != "combat":
		return
	previous_day = run.day
	encounter_reward = reward
	run_kills += arena.kills
	var won: bool = run.finish_combat(reward, arena.player.hp)
	profile.best_day = maxi(int(profile.best_day), previous_day)
	profile.peak = maxi(int(profile.peak), stream_peak)
	_save_profile()
	arena.set_active(false)
	if won:
		profile.wins += 1
		_save_profile()
		_delete_checkpoint()
		_show_end(true)
	else:
		_save_checkpoint()
		show_reward()

func show_reward() -> void:
	phase = "reward"
	_clear_ui()
	_header("DAY %d CLEAR" % previous_day, "")
	_panel(ui, Rect2(428, 260, 424, 261), Color("101619"), MINT)
	_label(ui, "SURVIVED", Rect2(456, 285, 365, 55), 47, TEXT)
	_label(ui, "+$%d" % encounter_reward, Rect2(457, 358, 362, 43), 36, GOLD)
	_button(ui, "NEXT MORNING  >", Rect2(456, 442, 369, 49), show_apartment, MINT)
	sound.set_music("reward")
	sound.sfx("win")

func _defeated() -> void:
	if phase != "combat":
		return
	run_kills += arena.kills
	run.finish_combat(0, 0)
	profile.best_day = maxi(int(profile.best_day), run.day)
	profile.peak = maxi(int(profile.peak), stream_peak)
	_save_profile()
	_delete_checkpoint()
	_show_end(false)

func _show_end(won: bool) -> void:
	phase = "won" if won else "dead"
	arena.set_active(false)
	_clear_ui()
	sound.set_music("title")
	sound.sfx("win" if won else "lose")
	_panel(ui, Rect2(286, 117, 708, 499), Color("141b2e"), MINT if won else PINK)
	_label(ui, "SIX DAYS. ONE LEGEND." if won else "STREAM DISCONNECTED", Rect2(324, 147, 637, 34), 18, MINT if won else PINK)
	_label(ui, "YOU BROKE THE\nALGORITHM." if won else "CHAT GOT HANDS.", Rect2(320, 195, 644, 108), 43, TEXT)
	_label(ui, "Max is famous. The lawn is ruined.\nYour mother still asks when you'll get a real job." if won else "The run ends. The clips live forever.\nTry another category, weapon, or deeply unhealthy synergy.", Rect2(325, 319, 627, 65), 19, DIM)
	_label(ui, "DAY %d    •    %d KOs    •    $%d BANKED    •    %s PEAK" % [mini(run.day, 6), run_kills, total_banked, _number(stream_peak)], Rect2(325, 405, 630, 35), 17, GOLD)
	if profile.best_day >= 3:
		_label(ui, "STARTING STYLES UNLOCKED  //  Choose one on your next run.", Rect2(325, 454, 640, 23), 13, PURPLE)
	_button(ui, "ONE MORE RUN", Rect2(325, 516, 301, 54), _choose_starting_style, MINT)
	_button(ui, "MAIN MENU", Rect2(641, 516, 309, 54), show_title, PANEL)

func _choose_starting_style() -> void:
	if profile.best_day < 3:
		begin_run()
		return
	_clear_ui()
	phase = "styles"
	_header("A DIFFERENT FLAVOR OF BAD IDEA", "Sidegrades change the starting build. Everything else is earned during the run.")
	var styles := [
		["", "SMALL-TIME LEGEND", "A stock keyboard, 100 HP, and a dream.\nThe classic balanced start."],
		["spicy", "RAGEBAIT ROOKIE", "+25% stream donations and KO bounties.\nMore heat. Less health. Good luck."],
		["cozy", "COMFORT CREATOR", "+15% viewer growth and armor.\nSofter hits. Maximum cozy energy."]
	]
	for i in styles.size():
		var x := 56.0 + i * 398
		_panel(ui, Rect2(x, 240, 376, 290), PANEL, PURPLE)
		_label(ui, styles[i][1], Rect2(x + 22, 274, 335, 40), 24, TEXT)
		_label(ui, styles[i][2], Rect2(x + 22, 338, 329, 90), 18, DIM)
		_button(ui, "START THIS BUILD", Rect2(x + 22, 455, 332, 48), func(): selected_perk = styles[i][0]; begin_run(), MINT)

func _header(title: String, _subtitle: String) -> void:
	_panel(ui, Rect2(26, 18, 234, 76), Color("101619"), BORDER)
	var stats: Dictionary = run.combat_stats()
	labels["header_hp"] = _label(ui, "%d / %d HP" % [stats.hp, stats.max_hp], Rect2(42, 24, 201, 27), 22, MINT)
	_label(ui, "$%d" % run.donations, Rect2(42, 57, 201, 29), 28, GOLD)
	_label(ui, "DAY %d" % mini(run.day, 6), Rect2(427, 17, 426, 35), 32, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(ui, title, Rect2(320, 57, 640, 29), 22, DIM).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_global_buttons()

func _global_buttons() -> void:
	music_button = _button(ui, "M / OFF" if muted else "M / ON", Rect2(1161, 17, 81, 28), _toggle_mute, PANEL)
	music_button.add_theme_font_size_override("font_size", 11)
	if phase != "title":
		var b := _button(ui, "PAUSE", Rect2(1161, 52, 81, 26), _toggle_pause, PANEL)
		b.add_theme_font_size_override("font_size", 11)

func _footer(text: String) -> void:
	_label(ui, text, Rect2(58, 648, 1165, 39), 14, DIM)

func _toggle_mute() -> void:
	muted = not muted
	sound.set_muted(muted)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	if is_instance_valid(music_button):
		music_button.text = "M / OFF" if muted else "M / ON"

func _toggle_pause() -> void:
	if phase == "title":
		return
	paused = not paused
	screen_fx.reset()
	screen_fx.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	arena.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	apartment_player.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(stage):
		stage.frozen = paused or not run.current_event.is_empty()
	for child in overlay.get_children():
		if child != toast_label:
			child.queue_free()
	if not paused:
		return
	var shade := ColorRect.new()
	shade.size = Vector2(1280, 720)
	shade.color = Color(0.025, 0.035, 0.07, 0.86)
	overlay.add_child(shade)
	_panel(overlay, Rect2(417, 141, 446, 449), PANEL, PURPLE)
	_label(overlay, "BRB. TOUCHING GRASS.", Rect2(449, 166, 398, 43), 25, TEXT)
	var controls := "WASD / arrows  ·  Move\nMouse / LMB or J  ·  Aim / attack\nSpace / Shift  ·  Dash\nRMB / K  ·  Touch Grass pulse"
	if phase == "apartment":
		controls = "WASD / arrows  ·  Move\nE near the PC  ·  Play"
	elif phase == "stream":
		controls = {"cozy": "SPACE  ·  Harvest in the green", "sweaty": "LMB  ·  Click the pink target\nSPACE in green  ·  Aim assist", "weird": "Flower  ·  A / FREE\nStolen bread  ·  D / BONK\nLeft / right arrows also work"}.get(run.game_id, "")
	elif phase == "shop":
		controls = "Click an item  ·  Buy\nREROLL  ·  New items\nClick a weapon  ·  Equip\nNEXT  ·  Answer the door"
	_label(overlay, controls + "\n\nF11  ·  Fullscreen     M  ·  Audio", Rect2(450, 223, 386, 140), 17, DIM)
	var fx_button := _button(overlay, "", Rect2(450, 372, 380, 32), _toggle_effects, PANEL)
	fx_button.name = "EffectsToggle"
	fx_button.text = "SHAKE + BLOOM / " + ("ON" if effects_enabled else "OFF")
	_button(overlay, "BACK TO THE CHAOS", Rect2(450, 420, 380, 47), _toggle_pause, MINT)
	_button(overlay, "MENU  /  KEEP CHECKPOINT", Rect2(450, 484, 380, 39), func(): _toggle_pause(); show_title(), PANEL)

func _toggle_effects() -> void:
	effects_enabled = not effects_enabled
	screen_fx.set_enabled(effects_enabled)
	var toggle := overlay.get_node_or_null("EffectsToggle") as Button
	if toggle:
		toggle.text = "SHAKE + BLOOM / " + ("ON" if effects_enabled else "OFF")
	_save_profile()

func _show_help() -> void:
	_clear_ui()
	phase = "help"
	_panel(ui, Rect2(272, 110, 736, 500), Color("101619"), BORDER)
	_label(ui, "HOW TO PLAY", Rect2(309, 139, 660, 54), 42, TEXT)
	_label(ui, "MORNING    WASD to PC. E to play.\nSTREAM       Harvest. Aim. Judge geese.\n                       08:00 - 16:00. 64 seconds.\nSHOP           Buy items. Reroll. Equip weapons.\nFIGHT          WASD + mouse. Hold LMB.\n                       SPACE dodge. RMB pulse.\n\n6 days. 2 bosses. One run.", Rect2(310, 215, 660, 273), 25, DIM)
	_button(ui, "OK", Rect2(310, 526, 660, 46), show_title, MINT)

func _equipment_level() -> int:
	var count := 0
	for key in run.upgrades:
		count += int(run.upgrades[key])
	return count

func _add_chat(user: String, text: String) -> void:
	chat_lines.append(user + "\n" + text)
	while chat_lines.size() > 3:
		chat_lines.pop_front()
	if labels.has("chat"):
		labels.chat.text = "\n\n".join(chat_lines)

func _ambient_chat() -> void:
	var comments := [
		["lawn_enjoyer", "outside graphics go crazy"],
		["buffering_irl", "my toaster runs this better"],
		["tax_goblin", "are donations a build?"],
		["definitely_a_mod", "please stop feeding the algorithm"],
		["mom_alt_account", "did you get the package honey"],
		["skill_issue_404", "I could do that. Hypothetically."],
		["keyboard_sommelier", "that click has notes of violence"],
		["ratio_delivery", "your order is approaching the house"],
		["one_real_viewer", "honestly this is kind of a vibe"]
	]
	var comment: Array = comments.pick_random()
	_add_chat(comment[0], comment[1])

func _toast(message: String, color: Color = MINT) -> void:
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_time = 3.2

func _number(value: float) -> String:
	return "%.1fk" % (value / 1000.0) if value >= 1000 else str(int(value))

func _style(fill: Color, border: Color, _radius := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _panel(parent: Node, rect: Rect2, color: Color, border: Color, radius := 12) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", _style(color, border, radius))
	parent.add_child(node)
	return node

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("line_spacing", 3)
	label.text = text
	parent.add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, _color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("12200c"))
	button.add_theme_color_override("font_hover_color", Color("12200c"))
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color("78859e"))
	button.add_theme_stylebox_override("normal", _pixel_button(BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", _pixel_button(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _pixel_button(BUTTON_PRESSED))
	button.add_theme_stylebox_override("disabled", _style(Color("252e41"), BORDER, 7))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _pixel_button(texture: Texture2D) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 4
	style.texture_margin_right = 4
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _style(Color("303a50"), Color("303a50"), 4)
	var fill := _style(color, color, 4)
	for box in [background, fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	bar.position = rect.position
	bar.size = rect.size
	return bar

func _read_json(path: String) -> Dictionary:
	if not persistence_enabled:
		return {}
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}

func _write_json(path: String, data: Dictionary) -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(path + ".tmp", path)

func _load_profile() -> void:
	var saved := _read_json(PROFILE_PATH)
	effects_enabled = bool(saved.get("effects_enabled", true))
	for key in profile:
		profile[key] = maxi(0, int(saved.get(key, 0)))

func _save_profile() -> void:
	var saved := profile.duplicate()
	saved["effects_enabled"] = effects_enabled
	_write_json(PROFILE_PATH, saved)

func _save_checkpoint() -> void:
	var data: Dictionary = run.to_save()
	if not data.is_empty():
		_write_json(SAVE_PATH, {"run": data, "kills": run_kills, "banked": total_banked, "peak": stream_peak})

func _delete_checkpoint() -> void:
	if not persistence_enabled:
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _reroll_shop() -> void:
	if phase == "shop" and run.reroll_shop():
		sound.sfx("click")
		show_shop()
