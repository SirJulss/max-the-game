extends NodeState

@export var player: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D

var direction: Vector2

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	if Input.is_action_pressed("move_left"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		direction = Vector2.RIGHT
	elif Input.is_action_pressed("move_up"):
		direction = Vector2.UP
	elif Input.is_action_pressed("move_down"):
		direction = Vector2.DOWN
	else:
		direction = Vector2.ZERO

	if direction == Vector2.UP:
		animated_sprite_2d.play("MaxIdleBack")
	elif direction == Vector2.RIGHT:
		animated_sprite_2d.play("MaxIdleRight")
	elif direction == Vector2.DOWN:
		animated_sprite_2d.play("MaxIdleFront")
	elif direction == Vector2.LEFT:
		animated_sprite_2d.play("MaxIdleLeft")

func _on_next_transitions() -> void:
	pass


func _on_enter() -> void:
	pass


func _on_exit() -> void:
	pass
