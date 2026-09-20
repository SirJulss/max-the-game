extends RefCounted
## Playback only. Every effect pixel comes from Pixel Composer exports.
## A 128px cell contains a 96px nominal footprint plus a 16px glow margin.
## Textured vertices preserve the caller's existing canvas/monitor transform.

const DIRECTORY := "res://Assets/FX/PixelComposer/"
const CELL_SIZE := 128
const FOOTPRINT := 96.0
const KINDS := ["ring", "disc", "swipe", "charge", "crosshair", "impact", "slash", "projectile", "jet_flame", "puddle", "bottle", "shadow", "halo"]
static var glow_enabled := true
static var _textures: Dictionary = {}

static func texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var path := DIRECTORY + kind + ".png"
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path) as Texture2D
	if resource:
		_textures[kind] = resource
	return resource

static func draw(canvas: CanvasItem, kind: String, at: Vector2, extent: Vector2, progress: float = 0.0, color: Color = Color.WHITE, rotation: float = 0.0) -> void:
	if color.a <= 0.0 or extent.x <= 0.0 or extent.y <= 0.0:
		return
	var sheet: Texture2D
	# These already contain an authored soft falloff. Adding a second Glow
	# flattens their alpha and makes large ambient lights look like solid discs.
	if glow_enabled and kind not in ["halo", "shadow"]:
		sheet = texture(kind + "_glow")
	if not sheet:
		sheet = texture(kind)
	if not sheet:
		return
	var frame_count := maxi(1, sheet.get_width() / CELL_SIZE)
	var frame := mini(frame_count - 1, int(clampf(progress, 0.0, 1.0) * frame_count))
	var half := extent * (float(CELL_SIZE) / FOOTPRINT) * 0.5
	var corners := PackedVector2Array([
		at + Vector2(-half.x, -half.y).rotated(rotation),
		at + Vector2(half.x, -half.y).rotated(rotation),
		at + Vector2(half.x, half.y).rotated(rotation),
		at + Vector2(-half.x, half.y).rotated(rotation)])
	var left := float(frame * CELL_SIZE) / sheet.get_width()
	var right := float((frame + 1) * CELL_SIZE) / sheet.get_width()
	var uv := PackedVector2Array([Vector2(left, 0), Vector2(right, 0), Vector2(right, 1), Vector2(left, 1)])
	canvas.draw_polygon(corners, PackedColorArray([color]), uv, sheet)
