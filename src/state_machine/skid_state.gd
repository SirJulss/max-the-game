extends NodeState
@export var player: Player
@export var skid_friction: float = 0.85
@export var stop_threshold: float = 6.0
@export var min_skid_time: float = 0.08
@export var turn_responsiveness: float = 8.0
@export var regain_dot_threshold: float = 0.5   # wie gut Input mit velocity übereinstimmen muss
@export var immediate_regain_speed: float = 30.0 # wenn vlen < das -> sofort regain

var skid_timer: float = 0.0
const EPS := 0.0001

func _on_enter() -> void:
	skid_timer = 0.0

func _on_physics_process(_delta: float) -> void:
	skid_timer += _delta

	var input_dir: Vector2 = GameInputEvent.movement_input()
	var has_input: bool = input_dir != Vector2.ZERO

	# Framerate-unabhängige Dämpfung (angepasst)
	var frame_friction := pow(clamp(skid_friction, 0.0, 1.0), _delta * 60.0)
	player.velocity *= frame_friction

	# Wenn Input UND die Geschwindigkeit sehr klein ist -> sofort Kontrolle zurück
	var vlen = player.velocity.length()
	if has_input and vlen <= immediate_regain_speed:
		# sofort zurück zur Kontrolle (Run wenn sprint gedrückt)
		if Input.is_action_pressed("sprint"):
			transition.emit("Run")
		else:
			transition.emit("Walk")
		return

	# Wenn Input vorhanden und Geschwindigkeit ausreichend groß -> evtl. direkte Rückeroberung
	if has_input and vlen > EPS:
		var inorm = input_dir.normalized()
		var vnorm = player.velocity / vlen
		var dot = inorm.dot(vnorm)
		if dot >= regain_dot_threshold:
			# Spieler will in etwa in die gleiche Richtung wie Momentum -> sofort Kontrolle zurück
			if Input.is_action_pressed("sprint"):
				transition.emit("Run")
			else:
				transition.emit("Walk")
			return
		else:
			# Spieler lenkt gegen das Momentum → erlauben, dass velocity langsam in Input-Richtung lerpt
			var target = inorm * vlen
			player.velocity = player.velocity.lerp(target, clamp(turn_responsiveness * _delta, 0.0, 1.0))

	# Bewegung ausführen
	player.move_and_slide()

	# Blickrichtung → immer Maus (optional)
	var mouse_dir := (player.get_global_mouse_position() - player.global_position)
	if mouse_dir.length() < 0.001:
		mouse_dir = Vector2.DOWN
	player.player_direction = player.player_direction.move_toward(mouse_dir.normalized(), 12.0 * _delta)

	# Wenn langsam genug & Mindestzeit überschritten -> Idle
	if vlen < stop_threshold and skid_timer > min_skid_time:
		player.velocity = Vector2.ZERO
		transition.emit("Idle")
		return

func _on_next_transitions() -> void:
	# Fallback: falls Input vorhanden und praktisch kein Momentum -> Walk
	if GameInputEvent.is_movement_input() and player.velocity.length() < 1.0:
		transition.emit("Walk")
