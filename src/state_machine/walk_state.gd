extends NodeState

@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D
@export var speed: int = 50

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	var direction: Vector2 = GameInputEvent.movement_input()
	
	if direction == Vector2.UP:
		animated_sprite_2d.play("MaxWalkUp")
	elif direction == Vector2.RIGHT:
		animated_sprite_2d.play("MaxWalkRight")
	elif direction == Vector2.DOWN:
		animated_sprite_2d.play("MaxWalkDown")
	elif direction == Vector2.LEFT:
		animated_sprite_2d.play("MaxWalkLeft")
	
	if direction != Vector2.ZERO:
		player.player_direction = direction

func _on_next_transitions() -> void:
	GameInputEvent.movement_input()
	
	if !GameInputEvent.is_movement_input():
		transition.emit("Idle")


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	animated_sprite_2d.stop()
