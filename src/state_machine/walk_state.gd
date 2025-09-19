extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var walk_speed: int = 70
@export var sprint_speed: int = 160   # schneller laufen

var animation_map := {
	Vector2.UP: "MaxWalkUp",
	Vector2.DOWN: "MaxWalkDown",
	Vector2.LEFT: "MaxWalkLeft",
	Vector2.RIGHT: "MaxWalkRight",
	Vector2(1, -1).normalized(): "MaxWalkRightUp",
	Vector2(1, 1).normalized(): "MaxWalkRightDown",
	Vector2(-1, -1).normalized(): "MaxWalkLeftUp",
	Vector2(-1, 1).normalized(): "MaxWalkLeftDown"
}

func _on_physics_process(_delta: float) -> void:
	var direction: Vector2 = GameInputEvent.movement_input()

	# Sprint
	var current_speed = walk_speed
	if Input.is_action_pressed("sprint"):   
		current_speed = sprint_speed
		
	if direction != Vector2.ZERO:
		var animation_name = animation_map.get(direction, "MaxWalkDown")
		animated_sprite_2d.play(animation_name)

	player.velocity = direction * current_speed
	player.move_and_slide()

	if direction != Vector2.ZERO:
		player.player_direction = direction

func _on_next_transitions() -> void:
	if !GameInputEvent.is_movement_input():
		transition.emit("Idle")

func _on_enter() -> void:
	pass

func _on_exit() -> void:
	animated_sprite_2d.stop()
