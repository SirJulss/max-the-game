extends Control
## Three short, replayable SPACE games inside the user's original animated CRT.
## clip() returns timing quality for RunData.try_clip(); no scene dependencies.
const ORIGINAL_MONITOR := preload("res://Assets/Gameplay/Streaming/Pc/PCOverlay.png")
const MAX_SPRITE := preload("res://Assets/Player/Idle/MaxIdle.png")
const JULIAN := preload("res://Assets/npc/julian.png")
const LOUIS := preload("res://Assets/npc/louis.png")
const TAN := preload("res://Assets/npc/tan.png")
const INK := Color("101726")
const MINT := Color("a4e55e")
const PINK := Color("ff779e")
const LOGICAL_SIZE := Vector2(800, 400)

var game_id := "cozy"
var elapsed := 0.0
var marker := 0.5
var cooldown := 0.0
var flash := 0.0
var last_good := true
var frozen := false
var action_count := 0
var attempts := 0
var _last_feedback_time := -10.0
var _last_target := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if frozen:
		return
	elapsed += delta
	var tempo := 2.5 if game_id == "cozy" else (3.2 if game_id in ["ranked", "sweaty"] else 2.8)
	marker = (sin(elapsed * tempo) + 1.0) * 0.5
	cooldown = maxf(0.0, cooldown - delta)
	flash = maxf(0.0, flash - delta * 1.9)
	queue_redraw()

func clip() -> float:
	if cooldown > 0.0 or frozen:
		return -1.0
	cooldown = 1.65
	play_action_feedback(marker >= 0.4 and marker <= 0.6)
	return marker

func play_action_feedback(success: bool = true) -> void:
	# Root may also report the model result after clip(); count that action once.
	if elapsed - _last_feedback_time < 0.05:
		return
	_last_feedback_time = elapsed
	_last_target = action_count
	last_good = success
	attempts += 1
	if success:
		action_count += 1
	flash = 1.0
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var monitor_frame := int(elapsed * 5.0) % 7
	draw_texture_rect_region(ORIGINAL_MONITOR, Rect2(Vector2.ZERO, size), Rect2(monitor_frame * 320, 0, 320, 180))
	var glass := Rect2(size.x * 18.0 / 320.0, size.y * 17.0 / 180.0, size.x * 284.0 / 320.0, size.y * 139.0 / 180.0)
	draw_set_transform(glass.position, 0, glass.size / LOGICAL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, LOGICAL_SIZE), INK)
	if game_id == "cozy":
		_draw_garden()
	elif game_id in ["ranked", "sweaty"]:
		_draw_shooter()
	else:
		_draw_court()
	_draw_controls()
	draw_set_transform(Vector2.ZERO)

func _text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _sprite(texture: Texture2D, at: Vector2, scale_factor: float = 2.0, one_frame: bool = false) -> void:
	var frame := 0 if one_frame else int(elapsed * 2.5) % 2
	draw_texture_rect_region(texture, Rect2(at.x - 16 * scale_factor, at.y - 61 * scale_factor, 32 * scale_factor, 64 * scale_factor), Rect2(frame * 32, 0, 32, 64))

func _draw_garden() -> void:
	draw_rect(Rect2(0, 0, 800, 307), Color("446743"))
	draw_rect(Rect2(0, 0, 800, 95), Color("76a795"))
	draw_circle(Vector2(722, 51), 30, Color("ffe09b"))
	for x in range(10, 800, 32):
		draw_rect(Rect2(x, 78, 13, 30), Color("ae9171"))
	draw_rect(Rect2(0, 89, 800, 6), Color("d2af7e"))
	_text("TURNIP FARM", Vector2(22, 29), 17, Color("eff6ce"))
	_text("HARVESTED %d" % action_count, Vector2(580, 29), 17, Color("eff6ce"))
	for plant in 12:
		var x := 46.0 + (plant % 4) * 122.0
		var y := 117.0 + floorf(plant / 4.0) * 61.0
		draw_rect(Rect2(x, y, 95, 47), Color("725346"))
		draw_rect(Rect2(x + 5, y + 5, 85, 37), Color("63463e"))
		if plant == action_count % 12:
			draw_rect(Rect2(x - 3, y - 3, 101, 53), MINT, false, 3)
		for turnip in 3:
			var center := Vector2(x + 19 + turnip * 28, y + 27)
			var sway := sin(elapsed * 2.0 + plant + turnip) * 2
			draw_circle(center, 7, Color("e6c5d1"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 4), center + Vector2(0, 14), center + Vector2(5, 4)]), Color("e6c5d1"))
			draw_line(center + Vector2(0, -3), center + Vector2(-7 + sway, -17), MINT, 4)
			draw_line(center + Vector2(0, -3), center + Vector2(7 + sway, -15), Color("74b953"), 4)
	_sprite(MAX_SPRITE, Vector2(620, 270), 2.25)
	_sprite(JULIAN, Vector2(715, 260), 1.85)
	draw_rect(Rect2(565, 277, 90, 17), Color("a37852"))
	if flash > 0 and last_good:
		var p := Vector2(590, 211 - (1.0 - flash) * 66)
		draw_circle(p, 17, Color("f1d5df"))
		draw_line(p, p + Vector2(-10, -27), MINT, 6)
		draw_line(p, p + Vector2(11, -25), MINT, 6)
		_text("+1", p + Vector2(26, 3), 24, MINT)

func _shooter_target(index: int) -> Vector2:
	var lane := index % 4
	return Vector2(132 + lane * 168, 144 + sin(elapsed * 1.25 + index) * 21)

func _draw_shooter() -> void:
	draw_rect(Rect2(0, 0, 800, 307), Color("35404d"))
	for x in range(0, 800, 50):
		draw_line(Vector2(x, 41), Vector2(x, 304), Color("414c59"), 1)
	for y in range(52, 307, 43):
		draw_line(Vector2(0, y), Vector2(800, y), Color("414c59"), 1)
	_text("RANKED RUSH", Vector2(22, 29), 17, Color("e5dbe4"))
	_text("TAGGED %d" % action_count, Vector2(633, 29), 17, MINT)
	var textures := [JULIAN, LOUIS, TAN, JULIAN]
	for target in 4:
		var p := _shooter_target(target)
		_sprite(textures[target], p, 1.75, target == 2)
		draw_rect(Rect2(p.x - 40, p.y + 8, 80, 8), Color("181f31"))
		if target == action_count % 4:
			draw_arc(p + Vector2(0, -51), 47, 0, TAU, 24, PINK, 3)
			draw_line(p + Vector2(-57, -51), p + Vector2(-33, -51), PINK, 3)
			draw_line(p + Vector2(33, -51), p + Vector2(57, -51), PINK, 3)
	var player_at := Vector2(400 + sin(elapsed * 0.7) * 80, 299)
	_sprite(MAX_SPRITE, player_at, 1.9)
	if flash > 0:
		var target_at := _shooter_target(_last_target % 4) + Vector2(0, -47)
		draw_line(player_at + Vector2(12, -51), target_at + (Vector2.ZERO if last_good else Vector2(63, 0)), Color(MINT if last_good else PINK, flash), 6)
		if last_good:
			draw_arc(target_at, 14 + (1 - flash) * 29, 0, TAU, 16, Color("ffe099"), 4)
	_text("PLASTIC IV", Vector2(22, 289), 13, Color("adbbcf"))

func _draw_court() -> void:
	draw_rect(Rect2(0, 0, 800, 307), Color("514155"))
	for panel in 11:
		var x := 15.0 + panel * 73
		draw_rect(Rect2(x, 45, 62, 213), Color("6b5061"), false, 3)
	_text("GOOSE COURT", Vector2(22, 29), 17, Color("f3d8c4"))
	_text("OBJECTIONS %d" % action_count, Vector2(563, 29), 17, MINT)
	draw_rect(Rect2(483, 77, 211, 135), Color("2d2c3d"))
	draw_rect(Rect2(491, 85, 195, 119), Color("866576"))
	_draw_goose(Vector2(567, 173 + sin(elapsed * 2) * 3), 2.2)
	_sprite(JULIAN, Vector2(113, 257), 1.9)
	_sprite(LOUIS, Vector2(210, 257), 1.9)
	_sprite(TAN, Vector2(307, 257), 1.9, true)
	draw_rect(Rect2(47, 259, 312, 34), Color("896351"))
	draw_rect(Rect2(43, 254, 320, 8), Color("c09472"))
	draw_rect(Rect2(443, 236, 306, 60), Color("896351"))
	draw_rect(Rect2(434, 226, 324, 11), Color("c09472"))
	_text("HONK COURT", Vector2(522, 274), 24, Color("ffe2ac"))
	var gavel_x := 701.0
	var gavel_y := 180.0 + (18.0 * flash if last_good else 0.0)
	draw_line(Vector2(gavel_x, gavel_y), Vector2(gavel_x - 23, gavel_y + 35), Color("d4a476"), 10)
	draw_rect(Rect2(gavel_x - 23, gavel_y - 11, 47, 24), Color("efbc81"))
	if flash > 0 and last_good:
		_text("HONK!", Vector2(540, 70 - (1.0 - flash) * 17), 33, Color("ffe2ac"))
		for wave in 3:
			draw_arc(Vector2(635, 152), 25 + wave * 16 + (1 - flash) * 17, -0.6, 0.6, 9, Color(MINT, flash), 3)

func _draw_goose(at: Vector2, factor: float) -> void:
	# Work in logical coordinates to keep the original monitor transform intact.
	draw_circle(at + Vector2(0, 9) * factor, 17 * factor, Color("e7e8eb"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-11, 1) * factor, at + Vector2(-29, -2) * factor, at + Vector2(-16, 17) * factor]), Color("e7e8eb"))
	draw_rect(Rect2(at + Vector2(5, -22) * factor, Vector2(13, 34) * factor), Color("e7e8eb"))
	draw_circle(at + Vector2(13, -21) * factor, 10 * factor, Color("f4f0ee"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(20, -24) * factor, at + Vector2(35, -19) * factor, at + Vector2(20, -15) * factor]), Color("ffc780"))
	draw_circle(at + Vector2(16, -24) * factor, 2 * factor, INK)
	draw_rect(Rect2(at + Vector2(-7, 7) * factor, Vector2(21, 17) * factor), Color("302c43"))
	for curl in 5:
		draw_circle(at + Vector2(4 + curl * 4, -31 - (2 if curl % 2 else 0)) * factor, 4 * factor, Color("c1bdca"))

func _draw_controls() -> void:
	draw_rect(Rect2(0, 307, 800, 93), Color("19242b"))
	var action := "HARVEST" if game_id == "cozy" else ("FIRE" if game_id in ["ranked", "sweaty"] else "HONK")
	_text("SPACE  ·  " + action, Vector2(37, 334), 20, Color("e6edce"))
	_text("HIT THE GREEN", Vector2(580, 333), 16, MINT)
	var lane := Rect2(37, 349, 726, 16)
	draw_rect(lane, Color("3c4a4b"))
	draw_rect(Rect2(lane.position.x + lane.size.x * 0.4, lane.position.y, lane.size.x * 0.2, lane.size.y), MINT)
	var mx := lane.position.x + marker * lane.size.x
	draw_line(Vector2(mx, 343), Vector2(mx, 372), Color("fff8dc"), 5)
	if cooldown > 0:
		draw_rect(Rect2(37, 384, 726 * minf(1.0, cooldown / 1.65), 4), Color("738b56"))
	if flash > 0:
		var result := "NICE!" if last_good else "MISS"
		_text(result, Vector2(354, 333), 23, MINT if last_good else PINK)
