extends NodeState

@export var player: CharacterBody2D
@export var animated_sprite_2d: AnimatedSprite2D

var direction: Vector2

func _on_process(_delta : float) -> void:
	pass


func _on_physics_process(_delta : float) -> void:
	direction = GameInputEvent.movement_input()

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
