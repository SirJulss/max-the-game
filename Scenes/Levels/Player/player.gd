class_name Player
extends CharacterBody2D

signal health_changed(hp: float, maximum: float)
signal died
signal attack_requested(direction: Vector2, weapon: String, combo: int)
signal special_requested
signal dashed
signal hurt(amount: float, source: Vector2)

@export var decel := 2400.0
@export var accel := 2600.0
var player_direction := Vector2.DOWN
var active := false
var allow_combat := true
var max_hp := 100.0
var hp := 100.0
var damage := 1.0
var move_speed := 1.0
var attack_speed := 1.0
var armor := 0.0
var weapon := "keyboard"
var dash_cooldown := 1.1
var dash_remaining := 0.0
var special_cooldown := 6.0
var special_remaining := 0.0
var attack_remaining := 0.0
var invulnerable := 0.0
var hit_flash := 0.0
var combo := 0
var combo_timeout := 0.0
var bounds := Rect2(110, 300, 1060, 330)
var is_dashing := false
var knockback := Vector2.ZERO

const DIRS_8 := {"R": Vector2.RIGHT, "RU": Vector2(0.707, -0.707), "U": Vector2.UP, "LU": Vector2(-0.707, -0.707), "L": Vector2.LEFT, "LD": Vector2(-0.707, 0.707), "D": Vector2.DOWN, "RD": Vector2(0.707, 0.707)}
const MOVE_ANIM_MAP_8 := {"R": "MaxWalkRight", "RU": "MaxWalkBackRight", "U": "MaxWalkBack", "LU": "MaxWalkBackLeft", "L": "MaxWalkLeft", "LD": "MaxWalkFrontLeft", "D": "MaxWalkFront", "RD": "MaxWalkFrontRight"}
const ATTACK_ANIM_MAP_8 := {"R": "MaxBRight", "RU": "MaxBBackRight", "U": "MaxBBack", "LU": "MaxBBackLeft", "L": "MaxBLeft", "LD": "MaxBFrontLeft", "D": "MaxBFront", "RD": "MaxBFrontRight"}
const IDLE_DIRS := {"Right": Vector2.RIGHT, "Up": Vector2.UP, "Left": Vector2.LEFT, "Down": Vector2.DOWN}
const IDLE_ANIM_MAP := {"Right": "MaxIdleRight", "Up": "MaxIdleBack", "Left": "MaxIdleLeft", "Down": "MaxIdleFront"}

func _ready() -> void:
	$AnimatedSprite2D.position = Vector2(0, -42)
	$AnimatedSprite2D.scale = Vector2(1.5, 1.5)
	$CollisionShape2D.position = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	set_active(active)

func configure(stats: Dictionary) -> void:
	max_hp = float(stats.get("max_hp", 100))
	hp = clampf(float(stats.get("hp", max_hp)), 1, max_hp)
	damage = float(stats.get("damage", 1.0))
	attack_speed = maxf(0.4, float(stats.get("attack_speed", 1.0)))
	move_speed = float(stats.get("move_speed", 1.0))
	armor = float(stats.get("armor", 0))
	weapon = str(stats.get("weapon", "keyboard"))
	dash_cooldown = maxf(0.35, 1.1 * float(stats.get("dash_cooldown", 1.0)))
	dash_remaining = 0
	attack_remaining = 0
	special_remaining = 0
	invulnerable = 0.6
	combo = 0
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	health_changed.emit(hp, max_hp)

func set_active(value: bool) -> void:
	active = value
	if is_node_ready():
		$StateMachine.set_physics_process(value)
		$StateMachine.set_process(value)
		if value:
			$StateMachine.transition_to("idle")
		else:
			velocity = Vector2.ZERO
			is_dashing = false
			$StateMachine.transition_to("idle")
			$AnimatedSprite2D.modulate = Color.WHITE
			$AnimatedSprite2D.play("MaxIdleFront")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return
	dash_remaining = maxf(0, dash_remaining - delta)
	attack_remaining = maxf(0, attack_remaining - delta)
	special_remaining = maxf(0, special_remaining - delta)
	invulnerable = maxf(0, invulnerable - delta)
	hit_flash = maxf(0, hit_flash - delta)
	combo_timeout = maxf(0, combo_timeout - delta)
	if combo_timeout == 0:
		combo = 0
	knockback = knockback.move_toward(Vector2.ZERO, 1800 * delta)
	$AnimatedSprite2D.modulate = Color(4, 0.6, 0.8) if hit_flash > 0 else (Color(0.5, 1.6, 1.5, 0.65) if is_dashing else Color.WHITE)
	if allow_combat and InputMap.has_action("special") and Input.is_action_just_pressed("special") and special_remaining <= 0:
		special_remaining = special_cooldown
		invulnerable = maxf(invulnerable, 0.3)
		special_requested.emit()
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 21, Color(0.015, 0.025, 0.07, 0.45))
	draw_set_transform(Vector2.ZERO)
	if active and allow_combat:
		draw_arc(Vector2.ZERO, 24, 0, TAU, 32, Color("66f6d5") if dash_remaining == 0 else Color(0.3, 0.55, 0.65, 0.5), 2.0)
		var tip := player_direction * 34.0
		draw_line(tip, tip + player_direction * 12, Color("f8df83"), 3)

func update_aim() -> void:
	var direction := get_global_mouse_position() - global_position
	if direction.length_squared() > 16:
		player_direction = direction.normalized()

func move_character(delta: float, speed_scale: float = 1.0) -> void:
	var movement := GameInputEvent.movement_input()
	var desired := movement * 270.0 * move_speed * speed_scale
	velocity = velocity.move_toward(desired, (accel if movement != Vector2.ZERO else decel) * delta)
	var saved_velocity := velocity
	velocity += knockback
	move_and_slide()
	velocity = saved_velocity
	clamp_to_yard()

func clamp_to_yard() -> void:
	position.x = clampf(position.x, bounds.position.x + 18, bounds.end.x - 18)
	position.y = clampf(position.y, bounds.position.y + 18, bounds.end.y - 18)

func wants_dash() -> bool:
	return dash_remaining <= 0 and ((InputMap.has_action("dash") and Input.is_action_just_pressed("dash")) or Input.is_action_just_pressed("sprint"))

func wants_attack() -> bool:
	return allow_combat and attack_remaining <= 0 and Input.is_action_pressed("attack")

func begin_attack() -> float:
	update_aim()
	combo = combo % 3 + 1
	combo_timeout = 1.0
	var duration := 0.30
	if weapon == "banhammer":
		duration = 0.59
	elif weapon == "capslock":
		duration = 0.22
	attack_remaining = duration / attack_speed
	attack_requested.emit(player_direction, weapon, combo)
	return minf(0.32, attack_remaining * 0.75)

func take_damage(amount: float, source: Vector2) -> bool:
	if not active or hp <= 0 or invulnerable > 0 or is_dashing:
		return false
	var received := maxf(1, amount - armor)
	hp = maxf(0, hp - received)
	invulnerable = 0.68
	hit_flash = 0.12
	knockback = (global_position - source).normalized() * 230
	health_changed.emit(hp, max_hp)
	hurt.emit(received, source)
	if hp <= 0:
		set_active(false)
		died.emit()
	return true

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func _closest_dir_key(vec: Vector2, table: Dictionary) -> String:
	var key := ""
	var score := -2.0
	for candidate in table:
		var dot: float = vec.normalized().dot(table[candidate])
		if dot > score:
			score = dot
			key = candidate
	return key

func get_animation_for_mouse(mouse_pos: Vector2, use_idle: bool = false, fallback: String = "") -> String:
	return get_animation_for_direction(mouse_pos - global_position, use_idle, fallback)

func get_animation_for_direction(vec: Vector2, use_idle: bool = false, fallback: String = "") -> String:
	if vec.length_squared() < 0.01:
		vec = Vector2.DOWN
	return str(IDLE_ANIM_MAP.get(_closest_dir_key(vec, IDLE_DIRS), fallback)) if use_idle else str(MOVE_ANIM_MAP_8.get(_closest_dir_key(vec, DIRS_8), fallback))

func get_attack_animation_for_direction(vec: Vector2, fallback: String = "MaxBFront") -> String:
	return str(ATTACK_ANIM_MAP_8.get(_closest_dir_key(vec, DIRS_8), fallback))
