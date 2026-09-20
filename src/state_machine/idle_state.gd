extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

func _on_enter() -> void:
	animated_sprite_2d.speed_scale = 1

func _on_physics_process(delta: float) -> void:
	player.update_aim()
	player.move_character(delta)
	animated_sprite_2d.play(player.get_animation_for_direction(player.player_direction, true))
	if player.wants_dash():
		transition.emit("Dash")
	elif player.wants_attack():
		transition.emit("Attack")
	elif GameInputEvent.is_movement_input():
		transition.emit("Walk")
