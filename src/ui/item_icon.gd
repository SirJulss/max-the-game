extends Control
## Tiny code-native item icons; original character, button and monitor art is retained.
var item_id := "keyboard"
const LIGHT := Color("e3e5d2")
const DARK := Color("252f33")
const GREEN := Color("80c83f")
const GOLD := Color("deb46a")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(0, 0, 64, 64), Color("242d29"))
	match item_id:
		"medkit", "vitality":
			box(12, 16, 40, 36, LIGHT)
			box(25, 22, 14, 25, Color("e66c67"))
			box(19, 28, 26, 12, Color("e66c67"))
		"banhammer":
			box(28, 20, 8, 36, GOLD)
			box(11, 10, 42, 23, Color("949ea3"))
			box(14, 12, 36, 4, LIGHT)
		"capslock":
			box(13, 22, 39, 18, Color("9eabd1"))
			box(17, 37, 12, 16, LIGHT)
			box(49, 26, 10, 10, DARK)
			box(23, 15, 10, 6, GREEN)
		"webcam", "clip_lab":
			box(9, 15, 46, 26, LIGHT)
			box(25, 20, 16, 16, DARK)
			box(30, 24, 7, 7, GREEN)
			box(27, 40, 10, 9, LIGHT)
			box(19, 49, 26, 5, LIGHT)
		"security":
			box(13, 21, 36, 16, LIGHT)
			box(48, 25, 11, 8, GREEN)
			box(28, 36, 9, 18, GOLD)
			box(17, 53, 30, 5, LIGHT)
		"armor", "thorns":
			box(15, 12, 34, 37, Color("9eabd1"))
			box(21, 49, 22, 7, Color("9eabd1"))
			box(27, 18, 10, 28, LIGHT)
			if item_id == "thorns":
				box(9, 19, 6, 8, GREEN)
				box(49, 31, 6, 8, GREEN)
		"coffee", "tip_jar", "protein":
			box(17, 17, 29, 37, LIGHT)
			box(22, 23, 19, 26, GOLD if item_id == "coffee" else GREEN)
			box(45, 25, 10, 18, LIGHT)
			box(46, 29, 5, 10, DARK)
			box(23, 8, 4, 6, LIGHT)
			box(34, 5, 4, 9, LIGHT)
		"sneakers":
			box(12, 25, 18, 23, GREEN)
			box(29, 38, 25, 15, GREEN)
			box(11, 51, 45, 6, LIGHT)
			box(16, 29, 12, 4, LIGHT)
		"fiber", "rage_drive":
			box(13, 14, 38, 40, LIGHT)
			box(18, 19, 28, 29, DARK)
			for i in 3:
				box(21 + i * 8, 37 - i * 7, 5, 8 + i * 7, GREEN)
		"vampire":
			box(10, 21, 44, 21, Color("b782b8"))
			box(16, 36, 8, 18, LIGHT)
			box(40, 36, 8, 18, LIGHT)
		"fan_club", "hater_bonds":
			box(19, 12, 26, 26, GOLD)
			box(28, 38, 8, 11, GOLD)
			box(18, 49, 28, 7, LIGHT)
			box(12, 16, 7, 18, GOLD)
			box(45, 16, 7, 18, GOLD)
		_:
			box(7, 21, 50, 29, LIGHT)
			for y in 3:
				for x in 6:
					box(11 + x * 7, 25 + y * 7, 4, 4, DARK)

func box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
