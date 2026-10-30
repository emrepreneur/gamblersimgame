extends Control
## Lucky Shot Bets: a smoky betting shop. Pick a side, then watch the match live on the shop TV.

const Table := preload("res://scripts/roulette_table.gd")
const CHIPS := [5, 10, 25, 50, 100]
const MATCH_TIME := 6.0
const TEAM_COLORS := [Color("#e63946"), Color("#ff6ec7"), Color("#a0522d"), Color("#2a9d8f"),
	Color("#f4a261"), Color("#7bd389"), Color("#9aa0a6"), Color("#7b2cbf")]

var tv: Control
var hud: Label
var toast: Label
var list: VBoxContainer
var chip := 10
var t := 0.0
var playing := false
var pending := 0 # winnings already in the state but not revealed yet
var teams := [0, 1]
var goals_at: Array = [] # [[time, side 0/1], ...]
var final := [0, 0]
var smoke: Array = []
var sfx := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2b2320")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for n in ["chips-collide-1", "chips-stack-1"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.ogg" % n)
		add_child(p)
		sfx[n] = p
	for i in 14:
		smoke.append([randf() * 720, randf() * 480, randf_range(30, 70), randf() * TAU])

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var top := PanelContainer.new()
	box.add_child(top)
	hud = Label.new()
	top.add_child(hud)

	tv = Control.new()
	tv.custom_minimum_size = Vector2(0, 470)
	tv.clip_contents = true
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.draw.connect(_draw_shop)
	box.add_child(tv)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.y = 64
	toast.add_theme_color_override("font_color", Color("#fff3c4"))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.text = tr("SPORT_PICK")
	box.add_child(toast)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var inner := VBoxContainer.new()
	panel.add_child(inner)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(list)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 10)
	inner.add_child(chips)
	for v in CHIPS:
		var c := Control.new()
		c.custom_minimum_size = Vector2(76, 70)
		c.draw.connect(func():
			if v == chip:
				c.draw_circle(Vector2(38, 36), 36, Color("#f7d774", 0.7))
			Table.draw_chip(c, Vector2(38, 35 if v != chip else 30), 30, v))
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				chip = v
				for k in chips.get_children(): k.queue_redraw())
		chips.add_child(c)
	Game.make_button(box, tr("BTN_BACK"), Game.go.bind("world"))
	_refresh()


func _refresh() -> void:
	var s = Game.state
	hud.text = tr("SPORT_HUD") % [s.day, s.money - pending, s.debt]
	for c in list.get_children():
		c.queue_free()
	if s.matches.is_empty():
		Game.make_label(list, tr("SPORT_NO_MATCHES"))
	for i in s.matches.size():
		var m: Array = s.matches[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		for home in [true, false]:
			var chance: float = m[2] if home else 1.0 - m[2]
			var b := Game.make_button(row, "%s  x%.2f" % [tr("TEAM_%d" % m[0 if home else 1]), s.odds(chance)], _bet.bind(i, home))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 70
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_color_override("font_color", TEAM_COLORS[m[0 if home else 1]].darkened(0.5))
			b.disabled = playing or s.money <= 0 or Game.is_over() or s.shadowed
	if s.shadowed:
		toast.text = tr("SHADOW_BOUNCER")


func _bet(index: int, home: bool) -> void:
	var s = Game.state
	var m: Array = s.matches[index]
	var amount := mini(chip, s.money)
	var result: Dictionary = s.bet_match(index, home, amount)
	if result.is_empty():
		return
	sfx["chips-collide-1"].play()
	var won: bool = result.key == "SPORT_WIN"
	# Make up a score that agrees with the result: the side Larry picked wins iff he won.
	var winner_side := (0 if home else 1) if won else (1 if home else 0)
	var w := randi_range(1, 3)
	var l := randi_range(0, w - 1)
	final = [w, l] if winner_side == 0 else [l, w]
	goals_at = []
	for side in 2:
		for g in final[side]:
			goals_at.append([randf_range(0.5, MATCH_TIME - 0.6), side])
	goals_at.sort_custom(func(a, b): return a[0] < b[0])
	pending = result.args[0] if won else 0
	teams = [m[0], m[1]]
	t = 0.0
	playing = true
	toast.text = tr("SPORT_KICKOFF") % [tr("TEAM_%d" % m[0 if home else 1]), amount]
	_refresh()
	await get_tree().create_timer(MATCH_TIME + 0.4).timeout
	pending = 0
	Game.record(result)
	toast.text = Game.entry_text(result)
	if won:
		sfx["chips-stack-1"].play()
	playing = false
	_refresh()


func _process(delta: float) -> void:
	t += delta
	tv.queue_redraw()


func _score_now() -> Array:
	var sc := [0, 0]
	if not playing and t > MATCH_TIME:
		return final
	for g in goals_at:
		if g[0] <= t:
			sc[g[1]] += 1
	return sc


# --- Drawing --------------------------------------------------------------

func _draw_shop() -> void:
	var c := tv
	var sz := c.size
	var font := get_theme_default_font()
	# Back wall with wood panels and a lucky horseshoe.
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#3d2f2a"))
	for i in 10:
		c.draw_line(Vector2(i * 80, 0), Vector2(i * 80, sz.y), Color("#33271f"), 3)
	c.draw_arc(Vector2(sz.x - 60, 40), 20, PI * 0.15, PI * 1.85, 16, Color("#c9a86a"), 6)
	# Odds board on the left.
	c.draw_rect(Rect2(14, 30, 120, 150), Color("#111"))
	for k in 6:
		c.draw_string(font, Vector2(24, 60 + k * 22), "%d.%d" % [1 + (k * 7) % 5, (k * 3) % 10], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffb000"))

	# The TV.
	var screen := Rect2(150, 26, sz.x - 230, 290)
	c.draw_rect(screen.grow(12), Color("#1a1a1e"))
	c.draw_rect(screen.grow(4), Color("#0c0c0e"))
	_draw_pitch(screen)
	c.draw_circle(Vector2(screen.end.x - 6, screen.end.y + 6), 3, Color("#ff3b3b") if playing else Color("#5a1a1a"))

	# Counter in front, with betting slips and a bookie's ashtray.
	c.draw_rect(Rect2(0, sz.y - 120, sz.x, 120), Color("#5a3820"))
	c.draw_rect(Rect2(0, sz.y - 120, sz.x, 14), Color("#7a4b2a"))
	for k in 5:
		c.draw_set_transform(Vector2(60 + k * 120, sz.y - 70), 0.2 * (k - 2), Vector2.ONE)
		c.draw_rect(Rect2(-26, -16, 52, 34), Color("#f4efe4"))
		for j in 3:
			c.draw_line(Vector2(-20, -8 + j * 9), Vector2(16, -8 + j * 9), Color("#999"), 2)
		c.draw_set_transform(Vector2.ZERO)
	c.draw_circle(Vector2(sz.x - 70, sz.y - 70), 26, Color("#7d8a96"))
	c.draw_circle(Vector2(sz.x - 70, sz.y - 70), 17, Color("#4b545c"))
	# Cigarette smoke drifting up.
	for p in smoke:
		var y := fmod(p[1] - t * 18.0, sz.y + 100)
		if y < -60:
			y += sz.y + 100
		var x: float = p[0] + sin(t * 0.6 + p[3]) * 30
		c.draw_circle(Vector2(x, y), p[2], Color(0.85, 0.85, 0.9, 0.03))


func _draw_pitch(r: Rect2) -> void:
	var c := tv
	var font := get_theme_default_font()
	var flick := 0.92 + 0.08 * sin(t * 50.0)
	for i in 8:
		c.draw_rect(Rect2(r.position.x + i * r.size.x / 8, r.position.y, r.size.x / 8 + 1, r.size.y),
			(Color("#2e8b57") if i % 2 == 0 else Color("#279150")) * Color(flick, flick, flick, 1))
	var line := Color(1, 1, 1, 0.8)
	c.draw_rect(r.grow(-10), line, false, 2)
	c.draw_line(Vector2(r.get_center().x, r.position.y + 10), Vector2(r.get_center().x, r.end.y - 10), line, 2)
	c.draw_arc(r.get_center(), 34, 0, TAU, 32, line, 2)
	for side in [0, 1]:
		var gx := r.position.x + 10 if side == 0 else r.end.x - 10
		c.draw_rect(Rect2(gx - (0 if side == 0 else 40), r.get_center().y - 50, 40, 100), line, false, 2)
		c.draw_rect(Rect2(gx - (8 if side == 0 else 0), r.get_center().y - 22, 8, 44), Color("#eeeeee"))

	if not playing and goals_at.is_empty():
		var txt := tr("SPORT_TV_IDLE")
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		c.draw_string_outline(font, r.get_center() + Vector2(-w / 2, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color.BLACK)
		c.draw_string(font, r.get_center() + Vector2(-w / 2, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		return

	# Ball: wanders, and heads for a goal just before each goal moment.
	var tt := minf(t, MATCH_TIME)
	var ball := r.get_center() + Vector2(sin(tt * 2.1) * r.size.x * 0.3, sin(tt * 3.3 + 1) * r.size.y * 0.3)
	for g in goals_at:
		var d: float = g[0] - tt
		if d > 0 and d < 0.6:
			var goal := Vector2(r.end.x - 14 if g[1] == 0 else r.position.x + 14, r.get_center().y)
			ball = ball.lerp(goal, 1.0 - d / 0.6)
	# Players chase the ball.
	for side in 2:
		var col: Color = TEAM_COLORS[teams[side]]
		for k in 5:
			var home := Vector2(r.position.x + r.size.x * (0.15 + 0.14 * k if side == 0 else 0.85 - 0.14 * k), r.position.y + r.size.y * (0.2 + 0.15 * k))
			var p := home.lerp(ball, 0.35 + 0.1 * sin(tt * 2 + k)) + Vector2(sin(tt * 5 + k * 2) * 6, cos(tt * 4 + k) * 6)
			c.draw_circle(p + Vector2(0, 3), 8, Color(0, 0, 0, 0.3))
			c.draw_circle(p, 8, col)
			c.draw_arc(p, 8, 0, TAU, 12, Color.WHITE, 1.5)
	c.draw_circle(ball + Vector2(1, 2), 5, Color(0, 0, 0, 0.35))
	c.draw_circle(ball, 5, Color.WHITE)

	# Scoreboard bug and match clock.
	var sc := _score_now()
	var minute := int(clampf(tt / MATCH_TIME, 0, 1) * 90)
	var bug := "%s %d - %d %s   %d'" % [_abbr(teams[0]), sc[0], sc[1], _abbr(teams[1]), minute]
	c.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(300, 34)), Color(0, 0, 0, 0.75))
	c.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(6, 34)), TEAM_COLORS[teams[0]])
	c.draw_string(font, r.position + Vector2(22, 33), bug, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	# GOAL! flash.
	for g in goals_at:
		if tt - g[0] >= 0 and tt - g[0] < 0.9:
			var txt := tr("SPORT_GOAL")
			var fs := 64
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := r.get_center() + Vector2(-w / 2, 20)
			c.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color.BLACK)
			c.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEAM_COLORS[teams[g[1]]].lightened(0.3))
	if not playing and t > MATCH_TIME:
		var ft := tr("SPORT_FULLTIME")
		var w2 := font.get_string_size(ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		c.draw_rect(Rect2(r.get_center() + Vector2(-w2 / 2 - 12, 40), Vector2(w2 + 24, 40)), Color(0, 0, 0, 0.7))
		c.draw_string(font, r.get_center() + Vector2(-w2 / 2, 70), ft, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ffd23f"))


func _abbr(team: int) -> String:
	return tr("TEAM_%d" % team).split(" ")[-1].substr(0, 3).to_upper()
