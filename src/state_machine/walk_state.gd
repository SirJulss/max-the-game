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
	_current_anim = ""
	animated_sprite_2d.speed_scale = 1.0

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)

func _on_physics_process(delta: float) -> void:
	var input_dir: Vector2 = GameInputEvent.movement_input()
	var has_input := input_dir != Vector2.ZERO
	
	if Input.is_action_just_pressed("attack"):
		transition.emit("Attack")
		return
	
	# Bewegung: Zielgeschwindigkeit setzen, velocity in Richtung move_toward
	if has_input:
		var target_vel = input_dir.normalized() * run_speed
		player.velocity = player.velocity.move_toward(target_vel, accel * delta)
	else:
		if player.velocity.length() > 0.1:
			player.velocity = player.velocity.move_toward(Vector2.ZERO, decel * delta)
		else:
			player.velocity = Vector2.ZERO

	# Single move_and_slide pro Frame
	player.move_and_slide()

	# Facing lerp zur Maus
	var mouse_dir := (player.get_global_mouse_position() - player.global_position)
	if mouse_dir.length() < 0.001:
		mouse_dir = Vector2.DOWN
	player.player_direction = player.player_direction.move_toward(mouse_dir.normalized(), facing_lerp_speed * delta)

	# Animation abhängig von Richtung
	var anim = player.get_animation_for_direction(player.player_direction, false, "MaxWalkDown")
	_play_if_changed(anim)

	# anim-speed basierend auf Verhältnis Geschwindigkeit / run_speed
	var speed_ratio = clamp(player.velocity.length() / run_speed, 0.0, 1.6)
	animated_sprite_2d.speed_scale = 1.0 + speed_ratio * 1.4

	# --- Transitions ---
	# Dash nur einmalig beim Tastendruck starten, aber nur wenn auch Bewegungseingabe vorhanden ist.
	# Dadurch wird verhindert, dass beim Start (wenn Sprint gehalten ist, aber keine Bewegung) sofort gedasht wird.
	if Input.is_action_just_pressed("sprint") and has_input:
		transition.emit("Dash")
		return

	# Hold-to-sprint -> Run (wenn Sprint gehalten UND es gibt Bewegungseingabe)
	if Input.is_action_pressed("sprint") and has_input:
		transition.emit("Run")
		return

	# wenn kein Input -> skid / idle
	if not has_input:
		if player.velocity.length() > skid_start_speed:
			transition.emit("Skid")
		elif player.velocity.length() < 1.0:
			transition.emit("Idle")

func _on_exit() -> void:
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.stop()
	_current_anim = ""
