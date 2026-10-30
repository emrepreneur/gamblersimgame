extends Control
## European roulette wheel drawn in code. spin_to(n) animates wheel + ball and lands the ball on n.

signal landed

const ORDER := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1,
	20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const STEP := TAU / 37.0
const SPIN_TIME := 4.5

var wheel_angle := 0.0
var ball_angle := -PI / 2
var ball_r := 0.0 # set in _ready: on the outer track
var idle_spin := 0.25 # rad/s while waiting
var spinning := false
var tick: AudioStreamPlayer


func _r() -> float:
	return minf(size.x, size.y) * 0.5


static func pocket_color(n: int) -> Color:
	if n == 0:
		return Color("#1f8a4c")
	return Color("#c8102e") if n in RED else Color("#1c1c24")


func _process(delta: float) -> void:
	if ball_r == 0.0 and size.x > 0: # first frame with a real size: ball rests in a pocket
		ball_r = _r() * 0.6
	if not spinning:
		wheel_angle += idle_spin * delta
		if ball_r < _r() * 0.8: # ball sits in a pocket and turns with the wheel
			ball_angle += idle_spin * delta
	queue_redraw()


func spin_to(n: int) -> void:
	spinning = true
	var idx := ORDER.find(n)
	var w0 := wheel_angle
	var w1 := w0 + TAU * 2.0 + randf() * TAU
	# Ball ends over pocket idx (pocket centre = wheel_angle + idx*STEP), after ~5 turns the other way.
	var b1 := w1 + idx * STEP
	var b0 := b1 + TAU * 5.0 + fposmod(ball_angle - b1, TAU)
	ball_angle = b0
	ball_r = _r() * 0.86
	var t := create_tween().set_parallel()
	t.tween_property(self, "wheel_angle", w1, SPIN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "ball_angle", b1, SPIN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Ball rolls on the track, then drops and bounces into the pocket ring.
	t.tween_property(self, "ball_r", _r() * 0.6, 0.6).set_delay(SPIN_TIME * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await t.finished
	spinning = false
	landed.emit()


func _draw() -> void:
	var c := size / 2.0
	var r := _r()
	var font := get_theme_default_font()

	# Wooden bowl and gold rim.
	draw_circle(c + Vector2(0, 10), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color("#5a2e14"))
	draw_circle(c, r * 0.95, Color("#7a4320"))
	draw_arc(c, r * 0.95, 0, TAU, 96, Color("#e8b923"), 4)
	# Ball track.
	draw_circle(c, r * 0.9, Color("#3b2210"))
	draw_circle(c, r * 0.8, Color("#c9a86a"))

	# Pockets: number ring (outer) and pocket floor (inner).
	for i in 37:
		var a0 := wheel_angle + (i - 0.5) * STEP
		var a1 := a0 + STEP
		var col := pocket_color(ORDER[i])
		_sector(c, r * 0.62, r * 0.79, a0, a1, col)
		_sector(c, r * 0.5, r * 0.62, a0, a1, col.darkened(0.35))
		draw_line(c + Vector2.from_angle(a0) * r * 0.5, c + Vector2.from_angle(a0) * r * 0.79, Color("#e8b923"), 2)
		# Number, rotated to read from outside in.
		var mid := a0 + STEP / 2
		draw_set_transform(c + Vector2.from_angle(mid) * r * 0.705, mid + PI / 2)
		var txt := str(ORDER[i])
		var fs := int(r * 0.07)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, Vector2(-w / 2, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO)

	# Cone and turret.
	draw_circle(c, r * 0.5, Color("#6b3a1c"))
	draw_circle(c, r * 0.38, Color("#8a5229"))
	draw_circle(c, r * 0.2, Color("#a86a36"))
	for k in 4:
		var a := wheel_angle * 1.0 + k * PI / 2
		draw_line(c, c + Vector2.from_angle(a) * r * 0.3, Color("#e8b923"), r * 0.04)
		draw_circle(c + Vector2.from_angle(a) * r * 0.3, r * 0.035, Color("#f7d774"))
	draw_circle(c, r * 0.08, Color("#f7d774"))
	draw_circle(c, r * 0.04, Color("#fff3c4"))

	# Ball with a little shadow and highlight.
	var bp := c + Vector2.from_angle(ball_angle) * ball_r
	draw_circle(bp + Vector2(2, 3), r * 0.035, Color(0, 0, 0, 0.35))
	draw_circle(bp, r * 0.035, Color("#f4f4f4"))
	draw_circle(bp + Vector2(-r * 0.01, -r * 0.01), r * 0.012, Color.WHITE)


func _sector(c: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 5:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 4.0)) * r1)
	for k in 5:
		pts.append(c + Vector2.from_angle(lerpf(a1, a0, k / 4.0)) * r0)
	draw_colored_polygon(pts, col)
