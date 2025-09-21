extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

@export var sprint_speed: float = 360.0      # schnellere Geschwindigkeit beim Sprinten (Run)
@export var accel: float = 2200.0
@export var decel: float = 1800.0
@export var skid_start_speed: float = 60.0
@export var facing_lerp_speed: float = 20.0

var _current_anim := ""

func _on_enter() -> void:
	_current_anim = ""
	animated_sprite_2d.speed_scale = 1.6

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)

func _on_physics_process(delta: float) -> void:
	var input_dir: Vector2 = GameInputEvent.movement_input()
	var has_input := input_dir != Vector2.ZERO

	# Wenn Sprint nicht mehr gehalten -> zurück zu Walk
	if not Input.is_action_pressed("sprint"):
		transition.emit("Walk")
		return

	# Bewegung: Sprint-Geschwindigkeit anstreben
	if has_input:
		var target_vel = input_dir.normalized() * sprint_speed
		player.velocity = player.velocity.move_toward(target_vel, accel * delta)
	else:
		# Falls kein Input, trotzdem abbremsen (oder direkt Skid wenn noch schnell)
		if player.velocity.length() > 0.1:
			player.velocity = player.velocity.move_toward(Vector2.ZERO, decel * delta)
		else:
			player.velocity = Vector2.ZERO

	# Single move_and_slide pro Frame
	player.move_and_slide()

	# Facing lerp zur Maus (etwas schneller beim Sprint)
	var mouse_dir := (player.get_global_mouse_position() - player.global_position)
	if mouse_dir.length() < 0.001:
		mouse_dir = Vector2.DOWN
	player.player_direction = player.player_direction.move_toward(mouse_dir.normalized(), facing_lerp_speed * delta)

	# Animation abhängig von Richtung (du kannst hier eigene Sprint-Animationen setzen)
	var anim = player.get_animation_for_direction(player.player_direction, false, "MaxRunDown")
	_play_if_changed(anim)

	# anim-speed basierend auf Verhältnis Geschwindigkeit / sprint_speed
	var speed_ratio = clamp(player.velocity.length() / sprint_speed, 0.0, 1.8)
	animated_sprite_2d.speed_scale = 1.2 + speed_ratio * 1.5

	# Falls kein Input und noch viel Momentum -> Skid, sonst Idle (wenn sehr langsam)
	if not has_input:
		if player.velocity.length() > skid_start_speed:
			transition.emit("Skid")
		elif player.velocity.length() < 1.0:
			transition.emit("Idle")

func _on_exit() -> void:
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.stop()
	_current_anim = ""
