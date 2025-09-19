extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

@export var run_speed: float = 220.0
@export var accel: float = 1600.0
@export var decel: float = 1400.0
@export var skid_start_speed: float = 40.0
@export var facing_lerp_speed: float = 16.0

var _current_anim := ""

func _on_enter() -> void:
	animated_sprite_2d.speed_scale = 1.6
	_current_anim = ""

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)

func _on_physics_process(_delta: float) -> void:
	var input_dir: Vector2 = GameInputEvent.movement_input()
	var has_input := input_dir != Vector2.ZERO

	if has_input:
		var target_vel = input_dir.normalized() * run_speed
		player.velocity = player.velocity.move_toward(target_vel, accel * _delta)
		player.move_and_slide()
	else:
		# abbremsen falls sprint aufgehört
		if player.velocity.length() > 0.1:
			player.velocity = player.velocity.move_toward(Vector2.ZERO, decel * _delta)
			player.move_and_slide()
		else:
			player.velocity = Vector2.ZERO

	# Facing lerp zur Maus (etwas schneller beim sprinten)
	var mouse_dir := (player.get_global_mouse_position() - player.global_position)
	if mouse_dir.length() < 0.001:
		mouse_dir = Vector2.DOWN
	player.player_direction = player.player_direction.move_toward(mouse_dir.normalized(), facing_lerp_speed * _delta)

	var anim = player.get_animation_for_direction(player.player_direction, false, "MaxWalkDown")
	_play_if_changed(anim)

	# anim-speed basierend auf Verhältnis Geschwindigkeit / run_speed
	var speed_ratio = clamp(player.velocity.length() / run_speed, 0.0, 1.6)
	animated_sprite_2d.speed_scale = 1.0 + speed_ratio * 1.4

	# sprint losgelassen -> zurück zu Walk
	if not Input.is_action_pressed("sprint"):
		transition.emit("Walk")
	else:
		# wenn kein Input aber noch momentum -> skid/idle
		if not has_input:
			if player.velocity.length() > skid_start_speed:
				transition.emit("Skid")
			elif player.velocity.length() < 1.0:
				transition.emit("Idle")

func _on_exit() -> void:
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.stop()
