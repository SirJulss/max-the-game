extends SceneTree
## Run with: godot --headless --path . --script res://src/combat/combat_smoke.gd

var arena: CombatArena
var failures := 0
var clear_received := false
var defeat_received := false
var impacts: Array[float] = []

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
	arena.impact.connect(func(strength: float) -> void: impacts.append(strength))
	check_impact_bounds()
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
	var spawns_are_safe := true
	for at in [Vector2(155, 350), Vector2(1125, 350), Vector2(155, 580), Vector2(1125, 580), Vector2(640, 440)]:
		arena.player.position = at
		spawns_are_safe = spawns_are_safe and arena._safe_spawn_position(at, "heckler").distance_to(at) >= 140
		spawns_are_safe = spawns_are_safe and arena._safe_spawn_position(at, "modzilla").distance_to(at) >= 210
	check(spawns_are_safe, "Regular enemies and bosses must enter away from Max, including at yard edges")
	arena.player.position = Vector2(600, 450)
	var summon_point := Vector2(640, 450)
	check(arena._safe_spawn_position(summon_point, "heckler").distance_to(summon_point) < 160, "Boss summons should move to nearby safe ground, not force a remote-gate chase")
	var target: Node2D = arena.spawn_enemy("heckler", Vector2(670, 450), false)
	target.hp = 200
	target.max_hp = 200
	var initial: float = target.hp
	var impact_count := impacts.size()
	arena._attack(Vector2.RIGHT, "keyboard", 1)
	check(target.hp < initial, "Keyboard swing must damage a target in its arc")
	check(impacts.size() == impact_count + 1 and impacts.back() == 0.18, "A successful keyboard swing must emit a small impact")
	var after: float = target.hp
	impact_count = impacts.size()
	arena._attack(Vector2.LEFT, "keyboard", 1)
	check(is_equal_approx(target.hp, after), "A backward swing must miss the forward target")
	check(impacts.size() == impact_count, "A missed swing must not trigger screen shake")
	arena._attack(Vector2.RIGHT, "banhammer", 3)
	check(target.hp < after, "Banhammer must hit")
	arena._attack(Vector2.RIGHT, "capslock", 3)
	check(arena.projectiles.size() == 3, "Capslock third shot must produce a fan")
	check_tan_swipe(target)
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
	var effect_boss: Node2D = arena.spawn_enemy("modzilla", Vector2(1000, 450))
	impact_count = impacts.size()
	effect_boss.take_hit(10000, Vector2.ZERO)
	check(impacts.size() == impact_count + 1 and impacts.back() == 1.0, "A boss KO must emit the strongest impact")
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

func check_tan_swipe(target: Node2D) -> void:
	var before: float = arena.player.hp
	target._prepare("swipe", 0.38, Vector2.RIGHT)
	target.windup = 0
	arena.player.position = target.position + Vector2(-45, 0)
	arena.player.invulnerable = 0
	target._resolve_attack()
	check(arena.player.hp == before, "Sidestepping behind Tan's committed swipe must avoid its damage")
	arena.player.position = target.position + Vector2(45, 0)
	arena.player.invulnerable = 0
	target._resolve_attack()
	check(arena.player.hp < before, "Tan's frontal telegraph must correspond to actual damage")
	arena.player.heal(100)
	arena.player.position = Vector2(600, 450)

func check_impact_bounds() -> void:
	arena.emit_impact(-3)
	check(impacts.is_empty(), "Negative impact requests must not emit")
	arena.emit_impact(0.1)
	arena.emit_impact(0.1)
	check(impacts.size() == 1, "Dense equal projectile impacts must coalesce")
	arena.emit_impact(0.45)
	check(impacts.size() == 2 and impacts.back() == 0.45, "A stronger impact must break through the short coalescing window")
	arena.emit_impact(40)
	check(impacts.size() == 3 and impacts.back() == 1.0, "Impact strength must clamp to one")
	arena.emit_impact(0.9)
	check(impacts.size() == 3, "A weaker event must not stack immediately after the strongest event")
