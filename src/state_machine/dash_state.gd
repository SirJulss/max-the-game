extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var dash_speed := 790.0
@export var dash_time := 0.18
var elapsed := 0.0
var direction := Vector2.DOWN

func _on_enter() -> void:
	elapsed = 0
	direction = GameInputEvent.movement_input()
	if direction == Vector2.ZERO:
		direction = player.player_direction
	player.is_dashing = true
	player.dash_remaining = player.dash_cooldown
	player.invulnerable = maxf(player.invulnerable, dash_time + 0.07)
	player.dashed.emit()
	animated_sprite_2d.play(player.get_animation_for_direction(direction))
	animated_sprite_2d.speed_scale = 3.0

func _on_physics_process(delta: float) -> void:
	elapsed += delta
	player.velocity = direction * dash_speed
	player.move_and_slide()
	player.clamp_to_yard()
	if elapsed >= dash_time:
		player.velocity = direction * 220
		transition.emit("Walk")

func _on_exit() -> void:
	player.is_dashing = false
	animated_sprite_2d.speed_scale = 1.0
