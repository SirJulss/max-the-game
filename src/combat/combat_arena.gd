class_name CombatArena
extends Node2D
## A small, deterministic encounter host. All fights occur in the same front yard.

signal cleared(reward: int)
signal defeated
signal feedback(message: String)

const PLAYER_SCENE := preload("res://Scenes/Levels/Player/Player.tscn")
const HATER_SCRIPT := preload("res://src/combat/hater.gd")
const EXPLOSION_TEXTURE := preload("res://Assets/test/image-removebg-preview.png")
var player: Player
var active := false
var kills := 0
var boss_name := ""
var boss_hp := 0.0
var boss_max_hp := 0.0
var bounds := Rect2(110, 300, 1060, 330)
var enemies: Array[Node2D] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var bottles: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var shockwaves: Array[Dictionary] = []
var floating_text: Array[Dictionary] = []
var spawn_queue: Array[String] = []
var stats: Dictionary = {}
var day := 1
var heat := 0.0
var spawn_timer := 0.0
var clear_timer := 0.0
var turret_timer := 0.0
var elapsed := 0.0
var reward_bank := 0
var hit_count := 0
var sfx: Dictionary = {}
var sound_voices := 0
var feedback_layer: Node2D

func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Max"
	player.top_level = false
	add_child(player)
	player.position = Vector2(640, 425)
	player.attack_requested.connect(_attack)
	player.special_requested.connect(_special)
	player.dashed.connect(_dash)
	player.hurt.connect(_player_hurt)
	player.died.connect(_defeat)
	feedback_layer = Node2D.new()
	feedback_layer.z_index = 2000
	add_child(feedback_layer)
	feedback_layer.draw.connect(_draw_floating_text)
	_make_sounds()
	set_active(false)

func start_encounter(round_day: int, stream_heat: float, build: Dictionary) -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	projectiles.clear()
	effects.clear()
	hazards.clear()
	bottles.clear()
	puddles.clear()
	shockwaves.clear()
	floating_text.clear()
	spawn_queue.clear()
	day = round_day
	heat = clampf(stream_heat, 0, 160)
	stats = build.duplicate(true)
	kills = 0
	hit_count = 0
	reward_bank = 0
	elapsed = 0
	clear_timer = 0
	spawn_timer = 0.6
	turret_timer = 1.0
	boss_name = ""
	boss_hp = 0
	boss_max_hp = 0
	player.position = Vector2(640, 440)
	player.bounds = bounds
	player.configure(stats)
	var count := clampi(3 + day * 2 + int(heat / 20), 5, 22)
	for index in count:
		var type := "heckler"
		if day >= 2 and index % 4 == 2:
			type = "reply"
		if day >= 2 and index % 5 == 4:
			type = "ratio"
		spawn_queue.append(type)
	if day == 3 or day >= 6:
		spawn_queue.insert(2, "modzilla" if day == 3 else "algorithm")
	set_active(true)
	feedback.emit("Front yard rules: aim, keep moving, dash through danger.")
	play_sfx("start")

func set_active(value: bool) -> void:
	active = value
	if is_instance_valid(player):
		player.set_active(value)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0 and not spawn_queue.is_empty():
		var type: String = spawn_queue.pop_front()
		var side := -1 if randi() % 2 == 0 else 1
		var spawn_position := Vector2(155 if side < 0 else 1125, randf_range(365, 565))
		if type == "modzilla" or type == "algorithm":
			spawn_position = Vector2(1010, 420)
		spawn_enemy(type, spawn_position)
		spawn_timer = 1.05 if day <= 2 else 0.85
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.tick(delta)
			if not active:
				return
			if enemy.boss:
				boss_hp = enemy.hp
				boss_max_hp = enemy.max_hp
	_update_projectiles(delta)
	_update_hazards(delta)
	_update_bottles(delta)
	_update_puddles(delta)
	_update_shockwaves(delta)
	if not active:
		return
	_update_security(delta)
	player.z_index = int(player.position.y)
	if player.is_dashing and int(elapsed * 60) % 3 == 0:
		add_ring(player.position, 20, Color("68f8d4"), 0.23)
	if spawn_queue.is_empty() and enemies.is_empty():
		# The last KO ends incoming danger immediately; the brief delay is celebration.
		projectiles.clear()
		hazards.clear()
		bottles.clear()
		puddles.clear()
		shockwaves.clear()
		clear_timer += delta
		if clear_timer > 0.8:
			var reward := reward_bank + 20 + day * 8 + int(heat * 0.25)
			set_active(false)
			projectiles.clear()
			hazards.clear()
			bottles.clear()
			puddles.clear()
			shockwaves.clear()
			play_sfx("win")
			cleared.emit(reward)
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index]["life"] -= delta
		if effects[index].has("velocity"):
			effects[index]["position"] += effects[index]["velocity"] * delta
		if effects[index]["life"] <= 0:
			effects.remove_at(index)
	for index in range(floating_text.size() - 1, -1, -1):
		floating_text[index]["life"] -= delta
		floating_text[index]["position"].y -= delta * 38
		if floating_text[index]["life"] <= 0:
			floating_text.remove_at(index)
	if visible:
		queue_redraw()
		if is_instance_valid(feedback_layer):
			feedback_layer.queue_redraw()

func spawn_enemy(type: String, spawn_position: Vector2) -> Node2D:
	var enemy: Node2D = HATER_SCRIPT.new()
	add_child(enemy)
	enemy.position = Vector2(clampf(spawn_position.x, 155, 1125), clampf(spawn_position.y, 350, 580))
	enemy.setup(type, day, heat, self)
	enemy.z_index = int(enemy.position.y)
	enemies.append(enemy)
	add_ring(enemy.position, enemy.radius + 20, enemy.tint, 0.5)
	if enemy.boss:
		boss_name = enemy.display_name
		boss_hp = enemy.hp
		boss_max_hp = enemy.max_hp
		feedback.emit(boss_name + "  /  " + enemy.boss_subtitle)
		play_sfx("stomp")
	return enemy

func enemy_separation(subject: Node2D) -> Vector2:
	var push := Vector2.ZERO
	for other in enemies:
		if other == subject or not is_instance_valid(other) or other.dead:
			continue
		var offset: Vector2 = subject.position - other.position
		var required: float = subject.radius + other.radius + 8
		if offset.length_squared() < required * required:
			push += offset.normalized() * (1 - offset.length() / required)
	return push.limit_length(2)

func _attack(direction: Vector2, weapon: String, combo_index: int) -> void:
	if not active:
		return
	var power: float = player.damage
	if weapon == "capslock":
		spawn_projectile(player.position + direction * 30, direction * 660, 19 * power, true, 1)
		if combo_index == 3:
			for offset in [-0.14, 0.14]:
				spawn_projectile(player.position + direction * 28, direction.rotated(offset) * 630, 11 * power, true, 0)
		play_sfx("shot")
		return
	var reach := 120.0 if weapon == "banhammer" else (103.0 if combo_index == 3 else 88.0)
	var strength := 57.0 if weapon == "banhammer" else (34.0 if combo_index == 3 else 23.0)
	var cone := -0.2 if weapon == "banhammer" else 0.0
	var force := 330.0 if weapon == "banhammer" else (250.0 if combo_index == 3 else 130.0)
	var color := Color("ffd28c") if weapon == "banhammer" else Color("68f8d4")
	effects.append({"kind": "slash", "position": player.position, "radius": reach, "angle": direction.angle(), "color": color, "life": 0.18, "maximum": 0.18})
	var landed := false
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_airborne:
			continue
		var offset: Vector2 = enemy.position - player.position
		if offset.length() <= reach + enemy.radius and (offset.length() < 40 or offset.normalized().dot(direction) > cone):
			enemy.take_hit(strength * power, player.position, force)
			landed = true
	play_sfx("hit" if landed else "swing")
	if landed:
		hit_count += 1

func _special() -> void:
	if not active:
		return
	var center := player.position
	add_ring(center, 176, Color("86f7b0"), 0.5)
	add_explosion(center + Vector2(0, -40), 92)
	burst(center, Color("86f7b0"), 28)
	damage_text(center + Vector2(-48, -72), "TOUCH GRASS", Color("9affbf"))
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_airborne and enemy.position.distance_to(center) < 176 + enemy.radius:
			enemy.take_hit(32 * player.damage, center, 430)
	for index in range(projectiles.size() - 1, -1, -1):
		if not projectiles[index]["friendly"] and projectiles[index]["position"].distance_to(center) < 210:
			projectiles.remove_at(index)
	play_sfx("special")

func _dash() -> void:
	play_sfx("dash")
	burst(player.position, Color("68e8f0"), 7)

func _player_hurt(amount: float, source: Vector2) -> void:
	damage_text(player.position + Vector2(-12, -65), "-" + str(int(ceil(amount))), Color("ff8495"))
	burst(player.position, Color("ff8495"), 12)
	play_sfx("hurt")
	var thorns := float(stats.get("thorns", 0))
	if thorns > 0:
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy) and enemy.position.distance_to(source) < 70:
				enemy.take_hit(thorns, player.position, 180)

func _defeat() -> void:
	set_active(false)
	projectiles.clear()
	hazards.clear()
	bottles.clear()
	puddles.clear()
	shockwaves.clear()
	defeated.emit()

func enemy_died(enemy: Node2D) -> void:
	kills += 1
	reward_bank += (30 if enemy.boss else 4) + int(stats.get("bounty", 0))
	var healing := float(stats.get("lifesteal", 0))
	if healing > 0:
		player.heal(healing)
		if player.hp < player.max_hp:
			damage_text(player.position + Vector2(20, -40), "+" + str(int(healing)), Color("84f9bd"))
	# Every fifth KO restores a little health, providing a comeback without passive waiting.
	if kills % 5 == 0:
		player.heal(5)
		damage_text(enemy.position + Vector2(-30, -30), "+5 HP", Color("84f9bd"))
	burst(enemy.position, enemy.tint, 16 if enemy.boss else 10)
	if enemy.boss:
		add_explosion(enemy.position + Vector2(0, -55), 132)
		boss_hp = 0
		boss_name = ""
		feedback.emit("" + ("Modzilla has been temporarily unmodded." if enemy.kind == "modzilla" else "The algorithm recommends touching grass."))
	enemies.erase(enemy)
	play_sfx("kill")

func spawn_projectile(at: Vector2, velocity: Vector2, damage: float, friendly: bool, pierce: int) -> void:
	projectiles.append({"position": at, "velocity": velocity, "damage": damage, "friendly": friendly, "life": 2.7, "pierce": pierce, "hit": []})

func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		if index >= projectiles.size():
			continue
		var projectile: Dictionary = projectiles[index]
		var previous: Vector2 = projectile["position"]
		projectile["position"] += projectile["velocity"] * delta
		projectile["life"] -= delta
		var remove: bool = projectile["life"] <= 0 or not bounds.grow(80).has_point(projectile["position"])
		if projectile["friendly"]:
			for enemy in enemies.duplicate():
				if not is_instance_valid(enemy) or enemy.dead or enemy.is_airborne or enemy.get_instance_id() in projectile["hit"]:
					continue
				var closest := Geometry2D.get_closest_point_to_segment(enemy.position, previous, projectile["position"])
				if closest.distance_to(enemy.position) < enemy.radius + 7:
					projectile["hit"].append(enemy.get_instance_id())
					enemy.take_hit(projectile["damage"], previous, 65)
					projectile["pierce"] -= 1
					play_sfx("hit")
					if projectile["pierce"] < 0:
						remove = true
						break
		else:
			var closest := Geometry2D.get_closest_point_to_segment(player.position, previous, projectile["position"])
			if closest.distance_to(player.position) < 21:
				player.take_damage(projectile["damage"], previous)
				remove = true
		if remove and index < projectiles.size():
			projectiles.remove_at(index)

func add_hazard(at: Vector2, radius: float, delay: float, damage: float) -> void:
	hazards.append({"position": at, "radius": radius, "remaining": delay, "maximum": delay, "damage": damage})

func lob_bottle(from: Vector2, target: Vector2, damage: float, radius: float = 60) -> void:
	target.x = clampf(target.x, bounds.position.x + 24, bounds.end.x - 24)
	target.y = clampf(target.y, bounds.position.y + 24, bounds.end.y - 24)
	bottles.append({"from": from, "target": target, "elapsed": 0.0, "duration": 0.95, "damage": damage, "radius": radius})

func _update_bottles(delta: float) -> void:
	for index in range(bottles.size() - 1, -1, -1):
		if index >= bottles.size():
			continue
		var bottle: Dictionary = bottles[index]
		bottle["elapsed"] += delta
		if bottle["elapsed"] >= bottle["duration"]:
			puddles.append({"position": bottle["target"], "radius": bottle["radius"], "life": 2.3, "damage": bottle["damage"] * 0.5, "next_hit": 0.7})
			add_ring(bottle["target"], bottle["radius"], Color("f5d280"), 0.35)
			burst(bottle["target"], Color("d7ddae"), 9)
			play_sfx("hit")
			if player.position.distance_to(bottle["target"]) < bottle["radius"] + 12:
				player.take_damage(bottle["damage"], bottle["target"])
			if index < bottles.size():
				bottles.remove_at(index)

func _update_puddles(delta: float) -> void:
	for index in range(puddles.size() - 1, -1, -1):
		if index >= puddles.size():
			continue
		var puddle: Dictionary = puddles[index]
		puddle["life"] -= delta
		puddle["next_hit"] -= delta
		if puddle["next_hit"] <= 0:
			puddle["next_hit"] = 0.7
			if player.position.distance_to(puddle["position"]) < puddle["radius"] + 8:
				player.take_damage(puddle["damage"], puddle["position"])
		if index < puddles.size() and puddle["life"] <= 0:
			puddles.remove_at(index)

func add_shockwave(at: Vector2, radius: float, damage: float, duration: float) -> void:
	shockwaves.append({"position": at, "radius": radius, "damage": damage, "duration": duration, "elapsed": 0.0, "hit": false})

func _update_shockwaves(delta: float) -> void:
	for index in range(shockwaves.size() - 1, -1, -1):
		if index >= shockwaves.size():
			continue
		var wave: Dictionary = shockwaves[index]
		var previous_radius: float = lerpf(14, wave["radius"], wave["elapsed"] / wave["duration"])
		wave["elapsed"] += delta
		var radius: float = lerpf(14, wave["radius"], wave["elapsed"] / wave["duration"])
		var distance: float = player.position.distance_to(wave["position"])
		if not wave["hit"] and distance >= previous_radius - 21 and distance <= radius + 21:
			wave["hit"] = true
			player.take_damage(wave["damage"], wave["position"])
		if index < shockwaves.size() and wave["elapsed"] >= wave["duration"]:
			shockwaves.remove_at(index)

func _update_hazards(delta: float) -> void:
	for index in range(hazards.size() - 1, -1, -1):
		if index >= hazards.size():
			continue
		var hazard: Dictionary = hazards[index]
		hazard["remaining"] -= delta
		if hazard["remaining"] <= 0:
			add_ring(hazard["position"], hazard["radius"], Color("ef96fa"), 0.35)
			burst(hazard["position"], Color("ef96fa"), 12)
			if player.position.distance_to(hazard["position"]) < hazard["radius"] + 10:
				player.take_damage(hazard["damage"], hazard["position"])
			if index < hazards.size():
				hazards.remove_at(index)

func _update_security(delta: float) -> void:
	var security := int(stats.get("security", 0))
	if security <= 0 or enemies.is_empty():
		return
	turret_timer -= delta
	if turret_timer <= 0:
		turret_timer = 1.15 / (1 + security * 0.25)
		var turret := Vector2(640, 319)
		var closest: Node2D = null
		var distance := INF
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.dead and not enemy.is_airborne and enemy.position.distance_squared_to(turret) < distance:
				closest = enemy
				distance = enemy.position.distance_squared_to(turret)
		if closest:
			spawn_projectile(turret, (closest.position - turret).normalized() * 590, 14.0 * security, true, 0)
			play_sfx("shot")

func add_ring(at: Vector2, radius: float, color: Color, duration: float) -> void:
	effects.append({"kind": "ring", "position": at, "radius": radius, "color": color, "life": duration, "maximum": duration})

func add_explosion(at: Vector2, radius: float) -> void:
	effects.append({"kind": "explosion", "position": at, "radius": radius, "color": Color.WHITE, "life": 0.55, "maximum": 0.55})

func burst(at: Vector2, color: Color, count: int) -> void:
	for index in count:
		var duration := randf_range(0.2, 0.42)
		effects.append({"kind": "particle", "position": at, "velocity": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(65, 240), "color": color, "radius": randf_range(2, 5), "life": duration, "maximum": duration})

func damage_text(at: Vector2, message: String, color: Color) -> void:
	floating_text.append({"position": at, "message": message, "color": color, "life": 0.65})

func _draw() -> void:
	for puddle in puddles:
		var at: Vector2 = puddle["position"]
		var radius: float = puddle["radius"]
		var fade: float = minf(1.0, puddle["life"] * 1.8)
		draw_circle(at, radius, Color(0.85, 0.59, 0.22, 0.3 * fade))
		draw_arc(at, radius, 0, TAU, 34, Color(1, 0.85, 0.46, 0.65 * fade), 2)
		for index in 7:
			var foam := at + Vector2.RIGHT.rotated(index * 2.39) * (radius * 0.55)
			draw_circle(foam, 3 + sin(elapsed * 3 + index), Color(1, 0.93, 0.67, fade * 0.75))
	for bottle in bottles:
		var at: Vector2 = bottle["target"]
		var fraction: float = bottle["elapsed"] / bottle["duration"]
		draw_circle(at, bottle["radius"], Color(0.9, 0.65, 0.26, 0.12))
		draw_arc(at, bottle["radius"], 0, TAU, 36, Color("f1d07e"), 2)
		draw_arc(at, bottle["radius"] * fraction, 0, TAU, 28, Color("ffe9ac"), 2)
	for wave in shockwaves:
		var progress: float = wave["elapsed"] / wave["duration"]
		var radius: float = lerpf(14, wave["radius"], progress)
		var at: Vector2 = wave["position"]
		draw_arc(at, radius, 0, TAU, 64, Color(1, 0.55, 0.24, 0.25 * (1 - progress)), 17)
		draw_arc(at, radius, 0, TAU, 64, Color(1, 0.84, 0.53, 1 - progress * 0.5), 5)
	for hazard in hazards:
		var at: Vector2 = hazard["position"]
		var radius: float = hazard["radius"]
		var progress: float = 1 - hazard["remaining"] / hazard["maximum"]
		draw_circle(at, radius, Color(0.8, 0.3, 1.0, 0.15 + progress * 0.15))
		draw_arc(at, radius, 0, TAU, 42, Color("eb9bff"), 3)
		draw_arc(at, radius * progress, 0, TAU, 36, Color("ffe0fa"), 2)
		draw_string(ThemeDB.fallback_font, at + Vector2(-21, 5), "AD!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("ffe0fa"))
	for projectile in projectiles:
		var at: Vector2 = projectile["position"]
		var direction: Vector2 = projectile["velocity"].normalized()
		var color := Color("9cfff0") if projectile["friendly"] else Color("ff9eaa")
		draw_line(at - direction * 18, at, Color(color, 0.4), 8)
		draw_circle(at, 5 if projectile["friendly"] else 8, color)
		if not projectile["friendly"]:
			draw_string(ThemeDB.fallback_font, at + Vector2(-3, 4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3b263e"))
	for effect in effects:
		var fraction: float = effect["life"] / effect["maximum"]
		var color: Color = effect["color"]
		color.a *= fraction
		var at: Vector2 = effect["position"]
		var radius: float = effect["radius"]
		match effect["kind"]:
			"explosion":
				var frame := clampi(int((1.0 - fraction) * 10), 0, 9)
				var row := frame / 5
				var region := Rect2((frame % 5) * 95, row * 119, 95, 119 if row == 0 else 118)
				draw_texture_rect_region(EXPLOSION_TEXTURE, Rect2(at - Vector2(radius, radius * 1.25), Vector2(radius * 2, radius * 2.5)), region)
			"ring":
				draw_arc(at, radius * (1 - fraction * 0.55), 0, TAU, 40, color, 3 + fraction * 3)
			"slash":
				var angle: float = effect["angle"]
				draw_arc(at, radius * (1.0 - fraction * 0.1), angle - 1.1, angle + 1.1, 26, color, 4 + fraction * 9)
				draw_arc(at, radius * 0.65, angle - 0.9, angle + 0.9, 22, Color(color, color.a * 0.5), 4)
			"particle":
				draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), color)
	if int(stats.get("security", 0)) > 0:
		var at := Vector2(640, 319)
		draw_circle(at, 19, Color("273746"))
		draw_circle(at, 12, Color("77dccb"))
		draw_rect(Rect2(at + Vector2(-5, -24), Vector2(10, 22)), Color("b3fff0"))

func _draw_floating_text() -> void:
	# Keep hit values legible above the larger original character sprites.
	for bottle in bottles:
		var fraction: float = bottle["elapsed"] / bottle["duration"]
		var at: Vector2 = bottle["from"].lerp(bottle["target"], fraction) + Vector2(0, -sin(fraction * PI) * 110)
		feedback_layer.draw_set_transform(at, fraction * TAU * 1.5)
		feedback_layer.draw_rect(Rect2(-5, -10, 10, 22), Color("577840"))
		feedback_layer.draw_rect(Rect2(-3, -18, 6, 10), Color("98be66"))
		feedback_layer.draw_rect(Rect2(-5, -3, 10, 8), Color("f4d887"))
		feedback_layer.draw_line(Vector2(-3, -18), Vector2(3, -18), Color("ede0b1"), 2)
	feedback_layer.draw_set_transform(Vector2.ZERO)
	for item in floating_text:
		var color: Color = item["color"]
		color.a = minf(1, item["life"] * 4)
		feedback_layer.draw_string(ThemeDB.fallback_font, item["position"] + Vector2(1, 2), item["message"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.05, 0.03, 0.12, color.a))
		feedback_layer.draw_string(ThemeDB.fallback_font, item["position"], item["message"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _make_sounds() -> void:
	var specs := {"hit": [180.0, 60.0, 0.075], "swing": [380.0, 130.0, 0.08], "shot": [780.0, 270.0, 0.08], "dash": [520.0, 90.0, 0.12], "hurt": [155.0, 45.0, 0.15], "kill": [410.0, 900.0, 0.12], "stomp": [90.0, 28.0, 0.25], "special": [190.0, 760.0, 0.3], "start": [280.0, 540.0, 0.18], "win": [440.0, 880.0, 0.35]}
	for key in specs:
		var spec: Array = specs[key]
		var frames := int(22050 * float(spec[2]))
		var data := PackedByteArray()
		data.resize(frames * 2)
		var phase := 0.0
		for sample in frames:
			var fraction := float(sample) / frames
			phase += TAU * lerpf(spec[0], spec[1], fraction) / 22050.0
			var envelope := sin(PI * fraction) * (1 - fraction)
			var wave := sin(phase) * 0.78 + sin(phase * 2.01) * 0.22
			data.encode_s16(sample * 2, int(wave * envelope * 8500))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		sfx[key] = stream

func play_sfx(key: String) -> void:
	if not sfx.has(key) or sound_voices >= 14:
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = sfx[key]
	voice.volume_db = -9
	voice.pitch_scale = randf_range(0.94, 1.06)
	add_child(voice)
	sound_voices += 1
	voice.finished.connect(func() -> void:
		sound_voices -= 1
		voice.queue_free())
	voice.play()
