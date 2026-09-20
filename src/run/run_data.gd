class_name RunData
extends RefCounted
## The entire run economy lives here. No scene or input dependencies: it is also
## exercised by tests/model_test.gd with Godot's headless runner.

const MAX_DAYS: int = 6
const STREAM_LIMIT: float = 64.0
const GOALS: Array[int] = [80, 240, 900, 3200, 12000, 50000]
const GAMES: Array[Dictionary] = [
	{"id": "cozy", "name": "Turnip Tax Simulator", "ui_name": "Turnip Farm", "short_stats": "Steady viewers / low heat", "subtitle": "COZY / LOW HEAT", "description": "Grow a tiny farm. Explain vegetable tax fraud. Steady viewers, fewer Haters.", "viewer_rate": 2.25, "donation_rate": 1.25, "heat_rate": 0.32, "color": Color("76d9b0")},
	{"id": "sweaty", "name": "Ranked & Bankrupt", "ui_name": "Ranked Rush", "short_stats": "Fast viewers / high heat", "subtitle": "COMPETITIVE / FAST GROWTH", "description": "One more ranked match. Fast audience growth, loud donations, louder Haters.", "viewer_rate": 3.05, "donation_rate": 1.50, "heat_rate": 0.83, "color": Color("ff977a")},
	{"id": "weird", "name": "Goose Court Online", "ui_name": "Goose Court", "short_stats": "Bigger tips / medium heat", "subtitle": "ABSURD / BIG TIPS", "description": "Defend geese in internet court. Tips are generous; chat makes everything weird.", "viewer_rate": 2.45, "donation_rate": 1.85, "heat_rate": 0.57, "color": Color("c1a0ff")},
]
const PERKS: Array[Dictionary] = [
	{"id": "", "name": "Small-Time Legend", "description": "A borrowed keyboard and unreasonable confidence. Balanced start."},
	{"id": "spicy", "name": "Ragebait Rookie", "description": "+25% stream donations, +2 per KO, +30% heat. Start with 90 HP."},
	{"id": "cozy", "name": "Comfort Creator", "description": "+15% viewers and +1 armor. Deal 12% less damage."},
]
const UPGRADES: Dictionary = {
	"medkit": {"name": "Emergency Touch Grass", "description": "Recover 45 HP. One restorative lawn visit per shop.", "cost": 18, "category": "SUSTAIN", "max_stacks": 99},
	"banhammer": {"name": "The Banhammer", "description": "Equip a heavy sweep: more damage and reach, slower swings. BONK is a moderation policy.", "cost": 52, "category": "WEAPON", "max_stacks": 1},
	"capslock": {"name": "Caps Lock Cannon", "description": "Equip a rapid ranged attack. Kite the reply guys while typing in ALL CAPS.", "cost": 58, "category": "WEAPON", "max_stacks": 1},
	"webcam": {"name": "Suspiciously HD Webcam", "description": "+18% viewer growth. Chat can finally count your pixels.", "cost": 24, "category": "STREAM", "max_stacks": 3},
	"fiber": {"name": "Fiber of Your Being", "description": "+25% viewer growth, +10% heat. Your bad takes now arrive instantly.", "cost": 32, "category": "STREAM", "max_stacks": 3},
	"tip_jar": {"name": "Emotionally Available Tip Jar", "description": "+25% stream donations. The jar believes in you.", "cost": 30, "category": "STREAM", "max_stacks": 3},
	"clip_lab": {"name": "Clip Goblin", "description": "+40% viewers and tips from clean clips. Clip cooldown -0.15 seconds.", "cost": 30, "category": "STREAM", "max_stacks": 2},
	"vitality": {"name": "Ergonomic Exoskeleton", "description": "+22 maximum HP and immediately recover 22 HP. Now with lumbar revenge.", "cost": 38, "category": "COMBAT", "max_stacks": 3},
	"protein": {"name": "Sponsored Protein", "description": "+18% attack damage. Legally described as food-adjacent.", "cost": 32, "category": "COMBAT", "max_stacks": 3},
	"coffee": {"name": "Third Coffee", "description": "+14% attack speed. Your keyboard has started sweating.", "cost": 32, "category": "COMBAT", "max_stacks": 3},
	"sneakers": {"name": "Grass-Proof Sneakers", "description": "+10% movement speed and 12% faster dash recovery.", "cost": 26, "category": "COMBAT", "max_stacks": 3},
	"armor": {"name": "Foam Acoustic Armor", "description": "+2 armor. Absorbs both damage and terrible opinions.", "cost": 34, "category": "DEFENSE", "max_stacks": 3},
	"rage_drive": {"name": "Rage-to-Wage Converter", "description": "Stream heat becomes attack damage: +0.3% per heat, up to +45% per stack.", "cost": 42, "category": "SYNERGY", "max_stacks": 2},
	"hater_bonds": {"name": "Hater Investment Fund", "description": "+3 donations per defeated Hater. A deeply questionable growth strategy.", "cost": 35, "category": "SYNERGY", "max_stacks": 3},
	"vampire": {"name": "Parasocial Vampire", "description": "Recover 4 HP whenever a Hater goes down. Feed on the engagement.", "cost": 40, "category": "SYNERGY", "max_stacks": 2},
	"security": {"name": "Automated Lawn Moderator", "description": "A yard turret helps remove unwanted opinions. Extra levels improve its fire rate.", "cost": 40, "category": "DEFENSE", "max_stacks": 3},
	"thorns": {"name": "Reflective Comment Section", "description": "Reflect 6 damage when hit. Reply all, physically.", "cost": 30, "category": "DEFENSE", "max_stacks": 2},
	"fan_club": {"name": "Redemption Arc", "description": "Each yard clear returns 8% of tomorrow's goal as fans (cap 30%) and restores 8 HP.", "cost": 36, "category": "SYNERGY", "max_stacks": 2},
}
const UI_ITEMS: Dictionary = {
	"medkit": ["Fresh Air", "+45 HP"], "banhammer": ["Banhammer", "Heavy melee / wide sweep"],
	"capslock": ["Caps Lock", "Rapid ranged shots"], "webcam": ["HD Webcam", "+18% viewers"],
	"fiber": ["Fiber", "+25% viewers / +10% heat"], "tip_jar": ["Tip Jar", "+25% donations"],
	"clip_lab": ["Clip Goblin", "+40% game rewards"], "vitality": ["Ergo Chair", "+22 max HP / heal 22"],
	"protein": ["Protein", "+18% damage"], "coffee": ["Coffee", "+14% attack speed"],
	"sneakers": ["Sneakers", "+10% speed / faster dash"], "armor": ["Foam Armor", "+2 armor"],
	"rage_drive": ["Rage Converter", "Heat gives up to +45% damage"], "hater_bonds": ["Hater Fund", "+$3 per KO"],
	"vampire": ["Vampire", "+4 HP per KO"], "security": ["Lawn Turret", "+1 turret level"],
	"thorns": ["Reply Shield", "Reflect 6 damage"], "fan_club": ["Fan Club", "+8% returning fans / +8 HP"],
}

var day: int = 1
var donations: int = 20
var hp: float = 100.0
var viewers: float = 5.0
var goal: float = 80.0
var heat: float = 0.0
var hype: float = 20.0
var stream_donations: float = 0.0
var stream_time: float = 0.0
var current_event: Dictionary = {}
var phase: String = "setup"
var game_id: String = ""
var game: Dictionary = {}
var starting_perk: String = ""
var upgrades: Dictionary = {}
var weapon: String = "keyboard"
var clip_cooldown: float = 0.0
var clips_hit: int = 0
var loyalty_fans: int = 0
var total_donations: int = 0
var peak_viewers: int = 0
var last_stream_income: int = 0
var last_combat_reward: int = 0
var rerolls: int = 0
var _offer_ids: Array[String] = []
var _shop_bought: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	reset_run()

func reset_run(perk: String = "") -> void:
	starting_perk = perk if perk in ["", "spicy", "cozy"] else ""
	day = 1
	donations = 20
	upgrades = {}
	weapon = "keyboard"
	hp = 90.0 if starting_perk == "spicy" else 100.0
	phase = "setup"
	loyalty_fans = 0
	total_donations = 0
	peak_viewers = 0
	last_stream_income = 0
	last_combat_reward = 0
	rerolls = 0
	_offer_ids.clear()
	_shop_bought.clear()
	_rng.randomize()
	_reset_stream()

func _reset_stream() -> void:
	goal = float(GOALS[day - 1])
	viewers = 5.0 + float((day - 1) * 4 + loyalty_fans)
	heat = 0.0
	hype = 20.0
	stream_donations = 0.0
	stream_time = 0.0
	clip_cooldown = 0.0
	clips_hit = 0
	current_event = {}
	game_id = ""
	game = {}

func begin_stream(selected_game_id: String) -> void:
	if phase != "setup":
		return
	for definition in GAMES:
		if definition["id"] == selected_game_id:
			game = definition.duplicate(true)
			game_id = selected_game_id
			phase = "stream"
			return

func tick_stream(delta: float) -> void:
	if phase != "stream" or not current_event.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	# A stalled application never silently simulates a whole dangerous minute.
	var step: float = minf(delta, 1.0)
	step = minf(step, STREAM_LIMIT - stream_time)
	if step <= 0.0:
		return
	var overtime: bool = viewers >= goal
	# Audience scale grows by orders of magnitude; time commitment does not.
	var scale: float = (goal / float(GOALS[0])) / (1.0 + float(day - 1) * 0.06)
	var growth: float = float(game["viewer_rate"]) * 0.4 * scale * viewer_multiplier() * (1.0 + hype / 160.0)
	viewers += growth * step
	stream_donations += float(game["donation_rate"]) * 0.55 * (1.0 + float(day - 1) * 0.24) * donation_multiplier() * (1.0 + hype / 200.0) * step * (1.15 if overtime else 1.0)
	var heat_rate: float = float(game["heat_rate"]) * (1.0 + float(_count("fiber")) * 0.10)
	if starting_perk == "spicy":
		heat_rate *= 1.30
	if overtime:
		heat_rate += 1.6 + maxf(viewers / goal - 1.0, 0.0) * 1.8
	heat = clampf(heat + heat_rate * step, 0.0, 160.0)
	hype = maxf(10.0, hype - 0.32 * step)
	stream_time += step
	clip_cooldown = maxf(0.0, clip_cooldown - step)
	peak_viewers = maxi(peak_viewers, int(viewers))

func choose_event(choice: int) -> String:
	if phase != "stream" or current_event.is_empty() or choice < 0 or choice >= current_event["choices"].size():
		return ""
	var effects: Dictionary = current_event["effects"][choice]
	var parts: Array[String] = []
	if effects.has("viewers"):
		var gained: int = maxi(1, roundi(goal * float(effects["viewers"]) * 0.55 * (1.0 + hype / 300.0)))
		viewers += gained
		parts.append("+%d viewers" % gained)
	if effects.has("money"):
		var money: int = maxi(1, roundi(float(effects["money"]) * donation_multiplier() * (1.0 + float(day - 1) * 0.15)))
		stream_donations += money
		parts.append("+$%d" % money)
	if effects.has("heat"):
		var heat_change: float = float(effects["heat"])
		heat = clampf(heat + heat_change, 0.0, 160.0)
		parts.append("%+d heat" % roundi(heat_change))
	if effects.has("hype"):
		hype = clampf(hype + float(effects["hype"]), 0.0, 100.0)
	peak_viewers = maxi(peak_viewers, int(viewers))
	current_event = {}
	return "  |  ".join(parts)

func clip_ready() -> bool:
	return phase == "stream" and current_event.is_empty() and clip_cooldown <= 0.0 and stream_time < STREAM_LIMIT

func try_clip(value: float) -> String:
	if not clip_ready() or not is_finite(value):
		return ""
	clip_cooldown = maxf(1.2, 1.65 - float(_count("clip_lab")) * 0.15)
	if value >= 0.40 and value <= 0.60:
		var clip_mult: float = 1.0 + float(_count("clip_lab")) * 0.40
		var gain: int = maxi(1, roundi(goal * 0.018 * clip_mult))
		var tips: int = maxi(1, roundi((1.0 + float(day - 1) * 0.3) * clip_mult * donation_multiplier()))
		viewers += gain
		stream_donations += tips
		hype = minf(100.0, hype + 6.0)
		heat = maxf(0.0, heat - 1.5)
		clips_hit += 1
		peak_viewers = maxi(peak_viewers, int(viewers))
		return "CLEAN CLIP! +%d viewers / +$%d" % [gain, tips]
	hype = maxf(0.0, hype - 5.0)
	heat = minf(160.0, heat + 3.0)
	return "Scuffed clip. Chat noticed. +3 heat"

func can_end_stream() -> bool:
	return phase == "stream" and stream_time >= STREAM_LIMIT

func force_end_ready() -> bool:
	return can_end_stream() and stream_time >= STREAM_LIMIT

func end_stream() -> int:
	if not can_end_stream():
		return 0
	last_stream_income = maxi(1, floori(stream_donations)) + (16 + day * 5 if viewers >= goal else 0)
	donations += last_stream_income
	total_donations += last_stream_income
	phase = "shop"
	current_event = {}
	rerolls = 0
	_shop_bought.clear()
	_generate_shop()
	return last_stream_income

func shop_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if phase != "shop":
		return result
	for id in _offer_ids:
		var offer: Dictionary = UPGRADES[id].duplicate(true)
		offer["id"] = id
		offer["ui_name"] = str(UI_ITEMS[id][0])
		offer["short_stats"] = str(UI_ITEMS[id][1])
		offer["owned"] = _count(id)
		offer["cost"] = upgrade_cost(id)
		offer["sold"] = _shop_bought.has(id)
		offer["affordable"] = donations >= int(offer["cost"]) and not bool(offer["sold"]) and (id != "medkit" or hp < float(combat_stats()["max_hp"]))
		result.append(offer)
	return result

func upgrade_cost(id: String) -> int:
	if not UPGRADES.has(id):
		return 0
	if id == "medkit":
		return 18
	return roundi(float(UPGRADES[id]["cost"]) * (1.0 + float(_count(id)) * 0.30))

func buy_upgrade(id: String) -> bool:
	if phase != "shop" or not id in _offer_ids or _shop_bought.has(id) or not UPGRADES.has(id):
		return false
	var cost: int = upgrade_cost(id)
	if donations < cost or _count(id) >= int(UPGRADES[id]["max_stacks"]):
		return false
	if id == "medkit" and hp >= float(combat_stats()["max_hp"]):
		return false
	donations -= cost
	_shop_bought[id] = true
	if id == "medkit":
		hp = minf(float(combat_stats()["max_hp"]), hp + 45.0)
		return true
	upgrades[id] = _count(id) + 1
	if id == "banhammer" or id == "capslock":
		weapon = id
	elif id == "vitality":
		hp = minf(float(combat_stats()["max_hp"]), hp + 22.0)
	return true

func equip_weapon(id: String) -> bool:
	if not phase in ["setup", "shop"] or not id in ["keyboard", "banhammer", "capslock"]:
		return false
	if id != "keyboard" and _count(id) == 0:
		return false
	weapon = id
	return true

func owned_weapons() -> Array[String]:
	var result: Array[String] = ["keyboard"]
	for id in ["banhammer", "capslock"]:
		if _count(id) > 0:
			result.append(id)
	return result

func reroll_cost() -> int:
	return 6 + day * 3 + rerolls * 4

func reroll_shop() -> bool:
	if phase != "shop" or donations < reroll_cost():
		return false
	donations -= reroll_cost()
	rerolls += 1
	_generate_shop()
	return true

func _generate_shop() -> void:
	_offer_ids.assign(["medkit"])
	# Four readable cards; rerolling changes stock without resetting sold items.
	_append_random_offer(["banhammer", "capslock"])
	_append_random_offer(["webcam", "fiber", "tip_jar", "clip_lab"])
	if _offer_ids.size() < 3:
		_append_random_offer(["protein", "coffee", "sneakers", "vitality", "armor"])
	_append_random_offer(["protein", "coffee", "sneakers", "vitality", "armor", "rage_drive", "hater_bonds", "vampire", "security", "thorns", "fan_club"])
	var all_ids: Array = UPGRADES.keys()
	while _offer_ids.size() < 4:
		if not _append_random_offer(all_ids):
			break

func _append_random_offer(pool: Array) -> bool:
	var candidates: Array[String] = []
	for value in pool:
		var id: String = str(value)
		if not id in _offer_ids and not _shop_bought.has(id) and id != "medkit" and _count(id) < int(UPGRADES[id]["max_stacks"]):
			candidates.append(id)
	if candidates.is_empty():
		return false
	_offer_ids.append(candidates[_rng.randi_range(0, candidates.size() - 1)])
	return true

func start_combat() -> Dictionary:
	if phase == "shop":
		phase = "combat"
	return combat_stats()

func combat_stats() -> Dictionary:
	var max_hp: float = (90.0 if starting_perk == "spicy" else 100.0) + float(_count("vitality")) * 22.0
	var damage: float = (1.0 + float(_count("protein")) * 0.18) * (0.88 if starting_perk == "cozy" else 1.0)
	var rage: float = minf(0.45, heat * 0.003) * float(_count("rage_drive"))
	damage *= 1.0 + rage
	return {
		"max_hp": max_hp, "hp": clampf(hp, 0.0, max_hp), "damage": damage,
		"attack_speed": 1.0 + float(_count("coffee")) * 0.14,
		"move_speed": 1.0 + float(_count("sneakers")) * 0.10,
		"dash_cooldown": pow(0.88, _count("sneakers")), "weapon": weapon,
		"armor": _count("armor") * 2 + (1 if starting_perk == "cozy" else 0),
		"lifesteal": _count("vampire") * 4, "security": _count("security"),
		"bounty": _count("hater_bonds") * 3 + (2 if starting_perk == "spicy" else 0),
		"rage": rage, "thorns": _count("thorns") * 6,
	}

func viewer_multiplier() -> float:
	return (1.0 + float(_count("webcam")) * 0.18 + float(_count("fiber")) * 0.25) * (1.15 if starting_perk == "cozy" else 1.0)

func donation_multiplier() -> float:
	return (1.0 + float(_count("tip_jar")) * 0.25) * (1.25 if starting_perk == "spicy" else 1.0)

func enemy_budget() -> int:
	return clampi(3 + day * 2 + floori(heat / 20.0), 5, 22)

func finish_combat(reward: int, remaining_hp: float) -> bool:
	if phase != "combat" or not is_finite(remaining_hp):
		return false
	hp = clampf(remaining_hp, 0.0, float(combat_stats()["max_hp"]))
	if hp <= 0.0:
		phase = "lost"
		return false
	last_combat_reward = maxi(0, reward)
	donations += last_combat_reward
	total_donations += last_combat_reward
	var next_goal: float = float(GOALS[mini(day, MAX_DAYS - 1)])
	loyalty_fans = mini(roundi(next_goal * 0.30), loyalty_fans + roundi(next_goal * 0.08) * _count("fan_club"))
	hp = minf(float(combat_stats()["max_hp"]), hp + 8.0 + float(_count("fan_club")) * 8.0)
	if day >= MAX_DAYS:
		phase = "won"
		return true
	day += 1
	phase = "setup"
	_offer_ids.clear()
	_shop_bought.clear()
	_reset_stream()
	return false

func build_summary() -> Array[String]:
	var lines: Array[String] = []
	for perk in PERKS:
		if perk["id"] == starting_perk:
			lines.append(str(perk["name"]))
	lines.append("Weapon: " + (str(UPGRADES[weapon]["name"]) if UPGRADES.has(weapon) else "Trusty Keyboard"))
	for id in upgrades:
		if id == "banhammer" or id == "capslock":
			continue
		lines.append("%s%s" % [str(UPGRADES[id]["name"]), " x%d" % _count(id) if _count(id) > 1 else ""])
	return lines

func _count(id: String) -> int:
	return int(upgrades.get(id, 0))

func to_save() -> Dictionary:
	if not phase in ["setup", "shop"]:
		return {}
	return {
		"version": 1, "day": day, "donations": donations, "hp": hp,
		"phase": phase, "starting_perk": starting_perk, "upgrades": upgrades.duplicate(true),
		"weapon": weapon, "loyalty_fans": loyalty_fans, "total_donations": total_donations,
		"peak_viewers": peak_viewers, "last_stream_income": last_stream_income,
		"last_combat_reward": last_combat_reward, "viewers": viewers, "goal": goal,
		"heat": heat, "hype": hype, "stream_donations": stream_donations,
		"stream_time": stream_time, "game_id": game_id, "clips_hit": clips_hit,
		"offer_ids": _offer_ids.duplicate(), "shop_bought": _shop_bought.duplicate(true),
		"rerolls": rerolls,
		# JSON cannot preserve all 64 bits of RNG state in a numeric value.
		"rng_state": str(_rng.state),
	}

func load_save(data: Dictionary) -> bool:
	# Validate the complete payload before touching the live run.
	if not _valid_number(data.get("version"), 1.0, 1.0) or not str(data.get("phase", "")) in ["setup", "shop"]:
		return false
	if not _valid_number(data.get("day"), 1.0, float(MAX_DAYS)) or float(data["day"]) != floorf(float(data["day"])):
		return false
	var saved_day: int = int(data.get("day", 0))
	if saved_day < 1 or saved_day > MAX_DAYS or not str(data.get("starting_perk", "")) in ["", "cozy", "spicy"]:
		return false
	if not data.get("upgrades", null) is Dictionary or not data.get("offer_ids", null) is Array or not data.get("shop_bought", null) is Dictionary:
		return false
	var saved_upgrades: Dictionary = data["upgrades"]
	for id in saved_upgrades:
		if not UPGRADES.has(id) or id == "medkit" or not _valid_number(saved_upgrades[id], 1.0, float(UPGRADES[id]["max_stacks"])):
			return false
		if float(saved_upgrades[id]) != floorf(float(saved_upgrades[id])):
			return false
	var saved_weapon: String = str(data.get("weapon", ""))
	if not saved_weapon in ["keyboard", "banhammer", "capslock"] or (saved_weapon != "keyboard" and not saved_upgrades.has(saved_weapon)):
		return false
	var maximum_hp: float = (90.0 if str(data.get("starting_perk", "")) == "spicy" else 100.0) + float(saved_upgrades.get("vitality", 0)) * 22.0
	if not _valid_number(data.get("hp"), 0.01, maximum_hp):
		return false
	for key in ["donations", "loyalty_fans", "total_donations", "peak_viewers", "last_stream_income", "last_combat_reward", "clips_hit"]:
		if not _valid_number(data.get(key), 0.0, 1000000.0) or float(data[key]) != floorf(float(data[key])):
			return false
	for key in ["viewers", "stream_donations"]:
		if not _valid_number(data.get(key), 0.0, 1000000.0):
			return false
	if not _valid_number(data.get("goal"), float(GOALS[saved_day - 1]), float(GOALS[saved_day - 1])) or not _valid_number(data.get("heat"), 0.0, 160.0) or not _valid_number(data.get("hype"), 0.0, 100.0) or not _valid_number(data.get("stream_time"), 0.0, STREAM_LIMIT):
		return false
	var saved_game_id: String = str(data.get("game_id", ""))
	if str(data["phase"]) == "shop" and not saved_game_id in ["cozy", "sweaty", "weird"]:
		return false
	var saved_offers: Array = data["offer_ids"]
	if saved_offers.size() > 4 or (str(data["phase"]) == "shop" and (saved_offers.is_empty() or not "medkit" in saved_offers)):
		return false
	var seen: Dictionary = {}
	for id in saved_offers:
		if not UPGRADES.has(id) or seen.has(id):
			return false
		seen[id] = true
	for id in data["shop_bought"]:
		if not UPGRADES.has(id) or not data["shop_bought"][id] is bool or data["shop_bought"][id] != true:
			return false
	if not _valid_number(data.get("rerolls", 0), 0.0, 10000.0) or float(data.get("rerolls", 0)) != floorf(float(data.get("rerolls", 0))):
		return false
	var rng_text: String = str(data.get("rng_state", ""))
	if not rng_text.is_valid_int():
		return false
	reset_run(str(data.get("starting_perk", "")))
	day = saved_day
	donations = int(data["donations"])
	hp = float(data["hp"])
	phase = str(data["phase"])
	upgrades = saved_upgrades.duplicate(true)
	weapon = saved_weapon
	loyalty_fans = int(data["loyalty_fans"])
	total_donations = int(data["total_donations"])
	peak_viewers = int(data["peak_viewers"])
	last_stream_income = int(data["last_stream_income"])
	last_combat_reward = int(data["last_combat_reward"])
	viewers = float(data["viewers"])
	goal = float(data["goal"])
	heat = float(data["heat"])
	hype = float(data["hype"])
	stream_donations = float(data["stream_donations"])
	stream_time = float(data["stream_time"])
	game_id = saved_game_id
	for definition in GAMES:
		if definition["id"] == game_id:
			game = definition.duplicate(true)
	clips_hit = int(data["clips_hit"])
	_offer_ids.assign(saved_offers)
	_shop_bought = data["shop_bought"].duplicate(true)
	rerolls = int(data.get("rerolls", 0))
	_rng.state = int(rng_text)
	return true

func _valid_number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high
