extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
var remaining := 0.0

func _on_enter() -> void:
	remaining = player.begin_attack()
	animated_sprite_2d.play(player.get_attack_animation_for_direction(player.player_direction))
	animated_sprite_2d.frame = 0
	animated_sprite_2d.speed_scale = 3.8 * player.attack_speed

func _on_physics_process(delta: float) -> void:
	player.move_character(delta, 0.78 if player.weapon == "banhammer" else 0.95)
	remaining -= delta
	if player.wants_dash():
		transition.emit("Dash")
	elif remaining <= 0:
		transition.emit("Walk" if GameInputEvent.is_movement_input() else "Idle")

func _on_exit() -> void:
	animated_sprite_2d.speed_scale = 1.0
