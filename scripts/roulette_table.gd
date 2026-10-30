extends Control
## Green felt betting table drawn in code. Tap a cell to drop the selected chip there.

signal bet_placed(bet: String)

const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const OUTSIDE := ["red", "black", "even", "odd"]

var bets := {} # bet -> amount
var highlight := -1 # winning number to flash, -1 = none
var flash := 0.0


## Layout: zero on the left, 12 columns x 3 rows of numbers, outside bets underneath.
func _cells() -> Dictionary:
	var out := {}
	var zero_w := size.x * 0.08
	var cw := (size.x - zero_w) / 12.0
	var grid_h := size.y * 0.72
	var ch := grid_h / 3.0
	out["0"] = Rect2(0, 0, zero_w, grid_h)
	for col in 12:
		for row in 3:
			var n := col * 3 + (3 - row) # top row is 3,6,9...
			out[str(n)] = Rect2(zero_w + col * cw, row * ch, cw, ch)
	var ow := (size.x - zero_w) / 4.0
	for i in 4:
		out[OUTSIDE[i]] = Rect2(zero_w + i * ow, grid_h, ow, size.y - grid_h)
	return out


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cells := _cells()
		for k in cells:
			if cells[k].has_point(event.position):
				bet_placed.emit(k)
				accept_event()
				return


func _process(delta: float) -> void:
	if highlight >= 0:
		flash += delta
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var felt := Color("#0f6b3a")
	draw_rect(Rect2(Vector2(-10, -10), size + Vector2(20, 20)), Color("#5a2e14"))
	draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color("#e8b923"))
	draw_rect(Rect2(Vector2.ZERO, size), felt)
	var cells := _cells()
	for k in cells:
		var r: Rect2 = cells[k]
		var inner := r.grow(-3)
		var fill := felt.lightened(0.06)
		var txt := ""
		match k:
			"red": fill = Color("#c8102e")
			"black": fill = Color("#1c1c24")
			"even": txt = tr("ROULETTE_EVEN_SHORT")
			"odd": txt = tr("ROULETTE_ODD_SHORT")
			_:
				var n := int(k)
				txt = k
				# Number badge colour like a real layout.
				var badge := Color("#1f8a4c") if n == 0 else (Color("#c8102e") if n in RED else Color("#1c1c24"))
				if n == highlight and fmod(flash, 0.5) < 0.25:
					badge = Color("#f7d774")
				draw_rect(r, felt)
				draw_circle(r.get_center(), minf(r.size.x, r.size.y) * 0.36, badge)
		if k in OUTSIDE:
			draw_rect(inner, fill if k in ["red", "black"] else felt)
			if k in ["red", "black"]: # diamond, like a real layout
				var cc := r.get_center()
				var d := r.size.y * 0.3
				draw_colored_polygon([cc + Vector2(0, -d), cc + Vector2(d * 1.6, 0), cc + Vector2(0, d), cc + Vector2(-d * 1.6, 0)], fill.lightened(0.25))
		draw_rect(r, Color("#d8e8d0", 0.7), false, 2)
		var fs := int(minf(r.size.y * 0.42, r.size.x * 0.42)) if not k in OUTSIDE else 26
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, r.get_center() + Vector2(-w / 2, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Chips on top.
	for k in bets:
		var r: Rect2 = cells[k]
		draw_chip(self, r.get_center() + Vector2(r.size.x * 0.18, -r.size.y * 0.18), minf(r.size.x, r.size.y) * 0.3, bets[k])


## Casino chip: rim, stripes, inner disc, value. Shared with the chip picker.
static func draw_chip(ci: CanvasItem, p: Vector2, radius: float, value: int) -> void:
	var col := Color("#1e6fd9")
	if value >= 100: col = Color("#1c1c24")
	elif value >= 50: col = Color("#8e2bd6")
	elif value >= 25: col = Color("#1f8a4c")
	elif value >= 10: col = Color("#c8102e")
	ci.draw_circle(p + Vector2(0, radius * 0.12), radius, Color(0, 0, 0, 0.4))
	ci.draw_circle(p, radius, col)
	for i in 6:
		var a := i * TAU / 6.0
		ci.draw_line(p + Vector2.from_angle(a) * radius * 0.72, p + Vector2.from_angle(a) * radius * 0.98, Color.WHITE, radius * 0.22)
	ci.draw_circle(p, radius * 0.62, col.lightened(0.15))
	ci.draw_arc(p, radius * 0.62, 0, TAU, 32, Color.WHITE, 2)
	var font := ThemeDB.get_default_theme().default_font
	var txt := str(value) if value < 1000 else "%dk" % (value / 1000)
	var fs := int(radius * 0.7)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(font, p + Vector2(-w / 2, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
