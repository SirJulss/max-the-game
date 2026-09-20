extends SceneTree
## Run with: godot --headless --path . --script res://src/combat/combat_smoke.gd

var arena: CombatArena
var failures := 0
var clear_received := false
var defeat_received := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("COMBAT TEST: " + message)

func run() -> void:
	seed(342)
	arena = CombatArena.new()
	root.add_child(arena)
	await process_frame
	arena.cleared.connect(func(_reward: int) -> void: clear_received = true)
	arena.defeated.connect(func() -> void: defeat_received = true)
	arena.start_encounter(1, 0, {"hp": 100, "armor": 2})
	arena.spawn_queue.clear()
	arena.player.position = Vector2(600, 450)
	if not InputMap.has_action("special"):
		InputMap.add_action("special")
	arena.player.allow_combat = false
	Input.action_press("attack")
	Input.action_press("special")
	arena.player._physics_process(0.01)
	check(not arena.player.wants_attack() and arena.player.special_remaining == 0, "The apartment movement-only mode must ignore combat inputs")
	Input.action_release("attack")
	Input.action_release("special")
	arena.player.allow_combat = true
	var target: Node2D = arena.spawn_enemy("heckler", Vector2(670, 450))
	target.hp = 200
	target.max_hp = 200
	var initial: float = target.hp
	arena._attack(Vector2.RIGHT, "keyboard", 1)
	check(target.hp < initial, "Keyboard swing must damage a target in its arc")
	var after: float = target.hp
	arena._attack(Vector2.LEFT, "keyboard", 1)
	check(is_equal_approx(target.hp, after), "A backward swing must miss the forward target")
	arena._attack(Vector2.RIGHT, "banhammer", 3)
	check(target.hp < after, "Banhammer must hit")
	arena._attack(Vector2.RIGHT, "capslock", 3)
	check(arena.projectiles.size() == 3, "Capslock third shot must produce a fan")
	var julian: Node2D = arena.spawn_enemy("ratio", Vector2(780, 450))
	julian.spawn_time = 0
	julian._prepare("jetpack", 0.01, Vector2.LEFT)
	julian.windup = 0
	julian._resolve_attack()
	var julian_hp: float = julian.hp
	julian.take_hit(9999, arena.player.position)
	check(julian.is_airborne and julian.hp == julian_hp, "Julian must become untargetable during his jetpack flight")
	julian.tick(1.2)
	check(not julian.is_airborne and arena.shockwaves.size() == 1, "Julian's landing must create an expanding shockwave")
	arena.player.position = julian.position + Vector2(50, 0)
	arena.player.invulnerable = 0
	arena._update_shockwaves(0.1)
	var after_wave: float = arena.player.hp
	arena.player.invulnerable = 0
	arena._update_shockwaves(0.06)
	check(after_wave < 100 and arena.player.hp == after_wave, "A shockwave can damage Max once, even across multiple frames")
	arena.shockwaves.clear()
	arena.player.position = Vector2(600, 450)
	var louis: Node2D = arena.spawn_enemy("reply", Vector2(925, 400))
	louis._prepare("bottle", 0.01, Vector2.LEFT)
	louis.windup = 0
	louis._resolve_attack()
	check(arena.bottles.size() == 1, "Louis must throw an arcing bottle instead of firing a bullet")
	arena._update_bottles(0.96)
	var before_puddle: float = arena.player.hp
	arena.player.invulnerable = 0
	arena._update_puddles(0.71)
	check(arena.puddles.size() == 1 and arena.player.hp < before_puddle, "A shattered bottle must leave a damaging area that players can leave")
	arena.puddles.clear()
	arena.player.heal(100)
	arena.player.invulnerable = 0
	arena.player.take_damage(12, Vector2(500, 450))
	check(arena.player.hp == 90, "Flat armor must reduce damage")
	check(not arena.player.take_damage(12, Vector2(500, 450)), "Damage grace period must reject immediate repeated damage")
	arena.player.invulnerable = 0
	arena.player.is_dashing = true
	check(not arena.player.take_damage(12, Vector2(500, 450)), "Dashes must avoid damage")
	arena.player.is_dashing = false
	Input.action_press("attack")
	await create_timer(0.75).timeout
	Input.action_release("attack")
	check(arena.player.combo_timeout > 0, "Held attack must drive the reused state machine")
	arena.player.special_requested.emit()
	for enemy in arena.enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.take_hit(10000, Vector2.ZERO)
	await create_timer(1.0).timeout
	check(clear_received, "An empty completed wave must emit cleared")
	arena.start_encounter(6, 110, {"hp": 5000, "max_hp": 5000, "security": 2, "thorns": 4, "lifesteal": 3})
	arena.spawn_queue.clear()
	for type in ["heckler", "reply", "ratio", "modzilla", "algorithm"]:
		var enemy: Node2D = arena.spawn_enemy(type, Vector2(randf_range(440, 850), randf_range(365, 545)))
		enemy.spawn_time = 0
		enemy.cooldown = 0
	await create_timer(4.5).timeout
	check(arena.boss_max_hp > 0, "Boss health must be exposed")
	check(arena.effects.size() > 0 or arena.projectiles.size() > 0 or arena.hazards.size() > 0, "Enemy patterns must produce combat effects")
	arena.player.invulnerable = 0
	arena.player.is_dashing = false
	arena.player.take_damage(100000, Vector2.ZERO)
	check(defeat_received and not arena.active, "Lethal damage must emit defeated and stop combat")
	print("Combat smoke: ", "PASS" if failures == 0 else "FAIL (%s)" % failures)
	arena.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if failures == 0 else 1)
