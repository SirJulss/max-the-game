class_name GameInputEvent
extends Node

static var direction: Vector2 = Vector2.ZERO

static func movement_input() -> Vector2:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1

	direction = dir.normalized()
	return direction

static func is_movement_input() -> bool:
	# direkt prüfen, ob irgendeine Bewegungsaktion gedrückt ist
	return Input.is_action_pressed("move_left") \
		or Input.is_action_pressed("move_right") \
		or Input.is_action_pressed("move_up") \
		or Input.is_action_pressed("move_down")
