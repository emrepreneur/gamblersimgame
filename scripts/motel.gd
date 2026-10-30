extends Control
## Larry's motel room, drawn in code. Every item he still owns is in the room; sold ones leave a
## dusty outline, and the ones Vinnie's people took leave a sticky note: "Thanks. V."

var room: Control
var log_label: Label
var t := 0.0

# Where each item lives in the room (room space 720 x 860): used for the dust outline when it's gone.
const SPOTS := {
	"ITEM_IRON": Rect2(180, 700, 220, 70),
	"ITEM_MICROWAVE": Rect2(80, 268, 130, 78),
	"ITEM_GUITAR": Rect2(412, 360, 62, 230),
	"ITEM_TV": Rect2(470, 420, 210, 130),
	"ITEM_WATCH": Rect2(356, 548, 40, 30),
	"ITEM_CAR": Rect2(440, 205, 190, 80),
	"ITEM_BLAZER": Rect2(236, 120, 70, 120),
	"ITEM_SUIT": Rect2(312, 120, 70, 140),
}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1b1420")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	room = Control.new()
	room.custom_minimum_size = Vector2(720, 860)
	room.clip_contents = true
	room.draw.connect(_draw_room)
	box.add_child(room)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var inner := VBoxContainer.new()
	panel.add_child(inner)
	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("font_size", 24)
	inner.add_child(log_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	if Game.is_over():
		Game.make_button(row, tr("BTN_RESTART"), func():
			Game.new_game(); Game.larry_pos = Vector2.ZERO; Game.go("world")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		Game.make_button(row, tr("BTN_SLEEP"), _sleep).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Game.make_button(row, tr("BTN_BACK_SHORT"), Game.go.bind("world")).custom_minimum_size.x = 160
	_refresh()


func _refresh() -> void:
	var e: Dictionary = Game.log[-1]
	log_label.text = Game.stats_text() + "\n" + Game.entry_text(e)
	room.queue_redraw()


func _sleep() -> void:
	# Lights out, then morning.
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.5)
	await tw.finished
	Game.record(Game.state.sleep())
	if Game.state.collection_due() or Game.is_over():
		Game.go("world" if not Game.is_over() else "motel") # Joey is waiting outside
		return
	_refresh()
	tw = create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	await tw.finished
	fade.queue_free()


func _process(delta: float) -> void:
	t += delta
	room.queue_redraw()


func _has(key: String) -> bool:
	return key in Game.state.owned


# --- Drawing --------------------------------------------------------------

func _draw_room() -> void:
	var r := room
	var s = Game.state
	var font := get_theme_default_font()
	# Wallpaper with tired stripes, and a water stain.
	for i in 18:
		r.draw_rect(Rect2(i * 40, 0, 40, 600), Color("#6b4f7a") if i % 2 == 0 else Color("#5e4570"))
	r.draw_circle(Vector2(150, 70), 46, Color("#4e3a5c", 0.6))
	r.draw_rect(Rect2(0, 590, 720, 14), Color("#3a2a44"))
	# Carpet with a mystery stain.
	r.draw_rect(Rect2(0, 604, 720, 256), Color("#7a4b2e"))
	for i in 12:
		r.draw_line(Vector2(0, 620 + i * 22), Vector2(720, 610 + i * 22), Color("#6e4228"), 2)
	r.draw_set_transform(Vector2(560, 780), 0, Vector2(1.8, 0.6))
	r.draw_circle(Vector2.ZERO, 40, Color("#5a3420", 0.7))
	r.draw_set_transform(Vector2.ZERO)

	_draw_window(r)
	_draw_calendar(r, font)

	# Bed.
	r.draw_rect(Rect2(20, 470, 320, 30), Color("#4a2e1a"))
	r.draw_rect(Rect2(20, 500, 320, 110), Color("#5a3820"))
	r.draw_rect(Rect2(30, 450, 300, 60), Color("#d8d2c0"))
	r.draw_rect(Rect2(40, 430, 90, 36), Color("#f1ece0"))
	r.draw_rect(Rect2(130, 455, 200, 70), Color("#a33b3b"))
	r.draw_line(Vector2(130, 470), Vector2(330, 470), Color("#c95454"), 4)
	# Wall shelf.
	r.draw_rect(Rect2(60, 346, 170, 12), Color("#4a2e1a"))
	# Nightstand + lamp.
	r.draw_rect(Rect2(345, 578, 70, 90), Color("#5a3820"))
	r.draw_rect(Rect2(352, 600, 56, 6), Color("#3a2414"))
	r.draw_line(Vector2(365, 578), Vector2(365, 540), Color("#2b2b38"), 4)
	r.draw_colored_polygon([Vector2(345, 540), Vector2(385, 540), Vector2(376, 515), Vector2(354, 515)], Color("#f3d58a"))
	r.draw_circle(Vector2(365, 545), 60, Color("#ffd27a", 0.08))
	# TV stand.
	r.draw_rect(Rect2(470, 550, 210, 70), Color("#4a2e1a"))
	r.draw_rect(Rect2(480, 560, 90, 50), Color("#3a2414"))
	# Hooks for clothes.
	for x in [271, 347]:
		r.draw_circle(Vector2(x, 118), 6, Color("#c9a86a"))

	# Items: the thing itself, a dusty outline, or Vinnie's note.
	for key in SPOTS:
		if _has(key):
			call("_draw_" + key.trim_prefix("ITEM_").to_lower(), r)
		elif key in s.taken:
			_note(r, SPOTS[key], font)
		elif key in ["ITEM_BLAZER", "ITEM_SUIT"]:
			pass # never owned is just an empty hook
		else:
			_dust(r, SPOTS[key])


func _dust(r: Control, rect: Rect2) -> void:
	var c := Color("#e8dcc0", 0.35)
	var pts := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
	for i in 4:
		r.draw_dashed_line(pts[i], pts[i + 1], c, 2, 8)


func _note(r: Control, rect: Rect2, font: Font) -> void:
	_dust(r, rect)
	var p := rect.get_center() - Vector2(44, 34)
	r.draw_set_transform(p, -0.08, Vector2.ONE)
	r.draw_rect(Rect2(4, 4, 88, 68), Color(0, 0, 0, 0.25))
	r.draw_rect(Rect2(0, 0, 88, 68), Color("#ffe066"))
	r.draw_string(font, Vector2(8, 28), "Thanks.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#3a2a00"))
	r.draw_string(font, Vector2(30, 56), "- V.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#b00020"))
	r.draw_set_transform(Vector2.ZERO)


func _draw_window(r: Control) -> void:
	var w := Rect2(430, 70, 220, 230)
	r.draw_rect(w.grow(10), Color("#3a2414"))
	r.draw_rect(w, Color("#141033"))
	for i in 9:
		var sp := Vector2(440 + fmod(i * 73.0, 200), 80 + fmod(i * 41.0, 90))
		r.draw_circle(sp, 1.6, Color(1, 1, 0.9, 0.5 + 0.5 * sin(t * 2 + i)))
	# Neon MOTEL sign across the street, buzzing.
	var on := fmod(t, 4.0) > 0.25
	var neon := Color("#ff4fd8") if on else Color("#5a2050")
	r.draw_rect(Rect2(455, 110, 120, 44), Color("#1b1030"))
	r.draw_string(get_theme_default_font(), Vector2(466, 144), "MOTEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, neon)
	if on:
		r.draw_circle(Vector2(515, 132), 80, Color("#ff4fd8", 0.07))
	# Parking lot.
	r.draw_rect(Rect2(w.position.x, 270, w.size.x, 30), Color("#2a2a33"))
	r.draw_line(Vector2(w.get_center().x, 70), Vector2(w.get_center().x, 300), Color("#3a2414"), 6)
	r.draw_line(Vector2(430, 185), Vector2(650, 185), Color("#3a2414"), 6)


func _draw_car(r: Control) -> void:
	var o := Vector2(450, 225)
	r.draw_rect(Rect2(o + Vector2(0, 22), Vector2(170, 34)), Color("#c0392b"))
	r.draw_colored_polygon([o + Vector2(30, 22), o + Vector2(50, 0), o + Vector2(120, 0), o + Vector2(145, 22)], Color("#a93226"))
	r.draw_rect(Rect2(o + Vector2(55, 5), Vector2(28, 16)), Color("#9fd3e6"))
	r.draw_rect(Rect2(o + Vector2(88, 5), Vector2(28, 16)), Color("#9fd3e6"))
	r.draw_circle(o + Vector2(38, 58), 13, Color("#111"))
	r.draw_circle(o + Vector2(132, 58), 13, Color("#111"))
	r.draw_circle(o + Vector2(166, 34), 5, Color("#ffe9a0"))


func _draw_calendar(r: Control, font: Font) -> void:
	var s = Game.state
	var c := Rect2(40, 110, 150, 140)
	r.draw_rect(c, Color("#f4efe4"))
	r.draw_rect(Rect2(c.position, Vector2(c.size.x, 30)), Color("#c8102e"))
	r.draw_string(font, c.position + Vector2(10, 23), tr("MOTEL_DAY") % s.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for i in 7: # this week, rent day circled
		var x := c.position.x + 12 + (i % 4) * 34
		var y := c.position.y + 60 + (i / 4) * 40
		var d: int = s.day + i
		r.draw_string(font, Vector2(x, y), str(d), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#3b2a52"))
		if i == s.days_to_rent() - 1:
			r.draw_arc(Vector2(x + 10, y - 7), 17, 0, TAU, 24, Color("#c8102e"), 3)
	r.draw_string(font, c.position + Vector2(78, 130), tr("MOTEL_RENT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#c8102e"))


func _draw_iron(r: Control) -> void:
	# Ironing board + iron.
	r.draw_colored_polygon([Vector2(180, 720), Vector2(380, 720), Vector2(400, 735), Vector2(380, 750), Vector2(180, 750)], Color("#8fb3c9"))
	r.draw_line(Vector2(220, 750), Vector2(300, 830), Color("#777"), 5)
	r.draw_line(Vector2(340, 750), Vector2(260, 830), Color("#777"), 5)
	r.draw_colored_polygon([Vector2(300, 705), Vector2(360, 705), Vector2(372, 720), Vector2(290, 720)], Color("#3b8de0"))
	r.draw_rect(Rect2(312, 694, 34, 8), Color("#222"))


func _draw_microwave(r: Control) -> void:
	r.draw_rect(Rect2(80, 268, 130, 78), Color("#d6d6d6"))
	r.draw_rect(Rect2(88, 276, 82, 62), Color("#2d3436"))
	r.draw_rect(Rect2(176, 278, 26, 58), Color("#b2b2b2"))
	r.draw_circle(Vector2(189, 292), 5, Color("#444"))
	r.draw_rect(Rect2(181, 306, 16, 8), Color("#2ecc71"))


func _draw_guitar(r: Control) -> void:
	r.draw_set_transform(Vector2(442, 590), -0.12, Vector2.ONE)
	r.draw_rect(Rect2(-6, -220, 12, 140), Color("#5a3820"))
	r.draw_rect(Rect2(-9, -232, 18, 18), Color("#3a2414"))
	r.draw_circle(Vector2(0, -60), 28, Color("#d35400"))
	r.draw_circle(Vector2(0, -20), 36, Color("#d35400"))
	r.draw_circle(Vector2(0, -45), 10, Color("#2b1a0e"))
	for k in 3:
		r.draw_line(Vector2(-3 + k * 3, -220), Vector2(-3 + k * 3, -10), Color("#eee", 0.7), 1)
	r.draw_set_transform(Vector2.ZERO)


func _draw_tv(r: Control) -> void:
	r.draw_rect(Rect2(480, 420, 190, 130), Color("#2b2b33"))
	var flick := 0.85 + 0.15 * sin(t * 13.0)
	r.draw_rect(Rect2(492, 432, 166, 104), Color("#3a7bd5") * Color(flick, flick, flick, 1))
	# A horse race on TV, of course.
	var hx := 500 + fmod(t * 40.0, 150)
	r.draw_rect(Rect2(492, 505, 166, 31), Color("#2e8b57") * Color(flick, flick, flick, 1))
	r.draw_rect(Rect2(hx, 488, 22, 14), Color("#5a3820"))
	r.draw_line(Vector2(560, 405), Vector2(540, 420), Color("#555"), 3)
	r.draw_line(Vector2(590, 405), Vector2(610, 420), Color("#555"), 3)


func _draw_watch(r: Control) -> void:
	r.draw_circle(Vector2(376, 566), 13, Color("#e8b923"))
	r.draw_circle(Vector2(376, 566), 9, Color("#fff8e1"))
	r.draw_line(Vector2(376, 566), Vector2(376, 559), Color("#333"), 2)
	r.draw_line(Vector2(376, 566), Vector2(382, 566), Color("#333"), 2)


func _draw_blazer(r: Control) -> void:
	_jacket(r, Vector2(271, 122), Color("#2c4a7a"), false)


func _draw_suit(r: Control) -> void:
	_jacket(r, Vector2(347, 122), Color("#2b2b33"), true)


func _jacket(r: Control, hook: Vector2, col: Color, tie: bool) -> void:
	r.draw_line(hook, hook + Vector2(-26, 14), Color("#c9a86a"), 3)
	r.draw_line(hook, hook + Vector2(26, 14), Color("#c9a86a"), 3)
	r.draw_colored_polygon([hook + Vector2(-32, 14), hook + Vector2(32, 14), hook + Vector2(36, 118), hook + Vector2(-36, 118)], col)
	r.draw_colored_polygon([hook + Vector2(-8, 14), hook + Vector2(8, 14), hook + Vector2(0, 60)], Color("#f4f4f4"))
	if tie:
		r.draw_colored_polygon([hook + Vector2(-3, 18), hook + Vector2(3, 18), hook + Vector2(5, 52), hook + Vector2(0, 60), hook + Vector2(-5, 52)], Color("#c8102e"))
	r.draw_line(hook + Vector2(0, 60), hook + Vector2(0, 118), col.darkened(0.3), 2)
	for k in 2:
		r.draw_circle(hook + Vector2(4, 72 + k * 18), 3, Color("#e8b923"))
