class_name ActionBar
extends Control
## The bottom-centre action bar in the references' style: a health orb
## (left) and a guard orb (right) in dark wrought-iron frames, four item
## slots between them flanked by Q/E key caps, a thin progress bar under
## the slots and number keys beneath. Pure drawing; the HUD feeds values.

const IRON := Color(0.11, 0.1, 0.1)
const IRON_HI := Color(0.46, 0.43, 0.4)
const IRON_MID := Color(0.24, 0.22, 0.21)

var health := 1.0
var health_text := ""
var guard := 1.0
var guard_text := ""
## 0..1 fill of the bar under the slots (ability readiness).
var progress := 1.0
## Per slot: {"glyph": String, "cooldown": 0..1, "ready": bool}
var slots: Array[Dictionary] = [{}, {}, {}, {}]
var font: Font

const ORB_R := 58.0
const SLOT := 56.0
const GAP := 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ORB_R * 4 + SLOT * 4 + GAP * 3 + 150, ORB_R * 2 + 30)
	font = load("res://art/fonts/Cinzel-Bold.woff2")


func _process(_delta: float) -> void:
	# Keep centred at the bottom of the screen whatever the window size.
	size = custom_minimum_size
	var vp := get_viewport_rect().size
	position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 4)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var cy := size.y - ORB_R - 8
	var strip_w := SLOT * 4 + GAP * 3
	var sx := (w - strip_w) * 0.5
	var sy := cy - SLOT * 0.5 - 10
	# Backing plate between the orbs.
	var plate := Rect2(sx - 44, sy - 14, strip_w + 88, SLOT + 50)
	# Dark iron plate: a vertical gradient, bevelled rim and rivets.
	var bands := 10
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(plate.position + Vector2(0, plate.size.y * t), Vector2(plate.size.x, plate.size.y / bands + 1)),
			Color(0.1, 0.095, 0.09, 0.9).lerp(Color(0.03, 0.03, 0.03, 0.92), t))
	draw_rect(plate, IRON_HI, false, 2.0)
	draw_rect(plate.grow(-4), Color(0.0, 0.0, 0.0, 0.6), false, 1.0)
	for cx: float in [plate.position.x + 8, plate.end.x - 8]:
		for cy2: float in [plate.position.y + 8, plate.end.y - 8]:
			draw_circle(Vector2(cx, cy2), 2.5, IRON_HI)
	# Filigree crest above the slots.
	var crest := Vector2(w * 0.5, sy - 12)
	for i in 5:
		var off := (i - 2) * 22.0
		draw_arc(crest + Vector2(off, 0), 10, PI, TAU, 12, IRON_MID, 3.0, true)
	draw_arc(crest, 16, PI, TAU, 16, IRON_HI, 2.0, true)
	# Slots.
	for i in 4:
		var r := Rect2(sx + i * (SLOT + GAP), sy, SLOT, SLOT)
		draw_rect(r, Color(0.05, 0.05, 0.06, 0.92))
		draw_rect(r.grow(-3), Color(0.12, 0.12, 0.13), false, 1.0)
		draw_rect(r, IRON_HI, false, 2.0)
		var s: Dictionary = slots[i] if i < slots.size() else {}
		if s.has("glyph"):
			_glyph(r, String(s.glyph), s.get("ready", true))
			var cd: float = s.get("cooldown", 0.0)
			if cd > 0.0:
				draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - cd)), Vector2(r.size.x, r.size.y * cd)), Color(0, 0, 0, 0.6))
		# Number caps under the slots (5..8 in the references; ours 1..4).
		_keycap(Vector2(r.get_center().x, sy + SLOT + 34), str(i + 1), 12)
	_keycap(Vector2(sx - 22, sy + SLOT * 0.5), "Q", 14)
	_keycap(Vector2(sx + strip_w + 22, sy + SLOT * 0.5), "E", 14)
	# Progress bar.
	var bar := Rect2(sx - 24, sy + SLOT + 8, strip_w + 48, 9)
	draw_rect(bar, Color(0.03, 0.03, 0.03, 0.9))
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * clampf(progress, 0, 1), bar.size.y - 4)), Color(0.22, 0.62, 0.2))
	draw_rect(bar, IRON_HI, false, 1.5)
	# Orbs.
	_orb(Vector2(sx - 44 - ORB_R - 18, cy), health, Color(0.62, 0.06, 0.05), Color(0.16, 0.01, 0.01), health_text)
	_orb(Vector2(sx + strip_w + 44 + ORB_R + 18, cy), guard, Color(0.14, 0.26, 0.66), Color(0.02, 0.04, 0.16), guard_text)


func _orb(c: Vector2, fill: float, col: Color, dark: Color, text: String) -> void:
	var r := ORB_R
	# Frame: heavy iron ring with filigree wings, a crest and claws.
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var base := c + Vector2(side * (r + 8), -r * 0.35 + k * r * 0.35)
			draw_arc(base + Vector2(side * 10, 0), 11 - k * 2, PI * 0.5 - side * PI * 0.5 - 1.2, PI * 0.5 - side * PI * 0.5 + 1.2, 12, IRON_MID, 4.0, true)
			draw_arc(base + Vector2(side * 10, 0), 11 - k * 2, PI * 0.5 - side * PI * 0.5 - 1.2, PI * 0.5 - side * PI * 0.5 + 1.2, 12, IRON_HI, 1.0, true)
	draw_circle(c, r + 12, IRON)
	draw_arc(c, r + 12, 0, TAU, 64, IRON_HI, 2.0, true)
	draw_arc(c, r + 7, 0, TAU, 64, Color(0.3, 0.27, 0.24), 1.0, true)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		draw_circle(c + Vector2(cos(a), sin(a)) * (r + 6), 2.2, IRON_HI)
	var top := c + Vector2(0, -r - 14)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-26, 10), top + Vector2(-12, -8), top + Vector2(0, -16), top + Vector2(12, -8), top + Vector2(26, 10)]), IRON)
	draw_polyline(PackedVector2Array([top + Vector2(-26, 10), top + Vector2(-12, -8), top + Vector2(0, -16), top + Vector2(12, -8), top + Vector2(26, 10)]), IRON_HI, 1.5)
	# Glass.
	draw_circle(c, r, Color(0.03, 0.03, 0.04))
	fill = clampf(fill, 0.0, 1.0)
	if fill > 0.0:
		var level := c.y + r - fill * 2.0 * r
		var pts := PackedVector2Array()
		var steps := 40
		# Liquid body: the chord at `level` and the circle below it.
		var half := sqrt(maxf(r * r - pow(level - c.y, 2.0), 0.0))
		var a0 := atan2(level - c.y, half)
		var a1 := atan2(level - c.y, -half)
		if a1 < a0:
			a1 += TAU
		for i in steps + 1:
			var a := lerpf(a0, a1, float(i) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if fill >= 0.999:
			pts = PackedVector2Array()
			for i in 64:
				var a := TAU * i / 64.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
		if pts.size() >= 3:
			var cols := PackedColorArray()
			for q in pts:
				var t := clampf((q.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)
				cols.append(col.lightened(0.25).lerp(dark, t))
			draw_polygon(pts, cols)
		# Swirl in the liquid.
		draw_arc(c + Vector2(r * 0.1, r * 0.25), r * 0.45, PI * 0.1, PI * 0.9, 16, Color(1, 1, 1, 0.08), 5.0, true)
	# Dark glass: the edge falls off into shadow, a hot specular glint and a
	# soft reflected rim at the bottom.
	for k in 7:
		draw_arc(c, r - 1.5 - k * 2.5, 0, TAU, 64, Color(0, 0, 0, 0.16 - k * 0.018), 3.0, true)
	draw_arc(c + Vector2(-r * 0.25, -r * 0.3), r * 0.55, PI * 1.05, PI * 1.55, 20, Color(1, 1, 1, 0.18), 6.0, true)
	draw_circle(c + Vector2(-r * 0.38, -r * 0.42), r * 0.1, Color(1, 1, 1, 0.55))
	draw_circle(c + Vector2(-r * 0.28, -r * 0.55), r * 0.05, Color(1, 1, 1, 0.4))
	draw_arc(c, r * 0.86, PI * 0.2, PI * 0.8, 24, Color(1, 1, 1, 0.07), 3.0, true)
	draw_arc(c, r, 0, TAU, 64, Color(0, 0, 0, 0.85), 3.0, true)
	if text != "":
		var fs := 18
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string_outline(font, c + Vector2(-tw * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		draw_string(font, c + Vector2(-tw * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.88))


func _keycap(c: Vector2, key: String, fs: int) -> void:
	var r := Rect2(c - Vector2(11, 11), Vector2(22, 22))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.92, 0.9)
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.2, 0.2, 0.2)
	draw_style_box(sb, r)
	var tw := font.get_string_size(key, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + fs * 0.36), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.08))


## Simple engraved icons for slot contents.
func _glyph(r: Rect2, glyph: String, ready: bool) -> void:
	var c := r.get_center()
	var col := Color(0.85, 0.82, 0.76) if ready else Color(0.45, 0.44, 0.42)
	match glyph:
		"sword":
			draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), col, 4.0)
			draw_line(c + Vector2(-16, 6), c + Vector2(-6, 16), col, 3.0)
			draw_line(c + Vector2(-20, 20), c + Vector2(-14, 14), Color(0.55, 0.35, 0.2), 4.0)
		"bow":
			draw_arc(c + Vector2(-6, 0), 18, -PI * 0.4, PI * 0.4, 16, col, 3.0)
			draw_line(c + Vector2(-6 + 18 * cos(PI * 0.4), -18 * sin(PI * 0.4)), c + Vector2(-6 + 18 * cos(PI * 0.4), 18 * sin(PI * 0.4)), col, 1.2)
			draw_line(c + Vector2(-14, 0), c + Vector2(16, 0), col, 2.0)
		"staff":
			draw_line(c + Vector2(-12, 18), c + Vector2(10, -12), Color(0.6, 0.42, 0.25), 4.0)
			draw_circle(c + Vector2(12, -15), 6, Color(0.4, 0.7, 1.0) if ready else col)
		"axe":
			draw_line(c + Vector2(-12, 18), c + Vector2(8, -14), Color(0.6, 0.42, 0.25), 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(4, -16), c + Vector2(18, -12), c + Vector2(14, 2), c + Vector2(6, -6)]), col)
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -16), c + Vector2(14, -16), c + Vector2(12, 4), c + Vector2(0, 18), c + Vector2(-12, 4)]), col)
			draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color(0.3, 0.1, 0.08), 3.0)
		"nova":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 6, c + Vector2(cos(a), sin(a)) * 18, col if not ready else Color(0.6, 0.85, 1.0), 2.5)
		"volley":
			for i in 3:
				draw_line(c + Vector2(-16, 10 - i * 10), c + Vector2(14, 2 - i * 10), col, 2.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(14, 2 - i * 10), c + Vector2(8, -2 - i * 10), c + Vector2(9, 5 - i * 10)]), col)
		_:
			if glyph != "":
				var fs := 22
				var tw := font.get_string_size(glyph.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
				draw_string(font, c + Vector2(-tw * 0.5, 8), glyph.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
