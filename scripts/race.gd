extends Control
## Back-alley roach derby, drawn in code: cardboard track, wiggling roaches, a yelling crowd, police raids.
## Bottom half: the race card (tap a roach to bet), and Larry's own roach stable.

const Table := preload("res://scripts/roulette_table.gd")
const CHIPS := [5, 10, 25, 50]
const LANE_COLORS := [Color("#e63946"), Color("#f4a261"), Color("#2a9d8f"), Color("#8e7dff"), Color("#e9c46a")]
const RACE_TIME := 4.0

var track: Control
var toast: Label
var hud: Label
var card: VBoxContainer
var stable: VBoxContainer
var race_btn: Button
var clear_btn: Button
var chip := 10
var bets := {} # field index -> amount
var running := false
var t := 0.0
var finish_at: Array = [] # per lane: time it crosses the line
var raid := false
var winner := -1
var sfx := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#1e1a1a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for n in ["chips-collide-1", "chips-stack-1", "dice-shake-1"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.ogg" % n)
		add_child(p)
		sfx[n] = p

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var top := PanelContainer.new()
	box.add_child(top)
	hud = Label.new()
	top.add_child(hud)

	track = Control.new()
	track.custom_minimum_size = Vector2(0, 430)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.clip_contents = true
	track.draw.connect(_draw_track)
	box.add_child(track)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.y = 70
	toast.add_theme_color_override("font_color", Color("#fff3c4"))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.text = tr("RACE_PICK")
	box.add_child(toast)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	inner.add_child(card)
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
	stable = VBoxContainer.new()
	inner.add_child(stable)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	clear_btn = Game.make_button(row, tr("ROULETTE_CLEAR"), func(): bets.clear(); _refresh())
	race_btn = Game.make_button(row, tr("RACE_GO"), _race)
	race_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Game.make_button(row, tr("BTN_BACK_SHORT"), Game.go.bind("world")).custom_minimum_size.x = 140
	clear_btn.custom_minimum_size.x = 160
	_refresh()


func _staked() -> int:
	return bets.values().reduce(func(a, b): return a + b, 0)


func _refresh() -> void:
	var s = Game.state
	hud.text = tr("ROULETTE_HUD") % [s.money, _staked()]
	for c in card.get_children():
		c.queue_free()
	# While racing, list the roaches on the track (the state has already rolled the next field).
	var fld: Array = shown_field if running else s.field
	var total := 0.0
	for r in fld:
		total += r[1] * r[1]
	for i in fld.size():
		var r: Array = fld[i]
		var chance: float = r[1] * r[1] / total
		var own: bool = i == (own_lane if running else s.own_in_field())
		var b := Button.new()
		b.custom_minimum_size.y = 58
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 24)
		var stake := "   +$%d" % bets[i] if bets.has(i) else ""
		b.text = tr("RACE_ROW") % [i + 1, r[0] + (tr("ROACH_YOURS") if own else ""), r[1], s.roach_odds(chance)] + stake
		b.add_theme_color_override("font_color", LANE_COLORS[i].darkened(0.45))
		b.disabled = running
		b.pressed.connect(_bet.bind(i))
		card.add_child(b)

	for c in stable.get_children():
		c.queue_free()
	if s.roach.is_empty():
		Game.make_button(stable, tr("ROACH_BUY") % s.ROACH_PRICE, _act.bind(s.buy_roach)).disabled = running or s.money < s.ROACH_PRICE
	else:
		Game.make_label(stable, tr("ROACH_STATS") % [s.roach.name, s.roach.speed, s.ROACH_MAX]).add_theme_font_size_override("font_size", 24)
		var row := HBoxContainer.new()
		stable.add_child(row)
		var tb := Game.make_button(row, tr("ROACH_TRAIN") % s.TRAIN_COST, _act.bind(s.train_roach))
		tb.disabled = running or s.roach.trained_day == s.day or s.money < s.TRAIN_COST or s.roach.speed >= s.ROACH_MAX
		var eb := Game.make_button(row, tr("ROACH_ENTER") % s.ENTRY_FEE, _act.bind(s.enter_roach))
		eb.disabled = running or s.roach.raced_day == s.day or s.own_in_field() >= 0 or s.money < s.ENTRY_FEE
		for x in [tb, eb]:
			x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			x.custom_minimum_size.y = 64
			x.add_theme_font_size_override("font_size", 24)
	race_btn.disabled = running or (bets.is_empty() and s.own_in_field() < 0)
	clear_btn.disabled = running or bets.is_empty()
	track.queue_redraw()


## Back to the pre-race view after a finished race.
func _reset_view() -> void:
	shown_field = []
	winner = -1
	raid = false
	own_lane = -1


func _bet(i: int) -> void:
	_reset_view()
	var amount := mini(chip, Game.state.money - _staked())
	if amount <= 0:
		toast.text = tr("ROULETTE_BROKE")
		return
	bets[i] = bets.get(i, 0) + amount
	sfx["chips-collide-1"].play()
	_refresh()


func _act(action: Callable) -> void:
	_reset_view()
	var r: Dictionary = action.call()
	Game.record(r)
	if not r.is_empty():
		toast.text = Game.entry_text(r)
	bets.clear() # field may have changed
	_refresh()


func _race() -> void:
	var s = Game.state
	var lanes: Array = s.field.duplicate(true)
	var own: int = s.own_in_field()
	var result: Dictionary = s.run_race(bets)
	if result.is_empty():
		return
	running = true
	raid = result.raid
	t = 0.0
	shown_field = lanes
	own_lane = own
	finish_at = []
	for i in lanes.size():
		finish_at.append(99.0)
	for k in result.order.size():
		finish_at[result.order[k]] = RACE_TIME * 0.8 + k * 0.32 + randf() * 0.1
	winner = result.order[0] if not raid else -1
	sfx["dice-shake-1"].play()
	toast.text = tr("RACE_OFF")
	_refresh()
	await get_tree().create_timer(RACE_TIME + 0.6).timeout
	var key := ""
	var args := []
	if raid:
		key = "RACE_RAID"; args = [result.staked]
	elif result.win + result.purse > 0:
		key = "RACE_WIN"; args = [lanes[winner][0], result.win + result.purse]
		sfx["chips-stack-1"].play()
	else:
		key = "RACE_LOSE"; args = [lanes[winner][0], result.staked]
	Game.record({"key": key, "args": args})
	toast.text = tr(key) % args
	bets.clear()
	running = false
	_refresh()


var shown_field: Array = [] # the field being raced (state already rolled a new one)
var own_lane := -1


func _process(delta: float) -> void:
	t += delta
	track.queue_redraw()


# --- Drawing --------------------------------------------------------------

func _draw_track() -> void:
	var sz := track.size
	var font := get_theme_default_font()
	# Garage: concrete floor, a bare bulb, oil stains.
	track.draw_rect(Rect2(Vector2.ZERO, sz), Color("#4a4440"))
	track.draw_circle(Vector2(sz.x * 0.2, sz.y * 0.85), 40, Color(0, 0, 0, 0.15))
	track.draw_circle(Vector2(sz.x * 0.82, sz.y * 0.2), 26, Color(0, 0, 0, 0.12))
	track.draw_circle(Vector2(sz.x / 2, 0), 220, Color("#ffd27a", 0.06))
	track.draw_line(Vector2(sz.x / 2, 0), Vector2(sz.x / 2, 20), Color("#222"), 3)
	track.draw_circle(Vector2(sz.x / 2, 26), 10, Color("#fff1b0"))

	# Crowd behind the track, bobbing (faster while racing).
	var excite := 14.0 if running else 2.0
	for i in 16:
		var x := 20 + i * (sz.x - 40) / 15.0
		var bob := absf(sin(t * excite * 0.5 + i * 1.7)) * (10.0 if running else 3.0)
		var col := Color.from_hsv(fmod(i * 0.37, 1.0), 0.35, 0.55)
		track.draw_rect(Rect2(x - 18, 92 - bob, 36, 50), col)
		track.draw_circle(Vector2(x, 80 - bob), 15, Color("#d9a77a").darkened(fmod(i * 0.13, 0.4)))
		if running and i % 3 == 0: # arms up
			track.draw_line(Vector2(x - 14, 96 - bob), Vector2(x - 24, 64 - bob), col, 6)
			track.draw_line(Vector2(x + 14, 96 - bob), Vector2(x + 24, 64 - bob), col, 6)

	# Cardboard track with taped lanes.
	var tr_rect := Rect2(16, 140, sz.x - 32, sz.y - 160)
	track.draw_rect(tr_rect.grow(6), Color("#8a6436"))
	track.draw_rect(tr_rect, Color("#c79a5c"))
	var lane_h := tr_rect.size.y / 5.0
	for i in 5:
		var y := tr_rect.position.y + i * lane_h
		track.draw_rect(Rect2(tr_rect.position.x, y, 28, lane_h), LANE_COLORS[i])
		track.draw_string(font, Vector2(tr_rect.position.x + 7, y + lane_h * 0.62), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		if i > 0:
			track.draw_line(Vector2(tr_rect.position.x, y), Vector2(tr_rect.end.x, y), Color("#f1e3c6"), 3)
	var start_x := tr_rect.position.x + 50
	var finish_x := tr_rect.end.x - 40
	track.draw_line(Vector2(start_x, tr_rect.position.y), Vector2(start_x, tr_rect.end.y), Color.WHITE, 3)
	for k in int(tr_rect.size.y / 12): # checkered finish
		for j in 2:
			if (k + j) % 2 == 0:
				track.draw_rect(Rect2(finish_x + j * 12, tr_rect.position.y + k * 12, 12, 12), Color("#111"))
			else:
				track.draw_rect(Rect2(finish_x + j * 12, tr_rect.position.y + k * 12, 12, 12), Color.WHITE)

	# Roaches.
	var racing := not shown_field.is_empty()
	var lanes: Array = shown_field if racing else Game.state.field
	for i in lanes.size():
		var y := tr_rect.position.y + (i + 0.5) * lane_h
		var p := 0.0
		var dir := 0.0
		if racing:
			var ft: float = finish_at[i] if i < finish_at.size() else 99.0
			var tt := minf(t, RACE_TIME + 0.6)
			p = clampf(tt / ft, 0.0, 1.15)
			p += 0.04 * sin(tt * 9.0 + i) * clampf(p, 0, 1) * (1.0 - clampf(p, 0, 1))
			if raid and tt > 1.6: # scatter!
				dir = (i - 2) * 0.5
				y += (tt - 1.6) * 120 * (i - 2)
		var x := lerpf(start_x, finish_x, clampf(p, 0, 1)) + maxf(p - 1.0, 0) * 200
		var moving := running and (p < 1.1 or raid)
		_draw_roach(Vector2(x, y), i, moving, dir, i == (own_lane if racing else Game.state.own_in_field()))

	# Raid: police lights and a big label.
	if raid and running and t > 1.5:
		var flash := int(t * 6) % 2 == 0
		track.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 0, 0, 0.25) if flash else Color(0, 0.3, 1, 0.25))
		var txt := tr("RACE_RAID_SHOUT")
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		track.draw_string_outline(font, Vector2((sz.x - w) / 2, sz.y / 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 12, Color.BLACK)
		track.draw_string(font, Vector2((sz.x - w) / 2, sz.y / 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
	elif winner >= 0 and t > RACE_TIME * 0.8:
		var txt2 := tr("RACE_WINNER") % (winner + 1)
		var w2 := font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		track.draw_string_outline(font, Vector2((sz.x - w2) / 2, 128), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 10, Color.BLACK)
		track.draw_string(font, Vector2((sz.x - w2) / 2, 128), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, LANE_COLORS[winner].lightened(0.3))


func _draw_roach(p: Vector2, lane: int, moving: bool, turn: float, own: bool) -> void:
	track.draw_set_transform(p, turn, Vector2.ONE)
	var wig := sin(t * 30.0 + lane) * (6.0 if moving else 1.0)
	var leg := Color("#3a2414")
	for k in 3: # six legs
		var lx := -12.0 + k * 12.0
		var swing := wig if k % 2 == 0 else -wig
		track.draw_line(Vector2(lx, -6), Vector2(lx + swing, -20), leg, 3)
		track.draw_line(Vector2(lx, 6), Vector2(lx - swing, 20), leg, 3)
	track.draw_set_transform(p + Vector2(0, 4), turn, Vector2(1, 0.5))
	track.draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.25)) # shadow
	track.draw_set_transform(p, turn, Vector2(1.5, 0.75))
	track.draw_circle(Vector2.ZERO, 16, Color("#6b3e1f")) # shell
	track.draw_circle(Vector2(-2, -3), 10, Color("#8a552c"))
	track.draw_set_transform(p, turn, Vector2.ONE)
	track.draw_line(Vector2(0, -11), Vector2(0, 11), Color("#4a2a12"), 2) # wing split
	track.draw_circle(Vector2(26, 0), 8, Color("#4a2a12")) # head
	track.draw_line(Vector2(31, -3), Vector2(46, -14 + wig * 0.4), leg, 2) # antennae
	track.draw_line(Vector2(31, 3), Vector2(46, 14 - wig * 0.4), leg, 2)
	track.draw_circle(Vector2(-4, 0), 9, LANE_COLORS[lane]) # number sticker
	var font := get_theme_default_font()
	track.draw_string(font, Vector2(-9, 6), str(lane + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	if own: # gold star over Larry's roach
		var star := PackedVector2Array()
		for k in 10:
			star.append(Vector2(0, -30) + Vector2.from_angle(-PI / 2 + k * PI / 5) * (10.0 if k % 2 == 0 else 4.5))
		track.draw_colored_polygon(star, Color("#ffd23f"))
	track.draw_set_transform(Vector2.ZERO)
