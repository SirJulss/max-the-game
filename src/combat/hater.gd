extends Node2D
## Enemies share damage/telegraph rules but have deliberately different spacing games.

const MONITOR_TEXTURE := preload("res://Assets/Gameplay/Streaming/Pc/PCOverlay.png")
const FX := preload("res://src/presentation/pixel_fx.gd")

var arena: Node2D
var kind := "heckler"
var display_name := "Heckler"
var boss_subtitle := ""
var hp := 40.0
var max_hp := 40.0
var speed := 90.0
var damage := 10.0
var radius := 20.0
var tint := Color("f5798d")
var boss := false
var dead := false
var cooldown := 0.8
var windup := 0.0
var windup_max := 0.0
var attack_kind := ""
var aim := Vector2.RIGHT
var charge_left := 0.0
var flash := 0.0
var stagger := 0.0
var knockback := Vector2.ZERO
var age := 0.0
var phase := 0
var half_triggered := false
const SPAWN_DURATION := 0.7
var spawn_time := SPAWN_DURATION
var npc_sprite: Sprite2D
var sprite_textures: Dictionary = {}
var body_scale := 1.5
var is_airborne := false
var flight_remaining := 0.0
var flight_duration := 1.2
var flight_start := Vector2.ZERO
var flight_target := Vector2.ZERO
var flight_height := 0.0

func setup(type: String, day: int, heat: float, owner_arena: Node2D) -> void:
	arena = owner_arena
	kind = type
	var power := 1.0 + maxf(0, day - 1) * 0.13 + heat * 0.002
	damage = (7.0 + day * 1.3) * (1.0 + heat * 0.0018)
	match kind:
		"heckler":
			display_name = "TAN"
			max_hp = 37 * power
			speed = 103 + day * 3
		"reply":
			display_name = "LOUIS"
			max_hp = 31 * power
			speed = 88
			tint = Color("83b9ff")
		"ratio":
			display_name = "JULIAN"
			max_hp = 54 * power
			speed = 76
			tint = Color("ffc574")
			radius = 23
		"modzilla":
			display_name = "MODZILLA"
			boss_subtitle = "Unpaid. Unstoppable."
			boss = true
			max_hp = 550 * (1 + heat * 0.0018)
			speed = 79
			tint = Color("a0ed8c")
			radius = 43
			damage *= 1.3
		"algorithm":
			display_name = "THE ALGORITHM"
			boss_subtitle = "Recommended for nobody."
			boss = true
			max_hp = 960 * (1 + heat * 0.0018)
			speed = 64
			tint = Color("c89bff")
			radius = 47
			damage *= 1.15
	hp = max_hp
	cooldown += randf() * 0.8
	_create_original_sprite()
	queue_redraw()

func _create_original_sprite() -> void:
	if kind == "algorithm":
		return
	var character := "tan"
	if kind == "reply" or kind == "modzilla":
		character = "louis"
	elif kind == "ratio":
		character = "julian"
	if kind == "modzilla":
		body_scale = 2.5
	for direction in {"front": "", "back": "Back", "right": "_rechts"}:
		var suffix: String = {"front": "", "back": "Back", "right": "_rechts"}[direction]
		var path := "res://Assets/npc/%s%s.png" % [character, suffix]
		if ResourceLoader.exists(path):
			sprite_textures[direction] = load(path)
	if sprite_textures.is_empty():
		push_error("The original NPC sprite exports are missing: " + character)
		return
	npc_sprite = Sprite2D.new()
	npc_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	npc_sprite.region_enabled = true
	npc_sprite.scale = Vector2.ONE * body_scale
	npc_sprite.show_behind_parent = true
	add_child(npc_sprite)
	_sync_sprite()

func _sync_sprite() -> void:
	if not is_instance_valid(npc_sprite):
		return
	var direction: Vector2 = (arena.player.position - position).normalized()
	if windup > 0 or charge_left > 0:
		direction = aim
	var facing := "front"
	if absf(direction.x) > absf(direction.y) * 1.2:
		facing = "right"
	elif direction.y < -0.2:
		facing = "back"
	var texture: Texture2D = sprite_textures.get(facing, sprite_textures["front"])
	npc_sprite.texture = texture
	var frames := maxi(1, texture.get_width() / 32)
	var frame := int(age * (6 if charge_left > 0 else 3.5)) % frames
	npc_sprite.region_rect = Rect2(frame * 32, 0, 32, 64)
	npc_sprite.flip_h = facing == "right" and direction.x < 0
	npc_sprite.position = Vector2(0, -28 * body_scale + floor(sin(age * 5) * 1.0) - flight_height)
	# Keep the artist's colors intact; only the enlarged boss gets a subtle tint.
	var accent := Color.WHITE.lerp(tint, 0.18) if boss else Color.WHITE
	npc_sprite.modulate = accent
	if spawn_time > 0:
		npc_sprite.modulate.a = 0.35 + 0.65 * (1.0 - spawn_time / SPAWN_DURATION)

func tick(delta: float) -> void:
	if dead:
		return
	age += delta
	flash = maxf(0, flash - delta)
	spawn_time = maxf(0, spawn_time - delta)
	stagger = maxf(0, stagger - delta)
	position += knockback * delta
	knockback = knockback.move_toward(Vector2.ZERO, 1100 * delta)
	_sync_sprite()
	queue_redraw()
	if spawn_time > 0 or stagger > 0:
		return
	if is_airborne:
		flight_remaining = maxf(0, flight_remaining - delta)
		var progress := 1.0 - flight_remaining / flight_duration
		position = flight_start.lerp(flight_target, progress)
		flight_height = sin(progress * PI) * 145
		_sync_sprite()
		z_index = int(position.y)
		if flight_remaining <= 0:
			is_airborne = false
			flight_height = 0
			position = flight_target
			cooldown = 2.3
			arena.add_shockwave(position, 170, damage * 1.25, 0.65)
			arena.burst(position, Color("ffd18a"), 12)
			arena.add_explosion(position + Vector2(0, -18), 45)
			arena.play_sfx("slam")
			arena.emit_impact(0.65)
		return
	var to_player: Vector2 = arena.player.position - position
	var distance := to_player.length()
	var direction := to_player.normalized()
	if boss and not half_triggered and hp < max_hp * 0.5:
		half_triggered = true
		arena.feedback.emit("ENRAGED: " + ("Modzilla deleted the rules." if kind == "modzilla" else "The algorithm discovered ragebait."))
		arena.spawn_enemy("reply" if kind == "algorithm" else "heckler", position + Vector2(-85, 25))
		arena.spawn_enemy("ratio" if kind == "algorithm" else "heckler", position + Vector2(85, 25))
	if charge_left > 0:
		charge_left -= delta
		position += aim * (490 if boss else 450) * delta
		if distance < radius + 21:
			arena.player.take_damage(damage * 1.3, position)
		if charge_left <= 0:
			cooldown = 1.25
			arena.burst(position, tint, 9)
		_clamp_position()
		return
	if windup > 0:
		windup -= delta
		if windup <= 0:
			_resolve_attack()
		return
	cooldown -= delta
	var movement := direction
	match kind:
		"reply":
			if distance < 190:
				movement = -direction
			elif distance < 295:
				movement = direction.orthogonal() * sin(age * 1.3)
			if cooldown <= 0:
				_prepare("bottle", 0.5, direction)
		"ratio":
			if cooldown <= 0 and distance < 420:
				_prepare("jetpack", 0.42, direction)
		"modzilla":
			if cooldown <= 0:
				phase += 1
				_prepare("charge" if phase % 3 == 0 else "stomp", 0.82, direction)
		"algorithm":
			movement = direction if distance > 260 else direction.orthogonal() * cos(age * 0.7)
			if cooldown <= 0:
				phase += 1
				if phase % 3 == 0:
					_prepare("ring", 0.7, direction)
				else:
					_prepare("recommend", 0.6, direction)
		_:
			if cooldown <= 0 and distance < 57:
				_prepare("swipe", 0.38, direction)
	if windup <= 0:
		var separation: Vector2 = arena.enemy_separation(self)
		position += (movement * speed + separation * 65) * delta
	_clamp_position()
	z_index = int(position.y)

func _clamp_position() -> void:
	position.x = clampf(position.x, arena.bounds.position.x + radius, arena.bounds.end.x - radius)
	position.y = clampf(position.y, arena.bounds.position.y + radius, arena.bounds.end.y - radius)

func _prepare(type: String, delay: float, direction: Vector2) -> void:
	attack_kind = type
	windup = delay * (0.88 if half_triggered else 1.0)
	windup_max = windup
	aim = direction
	if type == "jetpack":
		flight_target = arena.player.position + arena.player.velocity * 0.18
		flight_target.x = clampf(flight_target.x, arena.bounds.position.x + 40, arena.bounds.end.x - 40)
		flight_target.y = clampf(flight_target.y, arena.bounds.position.y + 40, arena.bounds.end.y - 40)

func _resolve_attack() -> void:
	var distance: float = position.distance_to(arena.player.position)
	match attack_kind:
		"swipe":
			arena.add_ring(position + aim * 32, 30, Color("ff7187"), 0.22)
			var offset: Vector2 = arena.player.position - position
			if distance < 16 or (distance < 66 and offset.normalized().dot(aim) > 0.1):
				arena.player.take_damage(damage, position)
			cooldown = 1.05
		"bottle":
			var target: Vector2 = arena.player.position + arena.player.velocity * 0.2
			arena.lob_bottle(position + Vector2(18, -45), target, damage, 60)
			cooldown = 1.85
		"jetpack":
			is_airborne = true
			flight_start = position
			flight_remaining = flight_duration
			knockback = Vector2.ZERO
			arena.play_sfx("jet_launch")
		"charge":
			charge_left = 0.58 if boss else 0.46
			cooldown = 1.3
		"stomp":
			var size := 154.0 if boss else 100.0
			arena.add_ring(position, size, Color("ff7f99"), 0.42)
			arena.burst(position, tint, 14)
			arena.add_explosion(position + Vector2(0, -20), 58)
			arena.play_sfx("slam")
			arena.emit_impact(0.65)
			if distance < size + 12:
				arena.player.take_damage(damage * 1.2, position)
			cooldown = 1.8 if boss else 2.0
		"ring":
			for index in 12:
				var direction := Vector2.RIGHT.rotated(TAU * index / 12.0 + age)
				arena.spawn_projectile(position + direction * 50, direction * 170, damage, false, 0)
			arena.play_sfx("stomp")
			cooldown = 1.7
		"recommend":
			var target: Vector2 = arena.player.position
			arena.add_hazard(target, 68, 1.1, damage * 1.2)
			if half_triggered:
				arena.add_hazard(target + Vector2(130, 0), 65, 1.35, damage)
				arena.add_hazard(target - Vector2(130, 0), 65, 1.35, damage)
			cooldown = 1.2

func take_hit(amount: float, from: Vector2, force: float = 150.0) -> void:
	if dead or is_airborne:
		return
	hp -= amount
	flash = 0.09
	knockback = (position - from).normalized() * force * (0.25 if boss else 1.0)
	# Heavy attacks interrupt ordinary Haters, but bosses keep their readable tells.
	if force >= 230 and not boss:
		stagger = 0.24
		windup = 0
		charge_left = 0
		cooldown = maxf(cooldown, 0.5)
	arena.damage_text(position + Vector2(0, -40), str(int(ceil(amount))), Color("fff2af"))
	arena.burst(position + Vector2(0, -15), tint, 5)
	if hp <= 0:
		dead = true
		arena.enemy_died(self)
		queue_free()

func _draw() -> void:
	var color := tint
	var bob := sin(age * 5.0) * 2.0
	if is_airborne or (windup > 0 and attack_kind == "jetpack"):
		var marker := flight_target - position
		var progress := 1.0 - flight_remaining / flight_duration if is_airborne else 0.0
		FX.draw(self, "disc", marker, Vector2.ONE * 90, progress, Color(1, 0.63, 0.25, 0.14))
		FX.draw(self, "ring", marker, Vector2.ONE * 90, progress, Color("ffc574"))
		FX.draw(self, "crosshair", marker, Vector2.ONE * 36, progress, Color("ffe9b4"))
		FX.draw(self, "ring", marker, Vector2.ONE * 340, progress, Color(1, 0.73, 0.4, 0.22))
	if spawn_time > 0:
		var arriving := 1.0 - spawn_time / SPAWN_DURATION
		var extent := Vector2.ONE * (radius + 15) * 2
		FX.draw(self, "disc", Vector2.ZERO, extent, arriving, Color(color, 0.1))
		FX.draw(self, "ring", Vector2.ZERO, extent, arriving, Color(color, 0.35))
	if windup > 0:
		var fraction := 1.0 - windup / maxf(0.01, windup_max)
		var warning := Color(1, 0.35, 0.43, 0.2 + fraction * 0.25)
		if attack_kind == "swipe":
			FX.draw(self, "swipe", Vector2.ZERO, Vector2.ONE * 132, fraction, Color("ffadbc"), aim.angle())
			FX.draw(self, "disc", Vector2.ZERO, Vector2.ONE * 32, fraction, warning)
		elif attack_kind == "charge":
			var length := 285.0 if boss else 220.0
			# The authored lane fills 38 of the nominal 96 vertical pixels.
			# Compensate its padding so the warning covers the collision corridor.
			var lane_width := (radius + 8) * 2 * FX.FOOTPRINT / 38.0
			FX.draw(self, "charge", aim * length * 0.5, Vector2(length, lane_width), fraction, Color("ffb078"), aim.angle())
		elif attack_kind == "stomp":
			var size := 154.0 if boss else 100.0
			FX.draw(self, "disc", Vector2.ZERO, Vector2.ONE * size * 2, fraction, warning)
			FX.draw(self, "ring", Vector2.ZERO, Vector2.ONE * size * 2, fraction, Color("ff7f99"))
		elif attack_kind == "bottle":
			FX.draw(self, "charge", aim * 145, Vector2(290, 6), fraction, warning, aim.angle())
		else:
			FX.draw(self, "ring", Vector2.ZERO, Vector2.ONE * (radius + 15) * 2, fraction, Color("ffdb86"))
	FX.draw(self, "shadow", Vector2(0, 5), Vector2((radius + 4) * 2, (radius + 4) * 0.7), 0, Color(0.025, 0.018, 0.07, 0.45))
	draw_set_transform(Vector2(0, bob))
	if flash > 0:
		var center := Vector2(0, -42 - flight_height)
		var extent := Vector2(70, 105) * (body_scale / 1.5)
		if kind == "algorithm":
			center = Vector2(0, -65)
			extent = Vector2(160, 105)
		FX.draw(self, "halo", center, extent, 1 - flash / 0.09, Color.WHITE)
	if kind == "algorithm":
		# The final boss is the original streaming monitor, now looking back at Max.
		draw_texture_rect_region(MONITOR_TEXTURE, Rect2(-70, -104, 140, 79), Rect2(0, 0, 320, 180))
		draw_circle(Vector2(0, -68), 20, Color("ed83bd"))
		draw_circle(Vector2(aim.x * 8, -68 + aim.y * 6), 9, Color("fff5bc"))
		draw_line(Vector2(-32, -24), Vector2(-43, -3), color, 4)
		draw_line(Vector2(32, -24), Vector2(43, -3), color, 4)
		draw_rect(Rect2(-12, -25, 24, 17), Color("927a97"))
		draw_rect(Rect2(-29, -8, 58, 7), Color("af91b7"))
	else:
		# Character bodies are the user's original Julian, Louis and Tan pixel art.
		# Small equipment additions make attack roles readable without replacing it.
		if kind == "reply":
			FX.draw(self, "bottle", Vector2(23, -42), Vector2.ONE * 34, 0)
		elif kind == "ratio":
			for side in [-1, 1]:
				var pack := Vector2(side * 22, -53 - flight_height)
				draw_rect(Rect2(pack - Vector2(6, 15), Vector2(12, 30)), Color("6f7c92"))
				draw_rect(Rect2(pack - Vector2(3, 11), Vector2(6, 20)), Color("c1d4de"))
				if is_airborne or (windup > 0 and attack_kind == "jetpack"):
					# Pixel Composer's exported flame points toward local negative X.
					FX.draw(self, "jet_flame", pack + Vector2(0, 34), Vector2(36, 20), fmod(age * 2, 1.0), Color("ffa254"), -PI / 2)
		elif kind == "modzilla":
			draw_line(Vector2(33, -18), Vector2(58, -92), Color("eed5a0"), 8)
			draw_rect(Rect2(36, -110, 55, 29), Color("ffb874"))
			draw_rect(Rect2(41, -105, 45, 19), Color("7d5653"))
			draw_string(ThemeDB.fallback_font, Vector2(48, -91), "BAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe1af"))
		FX.draw(self, "ring", Vector2.ZERO, Vector2.ONE * (radius + 4) * 2, 0, Color(tint, 0.5))
	draw_set_transform(Vector2.ZERO)
	if not boss:
		var bar_y := -64 * body_scale - 7 - flight_height
		draw_string(ThemeDB.fallback_font, Vector2(-22, bar_y - 5), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		if hp < max_hp:
			draw_rect(Rect2(-24, bar_y, 48, 5), Color("29233d"))
			draw_rect(Rect2(-24, bar_y, 48 * maxf(0, hp / max_hp), 5), tint)
