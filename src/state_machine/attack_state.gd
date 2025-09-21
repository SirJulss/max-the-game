extends NodeState
@export var player: Player
@export var animated_sprite_2d: AnimatedSprite2D

# Angriffs-Eigenschaften
@export var attack_cooldown: float = 0.9
@export var attack_duration: float = 1
@export var attack_slowdown: float = 0.3  # Stärkere Verlangsamung

var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var can_attack: bool = true
var attack_direction: Vector2
var _current_anim := ""

func _on_enter() -> void:
	print("Attack State entered")
	if not can_attack:
		print("Can't attack - cooldown active")
		transition.emit("Idle")
		return
		
	can_attack = false
	attack_timer = attack_duration
	cooldown_timer = attack_cooldown
	
	# Richtung des Angriffs basierend auf der aktuellen Blickrichtung
	attack_direction = player.player_direction
	print("Attack direction: ", attack_direction)
	
	var anim_name = player.get_attack_animation_for_direction(attack_direction)
	print("Attempting to play animation: ", anim_name)
	
	_play_if_changed(anim_name)
	
	# Optional: Angriffseffekte/Sound hier auslösen

func _play_if_changed(anim_name: String) -> void:
	if anim_name == "":
		return
		
	# Prüfen ob Animation existiert
	if not animated_sprite_2d.sprite_frames.has_animation(anim_name):
		print("ERROR: Animation '", anim_name, "' does not exist!")
		# Fallback-Animation
		anim_name = "MaxBFront"
	
	if anim_name != _current_anim:
		_current_anim = anim_name
		animated_sprite_2d.play(anim_name)
		print("Now playing: ", anim_name)

func _on_physics_process(delta: float) -> void:
	# Debug-Ausgabe
	print("Attack state physics process, timer: ", attack_timer)
	
	# Während des Angriffs verlangsamen wir die Bewegung stärker
	player.velocity = player.velocity.move_toward(Vector2.ZERO, player.decel * attack_slowdown * delta)
	player.move_and_slide()
	
	# Timer aktualisieren
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			print("Attack finished, transitioning to Idle")
			transition.emit("Idle")
	
	if cooldown_timer > 0:
		cooldown_timer -= delta
		if cooldown_timer <= 0:
			can_attack = true
			print("Cooldown finished")

func _on_exit() -> void:
	print("Attack State exited")
	animated_sprite_2d.stop()
	_current_anim = ""
