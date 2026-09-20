extends SceneTree
## Development playtest: an intentionally simple input-driven fighter, no damage cheats.
var arena: CombatArena
var ended := false
var won := false

func _initialize() -> void:
	Engine.time_scale = 6
	Engine.physics_ticks_per_second = 360
	for action in ["dash", "special"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	call_deferred("run")

func run() -> void:
	arena = CombatArena.new()
	root.add_child(arena)
	arena.cleared.connect(func(_r: int) -> void: ended = true; won = true)
	arena.defeated.connect(func() -> void: ended = true)
	await process_frame
	for weapon in ["keyboard", "banhammer", "capslock"]:
		for day in [1, 3, 6]:
			seed(930 + day)
			ended = false
			won = false
			var growth: float = (day - 1) / 5.0
			arena.start_encounter(day, 25.0 + day * 5, {"weapon": weapon, "hp": 100 + growth * 45, "max_hp": 100 + growth * 45, "damage": 1 + growth * 0.65, "attack_speed": 1 + growth * 0.3, "move_speed": 1 + growth * 0.1, "armor": growth * 4, "security": 0 if day == 1 else 1})
			Input.action_press("attack")
			while not ended and arena.elapsed < 100:
				_bot()
				await physics_frame
			print("PROBE ", weapon, " day ", day, " won=", won, " HP=", int(arena.player.hp), " seconds=", int(arena.elapsed), " KOs=", arena.kills)
			Input.action_release("attack")
			arena.set_active(false)
			await process_frame
	await create_timer(0.5).timeout
	arena.queue_free()
	await process_frame
	Engine.time_scale = 1
	await create_timer(0.15).timeout
	quit()

func _bot() -> void:
	var target: Node2D
	var nearest := INF
	for enemy in arena.enemies:
		var distance: float = enemy.position.distance_to(arena.player.position)
		if distance < nearest:
			nearest = distance
			target = enemy
	var movement := Vector2.ZERO
	Input.action_release("dash")
	Input.action_release("special")
	if target:
		var mouse := InputEventMouseMotion.new()
		mouse.position = target.position
		mouse.global_position = target.position
		Input.parse_input_event(mouse)
		var to_target: Vector2 = (target.position - arena.player.position).normalized()
		var ideal := 210 if arena.player.weapon == "capslock" else 70
		movement = to_target if nearest > ideal else to_target.orthogonal()
		if nearest < ideal - 15:
			movement = -to_target
		if target.windup > 0 and target.attack_kind == "stomp" and nearest < (185 if target.boss else 130):
			movement = -to_target
			Input.action_press("dash")
		elif target.windup > 0 and target.attack_kind == "charge":
			movement = to_target.orthogonal()
			Input.action_press("dash")
		if nearest < 160 and arena.player.special_remaining == 0:
			Input.action_press("special")
		if arena.player.position.x < 155 and movement.x < 0:
			movement.x = 1
		if arena.player.position.x > 1125 and movement.x > 0:
			movement.x = -1
		if arena.player.position.y < 350 and movement.y < 0:
			movement.y = 1
		if arena.player.position.y > 580 and movement.y > 0:
			movement.y = -1
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	if absf(movement.x) > 0.2:
		Input.action_press("move_right" if movement.x > 0 else "move_left")
	if absf(movement.y) > 0.2:
		Input.action_press("move_down" if movement.y > 0 else "move_up")
