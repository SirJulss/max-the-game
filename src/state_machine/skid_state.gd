extends NodeState
@export var player: Player
@export var skid_friction: float = 0.85
@export var stop_threshold: float = 6.0
@export var min_skid_time: float = 0.12
@export var turn_responsiveness: float = 8.0

var skid_timer: float = 0.0
const EPS := 0.01

func _on_enter() -> void:
	skid_timer = 0.0

func _on_physics_process(_delta: float) -> void:
	skid_timer += _delta
	var input_dir: Vector2 = GameInputEvent.movement_input()
	var has_input: bool = input_dir != Vector2.ZERO

	# Framerate-unabhängige Dämpfung
	var frame_friction := pow(skid_friction, _delta * 60.0)
	player.velocity *= frame_friction

	# erlaubte Rückeroberung: langsames lenken oder sofort wenn Dot hoch
	if has_input and player.velocity.length() > 0.1:
		var inorm = input_dir.normalized()
		var vlen = player.velocity.length()
		if vlen > EPS:
			var vnorm = player.velocity / vlen
			var dot = inorm.dot(vnorm)
			if dot > 0.5:
				# Übergabe der Kontrolle: keep facing toward mouse (sanft)
				player.player_direction = player.player_direction.move_toward((player.get_global_mouse_position() - player.global_position).normalized(), 12.0 * _delta)
				if Input.is_action_pressed("sprint"):
					transition.emit("Run")
				else:
					transition.emit("Walk")
				return
			else:
				var target = inorm * vlen
				player.velocity = player.velocity.lerp(target, clamp(turn_responsiveness * _delta, 0.0, 1.0))

	player.move_and_slide()

	# Wenn langsam genug & Mindestzeit überschritten -> Idle
	if player.velocity.length() < stop_threshold and skid_timer > min_skid_time:
		player.velocity = Vector2.ZERO
		transition.emit("Idle")
		return

	if player.velocity.length() < EPS and skid_timer > min_skid_time:
		player.velocity = Vector2.ZERO
		transition.emit("Idle")

func _on_next_transitions() -> void:
	if GameInputEvent.is_movement_input() and player.velocity.length() < 1.0:
		transition.emit("Walk")

func _on_exit() -> void:
	pass
