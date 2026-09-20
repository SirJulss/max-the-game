extends Control
## Three different input games inside the user's original animated CRT.
## resolve_action("click", stage.get_local_mouse_position()) uses local pixels.
## primary/left/right use no position. -1 rejects, 0.5 hits, 0.0 misses.
## timed_out only reports unanswered court cases; root applies try_clip(0.0).
## clip() remains the primary-action compatibility entry point.
signal timed_out
const FX := preload("res://src/presentation/pixel_fx.gd")
const ORIGINAL_MONITOR := preload("res://Assets/Gameplay/Streaming/Pc/PCOverlay.png")
const MAX_SPRITE := preload("res://Assets/Player/Idle/MaxIdle.png")
const JULIAN := preload("res://Assets/npc/julian.png")
const LOUIS := preload("res://Assets/npc/louis.png")
const TAN := preload("res://Assets/npc/tan.png")
const INK := Color("101726")
const MINT := Color("a4e55e")
const PINK := Color("ff779e")
const LOGICAL_SIZE := Vector2(800, 400)
const ACTION_COOLDOWN := 1.65
const COZY_ZONE := Vector2(0.30, 0.70)
const COURT_WINDOW := 2.8
const COURT_LEFT := Rect2(37, 323, 340, 51)
const COURT_RIGHT := Rect2(423, 323, 340, 51)
const SHOT_RADIUS := 46.0

var game_id := "cozy"
var elapsed := 0.0
var marker := 0.5
var cooldown := 0.0
var flash := 0.0
var last_good := true
var frozen := false
var action_count := 0
var attempts := 0
var _last_target := 0
var _target_index := 0
var _target_age := 0.0
var _shot_position := Vector2.ZERO
var _shot_assisted := false
var _case_index := 0
var court_answer := "right"
var court_time_left := COURT_WINDOW
var court_active := true
var _verdict := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if frozen or not is_finite(delta) or delta <= 0.0:
		return
	# Match RunData's stall guard: recovering focus must not skip a whole case.
	delta = minf(delta, 1.0)
	elapsed += delta
	var tempo := 1.9 if game_id == "cozy" else 2.7
	marker = (sin(elapsed * tempo) + 1.0) * 0.5
	var previous_cooldown := cooldown
	cooldown = maxf(0.0, cooldown - delta)
	flash = maxf(0.0, flash - delta * 1.9)
	if _is_ranked():
		_target_age += delta
		if _target_age >= 4.2:
			_advance_target()
	elif game_id == "weird":
		if not court_active:
			if cooldown <= 0.0:
				_next_case()
		else:
			court_time_left = maxf(0.0, court_time_left - maxf(0.0, delta - previous_cooldown))
			if court_time_left <= 0.0:
				_verdict = "TOO SLOW"
				_commit_result(false)
				court_active = false
				timed_out.emit()
	queue_redraw()

func clip() -> float:
	return resolve_action("primary")

func control_hint() -> String:
	if game_id == "cozy":
		return "SPACE OR CLICK / HARVEST IN GREEN"
	if _is_ranked():
		return "CLICK THE PINK TARGET / SPACE ASSIST"
	return "FLOWER: A / FREE    BREAD: D / BONK"

func primary_label() -> String:
	if game_id == "cozy":
		return "SPACE / HARVEST"
	if _is_ranked():
		return "SPACE / AIM ASSIST"
	return "A / FREE"

func _is_ranked() -> bool:
	return game_id in ["ranked", "sweaty"]

func _glass_rect() -> Rect2:
	return Rect2(size.x * 18.0 / 320.0, size.y * 17.0 / 180.0, size.x * 284.0 / 320.0, size.y * 139.0 / 180.0)

func logical_to_local(point: Vector2) -> Vector2:
	# Public for input-coordinate tests and accessibility overlays.
	var glass := _glass_rect()
	return glass.position + point * glass.size / LOGICAL_SIZE

func resolve_action(action: String, position: Vector2 = Vector2.ZERO) -> float:
	if frozen or cooldown > 0.0:
		return -1.0
	var logical := Vector2.ZERO
	if action == "click":
		var glass := _glass_rect()
		if glass.size.x <= 0 or glass.size.y <= 0 or not glass.has_point(position):
			return -1.0
		logical = (position - glass.position) * LOGICAL_SIZE / glass.size
	if game_id == "cozy":
		if not action in ["primary", "click"]:
			return -1.0
		return _commit_result(marker >= COZY_ZONE.x and marker <= COZY_ZONE.y)
	if _is_ranked():
		if not action in ["primary", "click"]:
			return -1.0
		if action == "click" and not Rect2(0, 36, 800, 271).has_point(logical):
			return -1.0
		_last_target = _target_index
		var target := _target_center(_target_index)
		_shot_assisted = action == "primary"
		# Space uses the visible assist timing lane; mouse aim bypasses timing.
		var hit := (marker >= 0.4 and marker <= 0.6) if _shot_assisted else logical.distance_to(target) <= SHOT_RADIUS
		_shot_position = target + (Vector2.ZERO if hit else Vector2(67, 0)) if _shot_assisted else logical
		var result := _commit_result(hit)
		if hit:
			_advance_target()
		return result
	if not court_active:
		return -1.0
	if action == "click":
		if COURT_LEFT.has_point(logical):
			action = "left"
		elif COURT_RIGHT.has_point(logical):
			action = "right"
		else:
			return -1.0
	if action == "primary":
		action = "left"
	if not action in ["left", "right"]:
		return -1.0
	var correct := action == court_answer
	_verdict = ("FREE!" if action == "left" else "BONK!") if correct else "WRONG VERDICT"
	court_active = false
	return _commit_result(correct)

func _commit_result(success: bool) -> float:
	cooldown = ACTION_COOLDOWN
	last_good = success
	attempts += 1
	if success:
		action_count += 1
	play_action_feedback(success)
	return 0.5 if success else 0.0

func play_action_feedback(success: bool = true) -> void:
	# Root may report the model result again; visual feedback never counts a hit.
	last_good = success
	flash = 1.0
	queue_redraw()

func _advance_target() -> void:
	_target_index = (_target_index + (1 if attempts % 2 == 0 else 3)) % 4
	_target_age = 0.0

func _next_case() -> void:
	_case_index += 1
	var sequence := ["right", "left", "left", "right", "left", "right", "right", "left"]
	court_answer = sequence[_case_index % sequence.size()]
	court_time_left = COURT_WINDOW
	court_active = true
	_verdict = ""

func _draw() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var monitor_frame := int(elapsed * 5.0) % 7
	draw_texture_rect_region(ORIGINAL_MONITOR, Rect2(Vector2.ZERO, size), Rect2(monitor_frame * 320, 0, 320, 180))
	var glass := _glass_rect()
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
		FX.draw(self, "impact", p, Vector2.ONE * 52, 1.0 - flash, Color(MINT, flash))
		_text("+1", p + Vector2(26, 3), 24, MINT)

func _shooter_target(index: int) -> Vector2:
	var lane := index % 4
	return Vector2(120 + lane * 176 + sin(elapsed * 1.3 + index * 1.8) * 23, 164 + sin(elapsed * 1.7 + index) * 33)

func _target_center(index: int) -> Vector2:
	return _shooter_target(index) + Vector2(0, -48)

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
		if target == _target_index:
			var center := _target_center(target)
			draw_circle(center, SHOT_RADIUS, Color(PINK, 0.10))
			draw_arc(center, SHOT_RADIUS, 0, TAU, 28, PINK, 3)
			draw_line(center + Vector2(-56, 0), center + Vector2(-32, 0), PINK, 3)
			draw_line(center + Vector2(32, 0), center + Vector2(56, 0), PINK, 3)
			draw_arc(center, SHOT_RADIUS + 7, -PI / 2, -PI / 2 + TAU * (1.0 - _target_age / 4.2), 28, Color(PINK, 0.4), 2)
	var player_at := Vector2(400 + sin(elapsed * 0.7) * 80, 299)
	_sprite(MAX_SPRITE, player_at, 1.9)
	if cooldown <= 0 and marker >= 0.4 and marker <= 0.6:
		draw_line(player_at + Vector2(12, -51), _target_center(_target_index), Color(MINT, 0.22), 2)
	if flash > 0:
		var target_at := _shot_position
		var muzzle := player_at + Vector2(12, -51)
		var shot_vector := target_at - muzzle
		FX.draw(self, "projectile", muzzle.lerp(target_at, 0.5), Vector2(shot_vector.length(), 26), 1.0 - flash, Color(MINT if last_good else PINK, flash), shot_vector.angle())
		if last_good:
			FX.draw(self, "impact", target_at, Vector2.ONE * 64, 1.0 - flash, Color("ffe099"))
	var mouse_at := get_local_mouse_position()
	var glass := _glass_rect()
	if glass.has_point(mouse_at) and not frozen:
		var cursor := (mouse_at - glass.position) * LOGICAL_SIZE / glass.size
		if cursor.y >= 36 and cursor.y < 307:
			draw_arc(cursor, 9, 0, TAU, 16, Color("fff0b8"), 2)
			draw_line(cursor - Vector2(15, 0), cursor + Vector2(15, 0), Color("fff0b8"), 1)
			draw_line(cursor - Vector2(0, 15), cursor + Vector2(0, 15), Color("fff0b8"), 1)
	_text("PLASTIC IV", Vector2(22, 289), 13, Color("adbbcf"))

func _draw_court() -> void:
	draw_rect(Rect2(0, 0, 800, 307), Color("514155"))
	for panel in 11:
		var x := 15.0 + panel * 73
		draw_rect(Rect2(x, 45, 62, 213), Color("6b5061"), false, 3)
	_text("GOOSE COURT", Vector2(22, 29), 17, Color("f3d8c4"))
	_text("CASES WON %d" % action_count, Vector2(603, 29), 17, MINT)
	# Read the evidence, then free the flower carrier or bonk the bread thief.
	var card_color := MINT if court_answer == "left" else Color("ffc780")
	draw_rect(Rect2(79, 51, 279, 119), Color("292c39"))
	draw_rect(Rect2(79, 51, 279, 119), card_color.darkened(0.3), false, 3)
	_text("EVIDENCE", Vector2(95, 74), 15, Color("dcc7ce"))
	_draw_evidence(Vector2(227, 116), court_answer == "right", 1.0)
	_text("FLOWER" if court_answer == "left" else "BREAD", Vector2(94, 152), 19, card_color)
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
	if flash > 0:
		_text(_verdict, Vector2(454, 66), 26, MINT if last_good else PINK)
	if flash > 0 and last_good:
		FX.draw(self, "slash", Vector2(658, 152), Vector2(94, 75), 1.0 - flash, Color(MINT, flash))

func _draw_evidence(at: Vector2, bread: bool, scale_factor: float) -> void:
	if bread:
		draw_rect(Rect2(at + Vector2(-41, -24) * scale_factor, Vector2(82, 48) * scale_factor), Color("b7784f"))
		draw_rect(Rect2(at + Vector2(-35, -29) * scale_factor, Vector2(70, 49) * scale_factor), Color("f2c581"))
		for slash in 3:
			var offset := Vector2(-21 + slash * 22, -16) * scale_factor
			draw_line(at + offset, at + offset + Vector2(-5, 25) * scale_factor, Color("d8975f"), 5 * scale_factor)
	else:
		draw_line(at + Vector2(0, 25) * scale_factor, at + Vector2(0, -9) * scale_factor, MINT, 6 * scale_factor)
		draw_line(at + Vector2(0, 14) * scale_factor, at + Vector2(-17, 5) * scale_factor, MINT, 5 * scale_factor)
		for petal in 6:
			var center := at + Vector2(cos(petal * TAU / 6), sin(petal * TAU / 6)) * 13 * scale_factor + Vector2(0, -12) * scale_factor
			draw_rect(Rect2(center - Vector2.ONE * 8 * scale_factor, Vector2.ONE * 16 * scale_factor), Color("efabd1"))
		draw_rect(Rect2(at + Vector2(-7, -19) * scale_factor, Vector2.ONE * 14 * scale_factor), Color("ffe5a0"))

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
	if game_id == "weird":
		var available := court_active and cooldown <= 0.0
		draw_rect(COURT_LEFT, Color("354b3f") if available else Color("29333b"))
		draw_rect(COURT_RIGHT, Color("61453e") if available else Color("29333b"))
		draw_rect(COURT_LEFT, MINT if available else Color("46534d"), false, 2)
		draw_rect(COURT_RIGHT, Color("ffc780") if available else Color("46534d"), false, 2)
		_draw_evidence(Vector2(75, 348), false, 0.45)
		_draw_evidence(Vector2(461, 348), true, 0.45)
		_text("A / FREE", Vector2(120, 356), 26, MINT if available else Color("8a9395"))
		_text("D / BONK", Vector2(504, 356), 26, Color("ffc780") if available else Color("8a9395"))
		if available:
			draw_rect(Rect2(37, 383, 726, 7), Color("3c4a4b"))
			draw_rect(Rect2(37, 383, 726 * court_time_left / COURT_WINDOW, 7), MINT if court_time_left > 0.8 else PINK)
	elif _is_ranked():
		_text("CLICK THE PINK TARGET", Vector2(37, 334), 21, Color("e6edce"))
		_text("SPACE ASSIST", Vector2(37, 368), 15, Color("b4c5ab"))
		_timing_lane(Rect2(219, 352, 544, 15), Vector2(0.4, 0.6))
		if flash > 0:
			_text(("ASSIST!" if _shot_assisted else "TAG!") if last_good else "MISS", Vector2(596, 334), 23, MINT if last_good else PINK)
	else:
		_text("SPACE / HARVEST", Vector2(37, 334), 20, Color("e6edce"))
		_text("GREEN = RIPE", Vector2(580, 333), 16, MINT)
		_timing_lane(Rect2(37, 349, 726, 16), COZY_ZONE)
		if flash > 0:
			_text("RIPE!" if last_good else "TOO SOON", Vector2(358, 333), 23, MINT if last_good else PINK)
	if cooldown > 0:
		draw_rect(Rect2(37, 385, 726 * minf(1.0, cooldown / ACTION_COOLDOWN), 4), Color("738b56"))

func _timing_lane(lane: Rect2, green: Vector2) -> void:
	draw_rect(lane, Color("3c4a4b"))
	draw_rect(Rect2(lane.position.x + lane.size.x * green.x, lane.position.y, lane.size.x * (green.y - green.x), lane.size.y), MINT)
	var mx := lane.position.x + marker * lane.size.x
	draw_line(Vector2(mx, lane.position.y - 6), Vector2(mx, lane.end.y + 7), Color("fff8dc"), 5)
