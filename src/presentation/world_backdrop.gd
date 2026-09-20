extends Node2D
## Original sprites and street art in a geometric suburb, lit by imported
## Pixel Composer effects. Runtime code only positions and plays their frames.

const FX := preload("res://src/presentation/pixel_fx.gd")
const INK := Color("101322")
const DEEP := Color("151a2e")
const VIOLET := Color("8c6cf4")
const CYAN := Color("6ee9dd")
const GOLD := Color("ffcf84")
const MAX_SPRITE := preload("res://Assets/Player/Idle/MaxIdle.png")
const ORIGINAL_MONITOR := preload("res://Assets/Gameplay/Streaming/Pc/PCOverlay.png")
const ORIGINAL_STREET := preload("res://Assets/test/streat.jpg")

var mode := "title"
var day := 1
var equipment := 0
var door_alert := false
var _clock := 0.0
var _font: Font


func _ready() -> void:
	z_index = -50
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func set_mode(next_mode: String, next_day: int = 1, next_equipment: int = 0) -> void:
	mode = next_mode
	day = next_day
	equipment = next_equipment
	queue_redraw()


func set_door_alert(active: bool) -> void:
	door_alert = active
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	_sky()
	match mode:
		"yard": _yard()
		"title": _title_studio()
		"apartment": _apartment()
		_: _studio()


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _line(a: Vector2, b: Vector2, color: Color, width: float = 2.0) -> void:
	draw_line(a, b, color, width, false)


func _label(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _sky() -> void:
	_box(0, 0, 1280, 720, INK)
	for band in 18:
		_box(0, band * 40, 1280, 40, Color("191a32").lerp(INK, float(band) / 18.0))
	for star in 44:
		var x := float((star * 137 + 43) % 1260)
		var y := float((star * 61 + 31) % 247)
		FX.draw(self, "halo", Vector2(x + 1, y + 1), Vector2.ONE * 3, fmod(_clock * 0.09 + star * 0.137, 1.0), Color(0.72, 0.77, 0.98, 0.4))
	# Distant, very ordinary buildings. The internet is considerably less ordinary.
	for block in 16:
		var height := float(45 + (block * 31) % 90)
		var x := float(block * 88 - 25)
		_box(x, 285 - height, 70, height, Color("171e31"))
		_box(x + 6, 277 - height, 58, 8, Color("1e263b"))
		for window in 3:
			if (block + window) % 3 != 0:
				_box(x + 12 + window * 18, 305 - height, 7, 10, Color("3e3747"))
	# Soft moon, kept out of UI reading lanes.
	FX.draw(self, "halo", Vector2(1120, 150), Vector2.ONE * 66, fmod(_clock * 0.06, 1.0), Color(0.50, 0.58, 0.85, 0.09))
	draw_circle(Vector2(1120, 150), 24, Color("717799"))
	draw_circle(Vector2(1129, 142), 22, Color("1b1c33"))


func _title_studio() -> void:
	# A diorama fills the left half; title and menu remain on the right.
	_box(58, 146, 553, 474, Color("090f1c"))
	_box(72, 154, 525, 402, Color("292640"))
	_box(72, 154, 525, 10, Color("655277"))
	_box(72, 164, 12, 392, Color("3a304d"))
	_box(585, 164, 12, 392, Color("3a304d"))
	for x in range(96, 588, 42):
		_box(x, 172, 2, 365, Color("302941"))
	_box(83, 481, 502, 77, Color("403344"))
	for y in range(494, 557, 18):
		_line(Vector2(83, y), Vector2(585, y), Color("503c4b"))
	for x in range(90, 585, 74):
		_line(Vector2(x, 483), Vector2(x + 25, 558), Color("382f40"))
	_box(73, 559, 524, 24, Color("1d2036"))
	_box(89, 583, 492, 9, Color("111729"))
	# Neon LIVE sign and warm window give the room its two light sources.
	_neon_sign(Vector2(111, 190), "MAX // LIVE", 211)
	_window(Vector2(432, 190), Vector2(108, 135), false)
	_box(109, 256, 133, 108, Color("161c30"))
	_box(115, 262, 121, 96, Color("312e48"))
	_label("TOP 0.001%", Vector2(128, 285), 14, GOLD)
	_label("OF MY", Vector2(146, 309), 14, Color("aaa1b7"))
	_label("HOUSEHOLD", Vector2(127, 335), 14, Color("aaa1b7"))
	# A plant, questionable drink and a desk made of determination.
	_plant(Vector2(124, 488), 1.0)
	_box(258, 471, 207, 26, Color("182037"))
	_box(252, 468, 219, 8, VIOLET.darkened(0.25))
	_box(280, 477, 18, 56, Color("202337"))
	_box(437, 477, 18, 56, Color("202337"))
	_desk(Vector2(236, 412), 291, 1, true)
	# Existing Max pixels, presented as the hero rather than discarded.
	FX.draw(self, "shadow", Vector2(323, 465), Vector2(96, 33), 0.0, Color(0.02, 0.04, 0.08, 0.55))
	var frame := int(_clock * 2.0) % 2
	draw_texture_rect_region(MAX_SPRITE, Rect2(240, 307, 96, 192), Rect2(frame * 32, 0, 32, 64))
	# Exposed edges and cable provide depth without turning the scene into clutter.
	_line(Vector2(497, 421), Vector2(497, 479), Color("11182a"), 5)
	_line(Vector2(497, 479), Vector2(545, 479), Color("11182a"), 5)
	_box(536, 460, 24, 33, Color("141c2d"))
	for led in 3:
		_box(541 + led * 6, 467, 3, 3, CYAN if led == int(_clock) % 3 else CYAN.darkened(0.65))
	_box(103, 602, 450, 34, Color("192238"))
	_label("PLEASE DO NOT FEED THE COMMENTS", Vector2(117, 625), 17, Color("b1a9c8"))
	# Small ambient motes above the room.
	for mote in 7:
		var p := Vector2(113 + mote * 66, 141 + sin(_clock * 0.5 + mote) * 6)
		FX.draw(self, "halo", p, Vector2.ONE * 6, fmod(_clock * 0.14 + mote * 0.17, 1.0), Color(0.58, 0.45, 0.94, 0.3))


func _studio() -> void:
	_box(0, 112, 1280, 497, Color("242339"))
	for x in range(16, 1280, 42):
		_box(x, 112, 2, 487, Color("29263e"))
	_box(0, 605, 1280, 115, Color("2e283b"))
	for y in range(608, 721, 24):
		_line(Vector2(0, y), Vector2(1280, y), Color("3b3044"))
	for x in range(12, 1280, 101):
		_line(Vector2(x, 609), Vector2(x + 25, 720), Color("262339"))
	# Neon corners remain visible around the game interface.
	_line(Vector2(34, 129), Vector2(34, 594), VIOLET.darkened(0.65), 4)
	_line(Vector2(34, 129), Vector2(896, 129), VIOLET.darkened(0.65), 4)
	_line(Vector2(893, 129), Vector2(893, 594), VIOLET.darkened(0.65), 4)
	_line(Vector2(912, 129), Vector2(1247, 129), CYAN.darkened(0.65), 4)
	_line(Vector2(1247, 129), Vector2(1247, 594), CYAN.darkened(0.65), 4)
	_plant(Vector2(33, 624), 0.7)
	_plant(Vector2(1247, 624), 0.7)
	# Floor cables and upgrade racks frame the stream overlay.
	_line(Vector2(50, 632), Vector2(873, 632), Color("151b2e"), 5)
	_line(Vector2(873, 632), Vector2(904, 612), Color("151b2e"), 5)
	for rack in mini(equipment + 1, 7):
		var x := float(968 + rack * 34)
		_box(x, 610, 25, 29, Color("111a2c"))
		_box(x + 4, 615, 3, 3, CYAN)
		_box(x + 4, 622, 17, 2, Color("364055"))
		_box(x + 4, 628, 17, 2, Color("364055"))
	# Gentle screen glow on the floor, low contrast for readability.
	FX.draw(self, "halo", Vector2(458, 613), Vector2(750, 26), fmod(_clock * 0.12, 1.0), Color(0.51, 0.39, 0.93, 0.18))


func _apartment() -> void:
	# A walkable morning room. The desk sits above the play area, not behind a menu.
	_box(0, 0, 1280, 720, Color("292b3c"))
	_box(93, 104, 1110, 207, Color("4a4056"))
	_box(93, 104, 1110, 9, Color("756072"))
	for x in range(111, 1200, 40):
		_box(x, 114, 2, 191, Color("504359"))
	_box(105, 307, 1090, 319, Color("67515b"))
	for y in range(310, 630, 32):
		_line(Vector2(107, y), Vector2(1194, y), Color("765c63"), 2)
	for row in 10:
		for column in 9:
			var x := 111 + column * 128 + (64 if row % 2 else 0)
			if x < 1194:
				_line(Vector2(x, 310 + row * 32), Vector2(x, 341 + row * 32), Color("594753"))
	_box(93, 305, 1110, 8, Color("302c40"))
	_box(93, 104, 12, 530, Color("272a3b"))
	_box(1194, 104, 12, 530, Color("272a3b"))
	_box(94, 626, 1110, 10, Color("2b2a3b"))
	# The original town artwork is the actual view outside the morning window.
	_box(782, 131, 244, 159, Color("252b3b"))
	draw_texture_rect_region(ORIGINAL_STREET, Rect2(790, 139, 228, 138), Rect2(1100, 400, 228, 138))
	_box(790, 139, 228, 138, Color(1.0, 0.80, 0.45, 0.24))
	draw_circle(Vector2(975, 164), 20, Color("ffe1a3"))
	_box(899, 137, 8, 143, Color("756378"))
	_box(788, 202, 232, 7, Color("756378"))
	_box(776, 279, 257, 12, Color("a38487"))
	_box(778, 129, 24, 148, Color("82657e"))
	_box(1008, 129, 24, 148, Color("82657e"))
	FX.draw(self, "halo", Vector2(964, 457), Vector2(260, 350), fmod(_clock * 0.07, 1.0), Color(1.0, 0.84, 0.54, 0.14), -0.35)
	# Max's own monitor artwork, with the tiny setup growing as the run develops.
	_neon_sign(Vector2(159, 130), "MAX // LIVE", 211)
	_desk(Vector2(153, 285), 338, equipment, true)
	_box(211, 354, 213, 15, Color("403a4e"))
	_box(242, 356, 15, 25, Color("383448"))
	_box(380, 356, 15, 25, Color("383448"))
	_box(242, 338, 150, 9, Color("4c5261"))
	# Simple furniture belongs to the room, with no needs or maintenance meters.
	_box(538, 155, 157, 99, Color("2a2c3e"))
	_box(544, 161, 145, 87, Color("63516c"))
	_label("WORLD'S OKAYEST", Vector2(553, 185), 13, GOLD)
	_label("STREAMER", Vector2(567, 212), 17, Color("f1d5c5"))
	_label("EST. YESTERDAY", Vector2(562, 237), 12, Color("c8aeba"))
	_box(565, 273, 167, 35, Color("65577b"))
	_box(576, 261, 144, 29, Color("8a7596"))
	_box(566, 274, 14, 43, Color("736284"))
	_box(718, 274, 14, 43, Color("736284"))
	_box(584, 292, 125, 19, Color("95819b"))
	_box(581, 311, 8, 8, Color("3e3448"))
	_box(708, 311, 8, 8, Color("3e3448"))
	_plant(Vector2(116, 301), 0.85)
	_plant(Vector2(1037, 312), 0.9)
	# The room's real exit is at the right, where Max can walk to it after shopping.
	_box(1061, 335, 122, 151, Color("252b3b"))
	_box(1070, 340, 102, 140, Color("8a6b69"))
	_box(1078, 350, 84, 53, Color("795d64"))
	_box(1078, 417, 84, 53, Color("795d64"))
	_box(1078, 406, 8, 9, Color("ffd196"))
	_box(1044, 480, 148, 8, Color("a17c76"))
	_label("OUTSIDE", Vector2(1087, 327), 15, Color("e9c9b0"))
	for tower in mini(equipment / 2, 4):
		_box(446 + tower * 26, 315, 21, 40, Color("272b3d"))
		_box(451 + tower * 26, 322, 3, 3, CYAN)
		_box(451 + tower * 26, 331, 11, 2, Color("66707f"))
	# A soft rug marks the initial spawn without imposing any obstacle.
	_box(627, 442, 295, 115, Color(0.34, 0.28, 0.39, 0.32))
	_box(633, 448, 283, 103, Color(0.44, 0.34, 0.44, 0.22))


func _yard() -> void:
	# House above the arena; windows keep the fight grounded in Max's home.
	# The player's original pixel-art street surrounds the fenced front yard.
	draw_texture_rect_region(ORIGINAL_STREET, Rect2(0, 157, 1280, 563), Rect2(0, 210, 1344, 591))
	# A narrow nighttime tint keeps the brighter sidewalk from competing with attacks.
	_box(0, 157, 1280, 563, Color(0.06, 0.08, 0.16, 0.24))
	_box(190, 153, 900, 137, Color("171e31"))
	_house()
	_box(84, 290, 1112, 358, Color("202e35"))
	_box(102, 300, 1076, 332, Color("263941"))
	for row in 6:
		for column in 18:
			if (row + column) % 2 == 0:
				_box(102 + column * 60, 300 + row * 55, 60, 55, Color(0.14, 0.20, 0.24, 0.27))
	# Broad paving is intentionally flat: enemies and attack telegraphs read over it.
	_box(568, 290, 144, 349, Color("35414a"))
	for tile in range(300, 640, 38):
		_line(Vector2(573, tile), Vector2(706, tile), Color("3e4b54"))
	for tile in 9:
		var offset := 0 if tile % 2 == 0 else 31
		_line(Vector2(604 + offset, 301 + tile * 38), Vector2(604 + offset, 335 + tile * 38), Color("3e4b54"))
	# Scatter is deterministic, sparse and darker than all combat silhouettes.
	for tuft in 105:
		var x := float(118 + (tuft * 79) % 1040)
		var y := float(310 + (tuft * 47) % 312)
		if x > 548 and x < 730:
			continue
		var grass := Color("30444a") if tuft % 3 == 0 else Color("2a3d43")
		_line(Vector2(x, y), Vector2(x + 2, y - 4), grass)
		_line(Vector2(x + 3, y), Vector2(x + 6, y - 2), grass)
	# Fences show the play boundary without blocking movement or obscuring enemies.
	_fence_side(83)
	_fence_side(1193)
	_fence_bottom()
	_lamp(Vector2(97, 290))
	_lamp(Vector2(1183, 290))
	_mailbox(Vector2(46, 456))
	_box(1223, 511, 35, 45, Color("1c2936"))
	_box(1220, 506, 41, 8, Color("3d4958"))
	_label("L", Vector2(1233, 539), 14, Color("657385"))
	# The badge is world signage, away from the moving actors.
	_box(883, 244, 264, 32, Color("202638"))
	_box(884, 245, 3, 29, VIOLET)
	_label("PLEASE TOUCH GRASS", Vector2(902, 266), 16, Color("b8accc"))
	if day >= 4:
		_box(145, 249, 225, 25, Color("202638"))
		_label("MODERATED WITH FORCE", Vector2(155, 267), 13, Color("97aaa9"))
	if door_alert:
		var pulse := 0.45 + 0.3 * sin(_clock * 8.0)
		FX.draw(self, "slash", Vector2(640, 250), Vector2.ONE * 86, fmod(_clock * 1.6, 1.0), Color(1.0, 0.81, 0.52, pulse), -PI * 0.5)
		_label("KNOCK KNOCK", Vector2(579, 171), 16, GOLD)
	# HUD text remains legible while the original street is still visible beneath it.
	_box(0, 648, 1280, 72, Color(0.04, 0.07, 0.12, 0.48))


func _house() -> void:
	_box(403, 146, 474, 142, Color("111929"))
	_box(420, 147, 440, 132, Color("40354d"))
	for y in range(158, 279, 16):
		_line(Vector2(420, y), Vector2(860, y), Color("493b54"))
	var roof := PackedVector2Array([Vector2(385, 153), Vector2(445, 106), Vector2(835, 106), Vector2(895, 153)])
	draw_colored_polygon(roof, Color("262b43"))
	_line(Vector2(384, 154), Vector2(896, 154), VIOLET.darkened(0.6), 5)
	for shingle in range(442, 845, 38):
		_line(Vector2(shingle, 117), Vector2(shingle + 12, 142), Color("30344d"))
	_box(765, 98, 36, 35, Color("343349"))
	_box(760, 96, 45, 8, Color("4b4260"))
	_window(Vector2(457, 179), Vector2(101, 76), true)
	_window(Vector2(723, 179), Vector2(101, 76), true)
	_box(603, 179, 74, 100, Color("171f31"))
	_box(610, 184, 60, 95, Color("64506a"))
	_box(615, 189, 50, 37, Color("2d2a41"))
	_box(619, 193, 42, 28, Color("3d3a56"))
	_box(615, 233, 50, 40, Color("4e3c58"))
	_box(658, 231, 5, 8, GOLD)
	_box(591, 277, 97, 8, Color("6a5869"))
	_box(583, 285, 113, 7, Color("423d50"))
	_label("404", Vector2(580, 202), 12, GOLD)
	_box(542, 262, 23, 14, Color("244240"))
	_box(719, 262, 23, 14, Color("244240"))
	for leaf in 5:
		_box(536 + leaf * 5, 258 - (leaf % 2) * 5, 10, 8, Color("42685b"))
		_box(713 + leaf * 5, 258 - ((leaf + 1) % 2) * 5, 10, 8, Color("42685b"))
	# Equipment physically grows a ridiculous rooftop antenna array.
	if equipment >= 2:
		_line(Vector2(547, 111), Vector2(547, 91), Color("9c89bc"), 3)
		_line(Vector2(535, 93), Vector2(559, 93), CYAN.darkened(0.3), 3)
	if equipment >= 4:
		_line(Vector2(579, 110), Vector2(579, 86), Color("9c89bc"), 3)
		_box(567, 85, 24, 8, Color("6b5c8b"))
		_box(575, 88, 7, 3, CYAN)


func _window(at: Vector2, size: Vector2, warm: bool) -> void:
	var light := GOLD if warm else Color("655ea0")
	draw_rect(Rect2(at - Vector2(5, 5), size + Vector2(10, 10)), Color("171d30"))
	draw_rect(Rect2(at, size), light.darkened(0.23))
	draw_rect(Rect2(at + Vector2(5, 5), size - Vector2(10, 10)), light.darkened(0.1))
	if not warm:
		for building in 4:
			_box(at.x + 6 + building * 23, at.y + 62 - building * 7, 18, size.y - 67 + building * 7, Color("313453"))
	_box(at.x + size.x * 0.5 - 3, at.y, 6, size.y, Color("353448"))
	_box(at.x, at.y + size.y * 0.5 - 3, size.x, 6, Color("353448"))
	_box(at.x - 9, at.y + size.y, size.x + 18, 7, Color("6c5870"))
	_box(at.x - 3, at.y - 2, 13, size.y + 2, Color("4e405d"))
	_box(at.x + size.x - 10, at.y - 2, 13, size.y + 2, Color("4e405d"))


func _neon_sign(at: Vector2, text: String, width: float) -> void:
	FX.draw(self, "halo", at + Vector2(width * 0.5, 19), Vector2(width + 40, 78), fmod(_clock * 0.14, 1.0), Color(0.56, 0.40, 0.98, 0.18))
	draw_rect(Rect2(at, Vector2(width, 38)), Color("151d30"))
	draw_rect(Rect2(at, Vector2(width, 38)), Color("7354b0"), false, 2)
	_label(text, at + Vector2(13, 27), 23, Color("d0a9ff"))
	draw_circle(at + Vector2(width - 19, 19), 4, Color("ff708e"))


func _desk(at: Vector2, width: float, level: int, hero: bool = false) -> void:
	_box(at.x, at.y, width, 14, Color("826077"))
	_box(at.x, at.y + 14, width, 7, Color("4b3c52"))
	_box(at.x + 13, at.y + 21, 12, 65, Color("2b2a3e"))
	_box(at.x + width - 25, at.y + 21, 12, 65, Color("2b2a3e"))
	var monitor_x := at.x + (107 if hero else 18)
	var frame := int(_clock * 5.0) % 7
	draw_texture_rect_region(ORIGINAL_MONITOR, Rect2(monitor_x - 8, at.y - 110, 160, 90), Rect2(frame * 320, 0, 320, 180))
	_box(monitor_x + 2, at.y - 101, 140, 68, Color("2c354e"))
	_box(monitor_x + 89, at.y - 99, 50, 62, Color("30344c"))
	for line in 6:
		_box(monitor_x + 96, at.y - 92 + line * 8, 29 + line % 3 * 3, 2, CYAN.darkened(0.2 + line * 0.07))
	# Chart animates to imply a live broadcast in the little room.
	for bar in 9:
		var height := 7.0 + (sin(_clock * 1.1 + bar * 0.6) + 1.0) * 13.0
		_box(monitor_x + 15 + bar * 7, at.y - 45 - height, 4, height, VIOLET)
	_box(monitor_x + 57, at.y - 20, 18, 16, Color("20283c"))
	_box(monitor_x + 43, at.y - 5, 46, 5, Color("4e526a"))
	_box(monitor_x + 50, at.y - 119, 24, 10, Color("111b2b"))
	_box(monitor_x + 59, at.y - 116, 5, 4, CYAN)
	# Microphone boom and hot mug.
	_line(Vector2(at.x + width - 18, at.y), Vector2(at.x + width - 18, at.y - 42), Color("182333"), 4)
	_line(Vector2(at.x + width - 18, at.y - 42), Vector2(at.x + width - 54, at.y - 59), Color("182333"), 4)
	_box(at.x + width - 63, at.y - 68, 13, 23, Color("828da1"))
	_box(at.x + width - 61, at.y - 65, 9, 9, Color("3b475d"))
	_box(at.x + 19, at.y - 18, 16, 18, Color("df9a91"))
	_box(at.x + 35, at.y - 14, 5, 10, Color("b57881"))
	if level >= 3:
		_box(at.x + width + 8, at.y - 40, 26, 40, Color("1b2239"))
		draw_circle(Vector2(at.x + width + 21, at.y - 22), 8, VIOLET)


func _plant(at: Vector2, scale_factor: float) -> void:
	draw_set_transform(at, 0, Vector2.ONE * scale_factor)
	_box(-14, -23, 28, 24, Color("76516a"))
	_box(-18, -26, 36, 7, Color("a2788a"))
	_line(Vector2(0, -26), Vector2(0, -77), Color("3e846b"), 5)
	for leaf in 5:
		var left := -1.0 if leaf % 2 == 0 else 1.0
		var y := -37.0 - leaf * 8.0
		var polygon := PackedVector2Array([Vector2(0, y + 7), Vector2(left * 22, y - 9), Vector2(left * 23, y + 1), Vector2(0, y + 13)])
		draw_colored_polygon(polygon, Color("4d9376") if leaf % 2 == 0 else Color("376758"))
	draw_set_transform(Vector2.ZERO)


func _fence_side(x: float) -> void:
	_box(x - 4, 291, 8, 354, Color("1a2632"))
	for y in range(302, 650, 29):
		_box(x - 8, y, 17, 9, Color("394453"))
		_box(x - 8, y, 17, 3, Color("4a5463"))


func _fence_bottom() -> void:
	_box(85, 641, 1110, 5, Color("161f2f"))
	for x in range(96, 1196, 26):
		_box(x, 636, 8, 15, Color("3d4756"))
		_box(x, 636, 8, 3, Color("59606f"))


func _lamp(at: Vector2) -> void:
	FX.draw(self, "halo", at + Vector2(0, -44), Vector2.ONE * 78, fmod(_clock * 0.11 + at.x * 0.001, 1.0), Color(1.0, 0.78, 0.43, 0.18))
	_box(at.x - 3, at.y - 35, 6, 41, Color("343848"))
	_box(at.x - 11, at.y - 55, 22, 22, Color("20293b"))
	_box(at.x - 7, at.y - 51, 14, 14, GOLD)
	_box(at.x - 13, at.y - 58, 26, 5, Color("596079"))


func _mailbox(at: Vector2) -> void:
	_box(at.x - 3, at.y, 6, 42, Color("68515f"))
	_box(at.x - 18, at.y - 23, 39, 29, Color("4a516b"))
	_box(at.x - 18, at.y - 23, 39, 6, Color("6e6484"))
	_box(at.x - 12, at.y - 12, 14, 3, Color("151f31"))
	_box(at.x + 15, at.y - 25, 4, 15, Color("f27d93"))
	_box(at.x + 15, at.y - 25, 13, 6, Color("f27d93"))
