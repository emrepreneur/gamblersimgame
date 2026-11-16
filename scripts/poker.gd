extends Control
## Texas Hold'em in the casino's back corner: Larry and three regulars, drawn in code.

const Table := preload("res://scripts/roulette_table.gd")
const RANKS := ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const CARD := Vector2(96, 134)
const SEAT_X := [360, 120, 360, 600] # seat 0 is Larry, at the bottom
const STEP := 0.55 # seconds between the regulars' moves

var felt: Control
var hud: Label
var toast: Label
var t := 0.0
var busy := false
var buttons := {}
var sfx := {}
# What the table looks like right now on screen (lags behind the rules while moves play out).
var shown := {"pot": 0, "stacks": [0, 100, 100, 100], "board": 0}
var said := ["", "", "", ""] # last move per seat
var out := [false, false, false, false]
var reveal := false
var tug := -10.0 # when the Reverend last tugged his collar


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Game.NAVY
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for n in ["card-slide-1", "card-shuffle", "chips-stack-1", "chips-collide-1"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.ogg" % n)
		add_child(p)
		sfx[n] = p
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var top := PanelContainer.new()
	box.add_child(top)
	hud = Label.new()
	top.add_child(hud)
	felt = Control.new()
	felt.custom_minimum_size = Vector2(0, 780)
	felt.clip_contents = true
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.draw.connect(_draw_table)
	box.add_child(felt)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.y = 136 # room for three lines, so the buttons never jump
	toast.text = tr("PK_WELCOME")
	box.add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for a in ["fold", "call", "raise", "allin"]:
		buttons[a] = Game.make_button(row, "", _act.bind(a))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	buttons["deal"] = Game.make_button(row2, "", _deal)
	buttons["leave"] = Game.make_button(row2, tr("PK_LEAVE_BTN"), _leave)
	buttons["back"] = Game.make_button(row2, tr("BTN_BACK_SHORT"), Game.back)
	for b in buttons.values():
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
	shown.stacks[0] = Game.state.pk_stack
	_refresh()


func _process(delta: float) -> void:
	t += delta
	felt.queue_redraw()


func _refresh() -> void:
	var s = Game.state
	var tb = s.table
	var live: bool = tb != null and tb.in_hand and not busy
	hud.text = tr("PK_HUD") % [s.money, shown.stacks[0]]
	var call: int = tb.to_call(0) if live else 0
	buttons.fold.text = tr("PK_FOLD_BTN")
	buttons.call.text = tr("PK_CALL_BTN") % call if call > 0 else tr("PK_CHECK_BTN")
	buttons.raise.text = tr("PK_RAISE_BTN") % (mini(call + tb.raise_by(), tb.stacks[0]) if live else 0)
	buttons.allin.text = tr("PK_ALLIN_BTN")
	for a in ["fold", "call", "raise", "allin"]:
		buttons[a].disabled = not live
	buttons.raise.disabled = not live or tb.raises >= tb.MAX_RAISES or tb.stacks[0] <= call
	var between: bool = not busy and (tb == null or not tb.in_hand)
	var seated: bool = s.pk_stack > 0
	buttons.deal.text = tr("PK_DEAL") if seated else tr("PK_SIT_BTN") % s.POKER_BUYIN
	buttons.deal.disabled = not between or (not seated and (s.money < s.POKER_BUYIN or s.shadowed or s.outfit() < s.CASINO_OUTFIT))
	buttons.leave.disabled = not between or not seated
	buttons.back.disabled = not between


func _deal() -> void:
	var s = Game.state
	if s.pk_stack == 0:
		var r: Dictionary = s.pk_sit()
		if r.is_empty():
			return
		Game.record(r)
		toast.text = Game.entry_text(r)
		shown.stacks[0] = s.pk_stack
		sfx["chips-stack-1"].play()
		_refresh()
		return
	if not s.pk_deal():
		return
	sfx["card-shuffle"].play()
	said = ["", "", "", ""]
	out = [false, false, false, false]
	reveal = false
	shown.board = 0
	toast.text = ""
	await _play()


func _act(action: String) -> void:
	Game.state.pk_act(action)
	await _play()


## Show what the rules already decided, one move at a time.
func _play() -> void:
	var s = Game.state
	var tb = s.table
	busy = true
	_refresh()
	for e in tb.events:
		shown.pot = e.pot
		shown.stacks = e.stacks
		if e.act == "street":
			shown.board = e.board
			said = ["", "", "", ""]
			sfx["card-slide-1"].play()
		elif e.act == "end":
			shown.board = e.board
			reveal = tb.result.showdown
		else:
			var who: String = tr(tb.BOTS[e.seat][0]) if e.seat > 0 else tr("PK_YOU")
			var line: String = tr("PK_ACT_" + e.act)
			line = line % ([who, e.amount] if line.count("%") == 2 else [who])
			if e.tell:
				line += " " + tr("PK_TELL")
				tug = t
			said[e.seat] = line
			out[e.seat] = e.act == "fold"
			if e.seat > 0:
				toast.text = line
			sfx["chips-collide-1"].play()
		_refresh()
		await get_tree().create_timer(STEP).timeout
	tb.events = []
	busy = false
	if not tb.in_hand:
		Game.record({"key": tb.result.key, "args": tb.result.args})
		toast.text = Game.entry_text(tb.result)
		if tb.result.net > 0:
			sfx["chips-stack-1"].play()
		if s.pk_stack < tb.BB: # felted
			_leave()
			return
	else:
		Game.record({}) # save the stack after every move
	_refresh()


func _leave() -> void:
	var r: Dictionary = Game.state.pk_leave()
	if r.is_empty():
		return
	Game.record(r)
	toast.text += ("\n" if toast.text != "" else "") + Game.entry_text(r)
	shown = {"pot": 0, "stacks": [0, 100, 100, 100], "board": 0}
	said = ["", "", "", ""]
	reveal = false
	_refresh()


# --- Drawing --------------------------------------------------------------

func _draw_table() -> void:
	var c := felt
	var sz := c.size
	var font := get_theme_default_font()
	var tb = Game.state.table
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#1a1016"))
	for i in 12: # a row of tired bulbs
		c.draw_circle(Vector2(30 + i * 60, 22), 5, Color("#ffd27a", 0.4 + 0.4 * sin(t * 2 + i)))
	# Oval table: rail, gold line, felt.
	for ring in [[1.0, Color("#5a2e14")], [0.965, Game.GOLD], [0.95, Game.GREEN.darkened(0.15)]]:
		c.draw_set_transform(Vector2(sz.x / 2, 440), 0, Vector2(1.0, 0.92) * ring[0])
		c.draw_circle(Vector2.ZERO, 350, ring[1])
	c.draw_set_transform(Vector2.ZERO)

	for seat in [1, 2, 3]:
		_draw_regular(seat, Vector2(SEAT_X[seat], 150 if seat != 2 else 110), tb)
	# Board and pot.
	var cards: Array = tb.board.slice(0, shown.board) if tb != null else []
	for i in 5:
		var p := Vector2(sz.x / 2 - 250 + i * 102, 330)
		if i < cards.size():
			_draw_card(p, cards[i], false, 1.0)
		else:
			c.draw_rect(Rect2(p, CARD), Color(0, 0, 0, 0.12))
	if shown.pot > 0:
		Table.draw_chip(c, Vector2(sz.x / 2 - 70, 500), 20, 25)
		_badge(Vector2(sz.x / 2 + 20, 500), tr("PK_POT") % shown.pot)
	# Larry's hand.
	if tb != null and not tb.hole[0].is_empty() and not out[0]:
		for i in 2:
			_draw_card(Vector2(sz.x / 2 - 100 + i * 104, 560), tb.hole[0][i], false, 1.0)
	if said[0] != "":
		_badge(Vector2(sz.x / 2, 545), said[0])
	_badge(Vector2(sz.x / 2, 730), "$%d" % shown.stacks[0])
	if tb != null:
		var d := Vector2(SEAT_X[tb.button] + (150 if tb.button == 0 else 0), 620 if tb.button == 0 else 300)
		c.draw_circle(d, 16, Game.IVORY)
		c.draw_string(font, d + Vector2(-7, 8), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Game.CHARCOAL)


func _draw_regular(seat: int, p: Vector2, tb) -> void:
	var c := felt
	var dim := 0.4 if out[seat] else 1.0
	var skin := Color("#e8b08c") * Color(dim, dim, dim)
	var body: Color = [Color.BLACK, Color("#c2185b"), Color("#1c1c24"), Color("#8e7cc3")][seat] * Color(dim, dim, dim)
	c.draw_rect(Rect2(p + Vector2(-52, 20), Vector2(104, 70)), body)
	c.draw_circle(p, 36, skin)
	match seat:
		1: # Big Sue: big hair, sunglasses, no expression
			c.draw_arc(p + Vector2(0, -6), 40, PI, TAU, 16, Color("#f2c230") * Color(dim, dim, dim), 22)
			c.draw_rect(Rect2(p + Vector2(-26, -10), Vector2(52, 14)), Color("#111"))
		2: # Reverend Al: white collar, and a hand that goes to it when he's lying
			var pull := clampf(1.0 - (t - tug) / 1.2, 0, 1) * sin((t - tug) * 18) * 5
			c.draw_rect(Rect2(p + Vector2(-14 + pull, 22), Vector2(28, 12)), Color.WHITE)
			c.draw_arc(p + Vector2(0, -8), 34, PI * 1.1, PI * 1.9, 12, Color("#555") * Color(dim, dim, dim), 8)
			for x in [-13, 13]:
				c.draw_circle(p + Vector2(x, -4), 4, Color("#2b1a10"))
			c.draw_arc(p + Vector2(0, 8), 12, 0.2, PI - 0.2, 10, Color("#8a4a3a"), 3) # always smiling
		3: # Grandma Ruth: grey bun, round glasses
			c.draw_circle(p + Vector2(0, -44), 18, Color("#cfcfd6") * Color(dim, dim, dim))
			c.draw_arc(p + Vector2(0, -6), 36, PI, TAU, 16, Color("#cfcfd6") * Color(dim, dim, dim), 12)
			for x in [-14, 14]:
				c.draw_arc(p + Vector2(x, -2), 10, 0, TAU, 16, Color("#3a2414"), 3)
			c.draw_arc(p + Vector2(0, 12), 8, 0.2, PI - 0.2, 8, Color("#8a4a3a"), 3)
	var name: String = tr(Game.state.PokerTable.BOTS[seat][0])
	_badge(p + Vector2(0, 108), "%s  $%d" % [name, shown.stacks[seat]])
	if tb != null and not tb.hole[seat].is_empty() and not out[seat]:
		for i in 2:
			_draw_card(p + Vector2(-50 + i * 52, 128), tb.hole[seat][i], not reveal, 0.5)
	if said[seat] != "" and not out[seat]:
		_badge(p + Vector2(0, -60), said[seat].trim_prefix(name + " "))


func _draw_card(p: Vector2, card: Array, face_down: bool, k: float) -> void:
	var c := felt
	c.draw_set_transform(p + CARD * k / 2, 0, Vector2(k, k))
	var r := Rect2(-CARD / 2, CARD)
	c.draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))
	_round_rect(r, Color.WHITE)
	if face_down:
		_round_rect(r.grow(-6), Game.BURGUNDY)
	else:
		var col := Color("#c8102e") if card[1] == 1 or card[1] == 2 else Color("#1c1c24")
		c.draw_string(get_theme_default_font(), r.position + Vector2(8, 34), RANKS[card[0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, col)
		_suit(Vector2(0, 22), card[1], 26, col)
	c.draw_set_transform(Vector2.ZERO)


func _round_rect(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	felt.draw_style_box(sb, r)


## Suits drawn as shapes: 0 spades, 1 hearts, 2 diamonds, 3 clubs (same shapes as the blackjack table).
func _suit(p: Vector2, suit: int, s: float, col: Color) -> void:
	var c := felt
	match suit:
		1, 0:
			var flip := -1.0 if suit == 0 else 1.0
			c.draw_circle(p + Vector2(-s * 0.5, -s * 0.3 * flip), s * 0.55, col)
			c.draw_circle(p + Vector2(s * 0.5, -s * 0.3 * flip), s * 0.55, col)
			c.draw_colored_polygon([p + Vector2(-s * 1.02, -s * 0.15 * flip), p + Vector2(s * 1.02, -s * 0.15 * flip), p + Vector2(0, s * 1.0 * flip)], col)
			if suit == 0:
				c.draw_colored_polygon([p + Vector2(0, s * 0.1), p + Vector2(-s * 0.45, s * 1.1), p + Vector2(s * 0.45, s * 1.1)], col)
		2:
			c.draw_colored_polygon([p + Vector2(0, -s), p + Vector2(s * 0.75, 0), p + Vector2(0, s), p + Vector2(-s * 0.75, 0)], col)
		3:
			c.draw_circle(p + Vector2(0, -s * 0.5), s * 0.48, col)
			c.draw_circle(p + Vector2(-s * 0.52, s * 0.15), s * 0.48, col)
			c.draw_circle(p + Vector2(s * 0.52, s * 0.15), s * 0.48, col)
			c.draw_colored_polygon([p + Vector2(0, 0), p + Vector2(-s * 0.4, s * 1.1), p + Vector2(s * 0.4, s * 1.1)], col)


func _badge(p: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_corner_radius_all(15)
	felt.draw_style_box(sb, Rect2(p + Vector2(-w / 2 - 12, -15), Vector2(w + 24, 30)))
	felt.draw_string(font, p + Vector2(-w / 2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#fff3c4"))
