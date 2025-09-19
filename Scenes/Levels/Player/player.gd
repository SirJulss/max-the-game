class_name Player
extends CharacterBody2D

# ----------------------
# Blick-/Facing-Info
# ----------------------
var player_direction: Vector2 = Vector2.DOWN

# ----------------------
# Richtungen & Animationen
# ----------------------
var DIRS_8 := {
	"R":  Vector2(1, 0).normalized(),
	"RU": Vector2(1, -1).normalized(),
	"U":  Vector2(0, -1).normalized(),
	"LU": Vector2(-1, -1).normalized(),
	"L":  Vector2(-1, 0).normalized(),
	"LD": Vector2(-1, 1).normalized(),
	"D":  Vector2(0, 1).normalized(),
	"RD": Vector2(1, 1).normalized()
}

var ANIM_MAP_8 := {
	"R":  "MaxWalkRight",
	"RU": "MaxWalkRightUp",
	"U":  "MaxWalkUp",
	"LU": "MaxWalkLeftUp",
	"L":  "MaxWalkLeft",
	"LD": "MaxWalkLeftDown",
	"D":  "MaxWalkDown",
	"RD": "MaxWalkRightDown"
}

var IDLE_DIRS := {
	"Right": Vector2.RIGHT,
	"Up":    Vector2.UP,
	"Left":  Vector2.LEFT,
	"Down":  Vector2.DOWN
}

var IDLE_ANIM_MAP := {
	"Right": "MaxIdleRight",
	"Up":    "MaxIdleBack",
	"Left":  "MaxIdleLeft",
	"Down":  "MaxIdleFront"
}

# ----------------------
# Initialisierung
# ----------------------
func _ready() -> void:
	if player_direction.length() < 0.001:
		player_direction = Vector2.DOWN
	else:
		player_direction = player_direction.normalized()

# ----------------------
# Hilfsfunktionen
# ----------------------
func _closest_dir_key(vec: Vector2, dir_table: Dictionary) -> String:
	if vec.length() < 0.001:
		for k in dir_table.keys():
			return k
	var d = vec.normalized()
	var best_key := ""
	var best_dot := -2.0
	for key in dir_table.keys():
		var v = dir_table[key]
		var dot = d.dot(v)
		if dot > best_dot:
			best_dot = dot
			best_key = key
	return best_key

func get_animation_for_mouse(mouse_pos: Vector2, use_idle: bool = false, fallback: String = "") -> String:
	var dir := mouse_pos - global_position
	if dir.length() < 0.001:
		dir = Vector2.DOWN
	if use_idle:
		var key = _closest_dir_key(dir, IDLE_DIRS)
		return IDLE_ANIM_MAP.get(key, fallback)
	else:
		var key = _closest_dir_key(dir, DIRS_8)
		return ANIM_MAP_8.get(key, fallback)

func get_animation_for_direction(vec: Vector2, use_idle: bool = false, fallback: String = "") -> String:
	if vec.length() < 0.001:
		vec = Vector2.DOWN
	if use_idle:
		var key = _closest_dir_key(vec, IDLE_DIRS)
		return IDLE_ANIM_MAP.get(key, fallback)
	else:
		var key = _closest_dir_key(vec, DIRS_8)
		return ANIM_MAP_8.get(key, fallback)
