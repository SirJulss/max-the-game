extends NodeState
@export var player: Player

# Tunables (inspectable)
@export var dash_speed: float = 700.0
@export var dash_duration: float = 0.18
@export var dash_tap_max: float = 0.20    # Sekunden: max Dauer, damit es als Tap gilt
@export var dash_cooldown: float = 0.6    # Sekunden

# Interner (statischer) Cooldown - shared, persistent
static var _cooldown_remaining: float = 0.0

# Instanzzustand
var _state: String = "decide"   # "decide" | "dashing"
var _dash_timer: float = 0.0

# Tap-Messung (framebasiert)
var _press_elapsed: float = 0.0
var _measuring_press: bool = false

# --- wird von Run/Walk/Idle jede Frame aufgerufen, damit Cooldown tickt ---
func _tick(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)

# öffentliche Abfrage: darf eine Dash-Request akzeptiert werden?
func can_accept_request() -> bool:
	return _state != "dashing" and _cooldown_remaining <= 0.0

func _on_enter() -> void:
	_state = "decide"
	_dash_timer = 0.0
	_press_elapsed = 0.0
	_measuring_press = true

func _on_physics_process(delta: float) -> void:
	if _state == "decide":
		if _measuring_press:
			_press_elapsed += delta

		# Sprint released -> prüfen ob Tap und Cooldown
		if Input.is_action_just_released("sprint"):
			_measuring_press = false
			if _press_elapsed <= dash_tap_max:
				if _cooldown_remaining <= 0.0:
					_start_dash()
				else:
					_cancel_and_return()
			else:
				_cancel_and_return()
			return

		# Tap-Fenster verstrichen -> kein Dash
		if _press_elapsed > dash_tap_max:
			_cancel_and_return()
			return

	elif _state == "dashing":
		# Dash-Bewegung: nutze zuletzt gedrückte Bewegungsrichtung (WASD)
		var dir = GameInputEvent.direction
		if dir.length() < 0.001:
			dir = player.player_direction
		if dir.length() < 0.001:
			dir = Vector2.DOWN
		player.velocity = dir.normalized() * dash_speed

		# robust bewegen und sofortige Kollision erkennen
		var displacement = player.velocity * delta
		var collision = player.move_and_collide(displacement)
		if collision:
			# Kollision -> abbrechen und passenden State wählen
			player.velocity = Vector2.ZERO
			_state = "decide"
			if Input.is_action_pressed("sprint"):
				transition.emit("Run")
			else:
				if GameInputEvent.is_movement_input():
					transition.emit("Walk")
				else:
					transition.emit("Idle")
			return

		# Timer runterzählen
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			if Input.is_action_pressed("sprint"):
				transition.emit("Run")
			else:
				if GameInputEvent.is_movement_input():
					transition.emit("Walk")
				else:
					transition.emit("Idle")

func _start_dash() -> void:
	_state = "dashing"
	_dash_timer = dash_duration
	_press_elapsed = 0.0
	_measuring_press = false
	_cooldown_remaining = dash_cooldown
	# initial velocity wird in dashing-block gesetzt, damit Input-Richtung aktuell ist

func _cancel_and_return() -> void:
	_measuring_press = false
	_press_elapsed = 0.0
	_state = "decide"

	if Input.is_action_pressed("sprint"):
		transition.emit("Run")
	else:
		if GameInputEvent.is_movement_input():
			transition.emit("Walk")
		else:
			transition.emit("Idle")

func _on_exit() -> void:
	if _state == "dashing":
		player.velocity = player.velocity.move_toward(Vector2.ZERO, dash_speed * 0.5)

	_state = "decide"
	_press_elapsed = 0.0
	_measuring_press = false
