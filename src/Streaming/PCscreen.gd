extends Node2D

@export var player: Node2D
@export var animated_sprite: AnimatedSprite2D

var pc_active: bool = false

func _ready() -> void:
	# Zu Beginn ist das PC-Overlay verborgen
	animated_sprite.visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		pc_active = not pc_active
		animated_sprite.visible = pc_active
		
		if pc_active:
			# Bildschirm-Animation starten, falls nötig
			animated_sprite.frame = 0
			animated_sprite.play("on")
		else:
			# Bildschirm wieder ausschalten
			animated_sprite.frame = 6
			animated_sprite.stop()
