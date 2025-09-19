# idle.gd
extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

var _current_anim := ""

func _on_enter() -> void:
	_current_anim = ""

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)

func _on_physics_process(_delta: float) -> void:
	# Wenn Input vorhanden -> Walk
	if GameInputEvent.is_movement_input():
		player.player_direction = GameInputEvent.movement_input().normalized()
		transition.emit("Walk")
		return

	# Blickrichtung zur Maus (Idle verwendet 4 Richtungen)
	var anim = player.get_animation_for_mouse(player.get_global_mouse_position(), true, "MaxIdleFront")
	_play_if_changed(anim)

func _on_exit() -> void:
	animated_sprite_2d.stop()
