extends NodeState
@export var player: Player
@export var skid_friction := 0.88
@export var stop_threshold := 8.0
@export var min_skid_time := 0.08

func _on_physics_process(delta: float) -> void:
	player.update_aim()
	player.move_character(delta)
	if player.wants_dash():
		transition.emit("Dash")
	elif player.wants_attack():
		transition.emit("Attack")
	elif GameInputEvent.is_movement_input():
		transition.emit("Walk")
	elif player.velocity.length() < stop_threshold:
		transition.emit("Idle")
