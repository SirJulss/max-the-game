extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

@export var dash_speed: float = 900.0
@export var dash_time: float = 0.16
@export var allow_turn_during_dash: bool = false
@export var facing_lerp_speed: float = 48.0

var _elapsed: float = 0.0
var _dashing: bool = false
var _dash_dir: Vector2 = Vector2.ZERO
var _current_anim: String = ""

func _on_enter() -> void:
	_elapsed = 0.0
	_dashing = true

	# Priorisiere Eingabe-Richtung; falls keine Eingabe -> aktuelle Facing-Richtung
	var input_dir: Vector2 = GameInputEvent.movement_input()
	if input_dir.length() < 0.001:
		_dash_dir = player.player_direction.normalized()
		if _dash_dir.length() < 0.001:
			_dash_dir = Vector2.DOWN
	else:
		_dash_dir = input_dir.normalized()

	player.velocity = _dash_dir * dash_speed
	animated_sprite_2d.speed_scale = 1.8
	_current_anim = ""
	_play_if_changed(player.get_animation_for_direction(_dash_dir, false, "MaxWalkDown"))

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)

func _on_physics_process(delta: float) -> void:
	if not _dashing:
		transition.emit("Walk")
		return

	_elapsed += delta

	# Konstante Dash-Geschwindigkeit während Dash
	player.velocity = _dash_dir * dash_speed
	player.move_and_slide()

	# Facing während Dash
	if allow_turn_during_dash:
		player.player_direction = player.player_direction.move_toward(_dash_dir, facing_lerp_speed * delta)
	else:
		player.player_direction = _dash_dir

	var anim = player.get_animation_for_direction(player.player_direction, false, "MaxWalkDown")
	_play_if_changed(anim)

	# Ende des Dashs -> kontrolliert abbremsen und zurück in Walk
	if _elapsed >= dash_time:
		_dashing = false
		# bleibt etwas Momentum erhalten
		player.velocity = _dash_dir * (dash_speed * 0.35)
		transition.emit("Walk")

func _on_exit() -> void:
	animated_sprite_2d.speed_scale = 1.0
	animated_sprite_2d.stop()
	_current_anim = ""
