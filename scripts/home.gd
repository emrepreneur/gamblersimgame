extends Control
## The dashboard: who Larry is, how it's going, what's next, and a card for every place in town.

const PLACE_CARDS := ["MOTEL", "DINER", "CASINO", "BETS", "DERBY", "PAWN", "VINNIE", "MAP"]
const SCENES := {"MOTEL": "motel", "BETS": "sports", "DERBY": "race"} # the rest open as panels on the map

var cash: Label


func _ready() -> void:
	var s = Game.state
	Game.hub = "home"
	if Game.is_over() or s.collection_due() or s.event != "":
		Game.go.call_deferred("world") # Joey, a morning surprise or the eviction notice happens out there
		return
	var bg := ColorRect.new()
	bg.color = Game.NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	# Who he is.
	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 18)
	_card(box).add_child(id_row)
	var face := Control.new()
	face.custom_minimum_size = Vector2(130, 130)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.draw.connect(_draw_larry.bind(face))
	id_row.add_child(face)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	id_row.add_child(who)
	_text(who, "Lucky Larry", 44)
	_text(who, tr(s.HOMES[s.home][0]), 26, Game.GOLD)
	_text(who, tr("HOME_DAY") % [s.day, s.badges.size(), 8], 24, Color(Game.IVORY, 0.7))
	var lang := Game.make_button(id_row, tr("BTN_LANGUAGE"), func():
		TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("tr") else "tr")
		get_tree().reload_current_scene())
	lang.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lang.custom_minimum_size.y = 0
	lang.add_theme_font_size_override("font_size", 22)

	# Money.
	var money := VBoxContainer.new()
	var money_card := _card(box)
	money_card.add_theme_stylebox_override("panel", _felt())
	money_card.add_child(money)
	_text(money, tr("HOME_CASH"), 22, Color(Game.IVORY, 0.75))
	cash = _text(money, "", 76)
	if Game.shown_money < 0:
		Game.shown_money = s.money
	create_tween().tween_method(func(v: int): cash.text = "$%s" % _commas(v), Game.shown_money, s.money, 0.7).set_ease(Tween.EASE_OUT)
	if s.money != Game.shown_money:
		cash.add_theme_color_override("font_color", Game.GOLD if s.money > Game.shown_money else Color("#e88a9a"))
	Game.shown_money = s.money
	var facts := HBoxContainer.new()
	money.add_child(facts)
	_fact(facts, tr("HOME_RENT"), "$%d · %s" % [s.rent(), tr("HOME_IN_DAYS") % s.days_to_rent()])
	_fact(facts, tr("HOME_DEBT"), "$%s" % _commas(s.debt) + ("" if s.debt == 0 else " · " + tr("HOME_IN_DAYS") % maxi(s.due_day - s.day, 0)),
		Game.IVORY if s.debt == 0 else Color("#e88a9a"))

	# What just happened.
	var news := VBoxContainer.new()
	_card(box).add_child(news)
	_text(news, tr("HOME_LATEST"), 22, Game.GOLD)
	_text(news, Game.entry_text(Game.log[-1]), 26)

	# Where to go.
	_text(box, tr("HOME_CITY"), 22, Game.GOLD)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for id in PLACE_CARDS:
		grid.add_child(_place_card(id))


	# What's next.
	var goals := VBoxContainer.new()
	goals.add_theme_constant_override("separation", 8)
	_card(box).add_child(goals)
	_text(goals, tr("HOME_GOALS"), 22, Game.GOLD)
	for g in _goals():
		var row := HBoxContainer.new()
		goals.add_child(row)
		_text(row, g[0], 26).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(row, g[3], 24, Color(Game.IVORY, 0.7)).autowrap_mode = TextServer.AUTOWRAP_OFF
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 12
		bar.max_value = g[2]
		bar.value = 0
		goals.add_child(bar)
		create_tween().tween_property(bar, "value", mini(g[1], g[2]), 0.6).set_trans(Tween.TRANS_CUBIC)

func _goals() -> Array: # [text, progress, target, "x / y"]
	var s = Game.state
	var out := []
	if s.debt > 0:
		out.append([tr("GOAL_DEBT"), s.money, s.debt, "$%s / $%s" % [_commas(mini(s.money, s.debt)), _commas(s.debt)]])
	if s.next_home_price() > 0:
		var p: int = s.next_home_price()
		out.append([tr("GOAL_HOME") % tr(s.HOMES[s.home + 1][0]), s.money, p, "$%s / $%s" % [_commas(mini(s.money, p)), _commas(p)]])
	for d in [7, 30, 100]:
		if s.day < d:
			out.append([tr("GOAL_DAYS") % d, s.day, d, "%d / %d" % [s.day, d]])
			break
	if not "BADGE_ROACH3" in s.badges:
		var w: int = s.roach.get("wins", 0)
		out.append([tr("GOAL_ROACH"), w, 3, "%d / 3" % w])
	return out.slice(0, 3)


func _place_card(id: String) -> Control:
	var s = Game.state
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 190)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var locked: bool = id == "CASINO" and s.outfit() < s.CASINO_OUTFIT
	for state in ["normal", "hover", "pressed"]:
		var sb := Game.card_style()
		if state == "pressed":
			sb.bg_color = Game.CHARCOAL.lightened(0.08)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(Game.click.play)
	b.pressed.connect(func():
		if id == "MAP":
			Game.hub = "world"
			Game.go("world")
		elif SCENES.has(id):
			Game.go(SCENES[id])
		else:
			Game.open_place = id
			Game.go("world"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(0, 84)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_icon.bind(icon, id))
	col.add_child(icon)
	_text(col, tr("CARD_" + id), 27).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tag: String = tr("CARD_CASINO_LOCKED") if locked else tr("CARD_%s_TAG" % id)
	var sub := _text(col, tag, 20, Color("#e88a9a") if locked else Color(Game.IVORY, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


# --- Small builders ---------------------------------------------------------

func _card(parent: Container) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _felt() -> StyleBoxFlat:
	var sb := Game.card_style()
	sb.bg_color = Game.GREEN.darkened(0.35)
	sb.border_color = Color(Game.GOLD, 0.8)
	return sb


func _text(parent: Container, text: String, size: int, color := Game.IVORY) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _fact(row: Container, title: String, value: String, color := Game.IVORY) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_text(col, title, 20, Color(Game.IVORY, 0.7))
	_text(col, value, 28, color)


static func _commas(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out


# --- Drawing ----------------------------------------------------------------

## Larry's portrait: his jacket follows what he owns.
func _draw_larry(c: Control) -> void:
	var o := Vector2(65, 65)
	c.draw_circle(o, 65, Game.GREEN.darkened(0.3))
	c.draw_arc(o, 63, 0, TAU, 48, Game.GOLD, 3, true)
	var jacket: Color = [Color("#3f7fb5"), Color("#5a4a3a"), Color("#1c1f2b")][Game.state.outfit()]
	c.draw_colored_polygon([o + Vector2(-46, 46), o + Vector2(-30, 22), o + Vector2(30, 22), o + Vector2(46, 46), o + Vector2(28, 60), o + Vector2(-28, 60)], jacket)
	c.draw_colored_polygon([o + Vector2(-9, 22), o + Vector2(9, 22), o + Vector2(0, 44)], Color("#f4eedf") if Game.state.outfit() > 0 else Color("#f2c230"))
	c.draw_rect(Rect2(o + Vector2(-8, 10), Vector2(16, 14)), Color("#d9a273"))
	c.draw_circle(o + Vector2(0, -8), 24, Color("#e8b488"))
	c.draw_arc(o + Vector2(0, -12), 22, PI * 1.05, PI * 1.95, 16, Color("#4a3426"), 9) # thinning hair
	c.draw_circle(o + Vector2(-8, -10), 2.6, Color("#1b1420"))
	c.draw_circle(o + Vector2(8, -10), 2.6, Color("#1b1420"))
	c.draw_line(o + Vector2(-12, -17), o + Vector2(-4, -15), Color("#4a3426"), 2.5) # hopeful eyebrows
	c.draw_line(o + Vector2(12, -17), o + Vector2(4, -15), Color("#4a3426"), 2.5)
	c.draw_colored_polygon([o + Vector2(-11, 0), o + Vector2(0, -3), o + Vector2(11, 0), o + Vector2(8, 5), o + Vector2(-8, 5)], Color("#4a3426")) # moustache
	c.draw_arc(o + Vector2(0, 4), 7, 0.25, PI - 0.25, 10, Color("#8a4a3a"), 2)


func _draw_icon(c: Control, id: String) -> void:
	var o := Vector2(c.size.x / 2, 42)
	var gold := Game.GOLD
	var ivory := Game.IVORY
	match id:
		"MOTEL": # bed under a blinking sign
			c.draw_rect(Rect2(o + Vector2(-38, 4), Vector2(76, 16)), gold)
			c.draw_rect(Rect2(o + Vector2(-38, -16), Vector2(8, 46)), gold)
			c.draw_rect(Rect2(o + Vector2(30, 14), Vector2(8, 16)), gold)
			c.draw_rect(Rect2(o + Vector2(-26, -8), Vector2(22, 12)), ivory)
		"DINER": # coffee cup
			c.draw_rect(Rect2(o + Vector2(-22, -12), Vector2(40, 34)), ivory)
			c.draw_arc(o + Vector2(20, 4), 11, -PI / 2, PI / 2, 12, ivory, 5)
			c.draw_rect(Rect2(o + Vector2(-32, 24), Vector2(60, 5)), gold)
			for i in 3:
				c.draw_arc(o + Vector2(-12 + i * 10, -24), 5, PI / 2, PI * 1.5, 8, Color(ivory, 0.6), 2)
		"CASINO": # chip
			c.draw_circle(o, 36, Game.BURGUNDY)
			for i in 8:
				c.draw_arc(o, 31, i * TAU / 8, i * TAU / 8 + 0.35, 6, ivory, 9)
			c.draw_circle(o, 21, ivory)
			c.draw_circle(o, 17, Game.BURGUNDY)
		"BETS": # ball
			c.draw_circle(o, 34, ivory)
			c.draw_colored_polygon(_ngon(o, 12, 5, -PI / 2), Game.CHARCOAL)
			for i in 5:
				var a := -PI / 2 + i * TAU / 5
				c.draw_line(o + Vector2.from_angle(a) * 12, o + Vector2.from_angle(a) * 34, Game.CHARCOAL, 3)
		"DERBY": # roach
			c.draw_set_transform(o, 0, Vector2(1.5, 1.0))
			c.draw_circle(Vector2.ZERO, 22, Color("#8a5a2b"))
			c.draw_set_transform(Vector2.ZERO)
			c.draw_circle(o + Vector2(34, 0), 10, Color("#6b431f"))
			c.draw_line(o + Vector2(-30, 0), o + Vector2(24, 0), Color("#6b431f"), 2)
			for i in 3:
				for side in [-1, 1]:
					c.draw_line(o + Vector2(-16 + i * 16, side * 18), o + Vector2(-24 + i * 16, side * 34), gold, 3)
			c.draw_line(o + Vector2(42, -4), o + Vector2(56, -18), gold, 2)
			c.draw_line(o + Vector2(42, 4), o + Vector2(56, 18), gold, 2)
		"PAWN": # three balls
			c.draw_line(o + Vector2(-24, -22), o + Vector2(24, -22), gold, 4)
			for x in [-24, 0, 24]:
				c.draw_line(o + Vector2(x, -22), o + Vector2(x, 0 if x != 0 else 14), gold, 3)
				c.draw_circle(o + Vector2(x, 6 if x != 0 else 22), 13, gold)
		"VINNIE": # washing machine
			c.draw_rect(Rect2(o + Vector2(-30, -36), Vector2(60, 72)), ivory)
			c.draw_rect(Rect2(o + Vector2(-30, -36), Vector2(60, 14)), Color(Game.CHARCOAL, 0.25))
			c.draw_circle(o + Vector2(0, 8), 21, Game.CHARCOAL)
			c.draw_circle(o + Vector2(0, 8), 16, Game.GREEN)
			c.draw_string(get_theme_default_font(), o + Vector2(-6, 16), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, gold)
		"MAP": # pin
			c.draw_circle(o + Vector2(0, -10), 24, gold)
			c.draw_colored_polygon([o + Vector2(-20, 2), o + Vector2(20, 2), o + Vector2(0, 38)], gold)
			c.draw_circle(o + Vector2(0, -10), 10, Game.CHARCOAL)


static func _ngon(o: Vector2, r: float, n: int, start: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(o + Vector2.from_angle(start + i * TAU / n) * r)
	return pts
