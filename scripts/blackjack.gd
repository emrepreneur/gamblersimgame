extends Control
## Blackjack with Dolores, drawn in code: felt table, dealer, cards with hand-drawn suits.

const Table := preload("res://scripts/roulette_table.gd")
const CHIPS := [5, 10, 25, 50, 100]
const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const CARD := Vector2(96, 134)

var felt: Control
var hud: Label
var toast: Label
var chip := 10
var player: Array = [] # cards shown on the table
var dealer: Array = []
var hide_hole := false
var dealt := {} # card id -> time it landed, for the slide-in
var t := 0.0
var busy := false
var pending := 0
var deal_btn: Button
var hit_btn: Button
var stand_btn: Button
var double_btn: Button
var chip_row: HBoxContainer
var sfx := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2a1f3d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for n in ["card-place-1", "card-slide-1", "card-shuffle", "chips-stack-1", "chips-collide-1"]:
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
	felt.custom_minimum_size = Vector2(0, 760)
	felt.clip_contents = true
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.draw.connect(_draw_table)
	box.add_child(felt)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.y = 64
	toast.add_theme_color_override("font_color", Color("#fff3c4"))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.text = tr("BJ_PLACE")
	box.add_child(toast)

	chip_row = HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 12)
	box.add_child(chip_row)
	for v in CHIPS:
		var c := Control.new()
		c.custom_minimum_size = Vector2(84, 80)
		c.draw.connect(func():
			if v == chip:
				c.draw_circle(Vector2(42, 42), 40, Color("#f7d774", 0.7))
			Table.draw_chip(c, Vector2(42, 40 if v != chip else 34), 34, v))
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and not busy and Game.state.bj.is_empty():
				chip = v
				sfx["chips-collide-1"].play()
				for k in chip_row.get_children(): k.queue_redraw())
		chip_row.add_child(c)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	deal_btn = Game.make_button(row, tr("BJ_DEAL"), _deal)
	hit_btn = Game.make_button(row, tr("BJ_HIT_BTN"), _act.bind("hit"))
	stand_btn = Game.make_button(row, tr("BJ_STAND_BTN"), _act.bind("stand"))
	double_btn = Game.make_button(row, tr("BJ_DOUBLE_BTN"), _act.bind("double"))
	for b in [deal_btn, hit_btn, stand_btn, double_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
	Game.make_button(box, tr("BTN_BACK_SHORT"), Game.go.bind("world"))
	# A hand left open (e.g. app closed mid-hand) is shown as it was.
	if not Game.state.bj.is_empty():
		player = Game.state.bj.player.duplicate()
		dealer = Game.state.bj.dealer.duplicate()
		hide_hole = true
	_refresh()


func _refresh() -> void:
	var s = Game.state
	var bet: int = s.bj.get("bet", 0)
	hud.text = tr("ROULETTE_HUD") % [s.money - pending, bet]
	var in_hand: bool = not s.bj.is_empty()
	deal_btn.disabled = busy or in_hand or s.money <= 0 or s.shadowed
	hit_btn.disabled = busy or not in_hand
	stand_btn.disabled = busy or not in_hand
	double_btn.disabled = busy or not in_hand or s.bj.player.size() != 2 or s.money < bet
	felt.queue_redraw()


func _process(delta: float) -> void:
	t += delta
	felt.queue_redraw()


func _land(card: Array, to_player: bool) -> void:
	(player if to_player else dealer).append(card)
	dealt[_id(card)] = t
	sfx["card-place-1"].play()
	await get_tree().create_timer(0.35).timeout


func _id(card: Array) -> String:
	return "%d-%d" % card


func _deal() -> void:
	var s = Game.state
	var amount := mini(chip, s.money)
	var r: Dictionary = s.bj_deal(amount)
	if r.is_empty():
		return
	busy = true
	player.clear(); dealer.clear(); dealt.clear()
	sfx["card-shuffle"].play()
	hide_hole = true
	var hands := [r.player, r.dealer] if r.has("player") else [s.bj.player, s.bj.dealer]
	pending = r.get("paid", 0)
	_refresh()
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		await _land(hands[0][i], true)
		await _land(hands[1][i], false)
	if r.has("player"): # natural blackjack on the deal
		await _finish(r)
	else:
		toast.text = tr("BJ_DEALT")
	busy = false
	_refresh()


func _act(what: String) -> void:
	var s = Game.state
	var before: int = s.bj.player.size()
	var r: Dictionary
	match what:
		"hit": r = s.bj_hit()
		"stand": r = s.bj_stand()
		"double": r = s.bj_double()
	if r.is_empty():
		return
	busy = true
	pending = r.get("paid", 0)
	_refresh()
	var final_player: Array = r.player if r.has("player") else s.bj.player
	for i in range(before, final_player.size()):
		await _land(final_player[i], true)
	if r.has("player"):
		await _finish(r)
	else:
		toast.text = Game.entry_text(r)
	busy = false
	_refresh()


## Reveal the hole card, let Dolores draw, then show the result.
func _finish(r: Dictionary) -> void:
	hide_hole = false
	sfx["card-slide-1"].play()
	await get_tree().create_timer(0.5).timeout
	for i in range(dealer.size(), r.dealer.size()):
		await _land(r.dealer[i], false)
	pending = 0
	Game.record({"key": r.key, "args": r.args})
	toast.text = Game.entry_text(r)
	if r.paid > 0:
		sfx["chips-stack-1"].play()


# --- Drawing --------------------------------------------------------------

func _draw_table() -> void:
	var c := felt
	var sz := c.size
	var font := get_theme_default_font()
	# Casino wall and Dolores.
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("#2a1f3d"))
	# Felt: a wide arc with a gold rail.
	var centre := Vector2(sz.x / 2, -260)
	c.draw_circle(centre, 1000, Color("#5a2e14"))
	c.draw_circle(centre, 985, Color("#e8b923"))
	c.draw_circle(centre, 978, Color("#0f6b3a"))
	c.draw_rect(Rect2(0, 0, sz.x, 230), Color("#3a1f3d")) # wall in front of the far edge
	for i in 12:
		c.draw_circle(Vector2(30 + i * 60, 30), 6, Color("#ffd27a", 0.5 + 0.5 * sin(t * 2 + i)))
	_draw_dolores(Vector2(sz.x / 2, 250))
	c.draw_rect(Rect2(0, 230, sz.x, 14), Color("#5a2e14"))
	var lines := tr("BJ_FELT")
	var w := font.get_string_size(lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	c.draw_string(font, Vector2((sz.x - w) / 2, 470), lines, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#f7d774", 0.6))
	# Shoe.
	c.draw_rect(Rect2(sz.x - 120, 270, 90, 70), Color("#2b1a10"))
	c.draw_rect(Rect2(sz.x - 112, 276, 74, 50), Color("#b22234"))

	# Hands.
	_draw_hand(dealer, Vector2(sz.x / 2, 300), true)
	_draw_hand(player, Vector2(sz.x / 2, 520), false)
	if not dealer.is_empty():
		var dv: int = Game.state.hand_value([dealer[0]]) if hide_hole else Game.state.hand_value(dealer)
		_badge(Vector2(sz.x / 2, 290), str(dv) + ("+" if hide_hole else ""))
	if not player.is_empty():
		_badge(Vector2(sz.x / 2, 680), str(Game.state.hand_value(player)))
	# Bet chip in the circle.
	var bet: int = Game.state.bj.get("bet", 0)
	c.draw_arc(Vector2(sz.x / 2, 715), 34, 0, TAU, 32, Color("#f7d774", 0.5), 3)
	if bet > 0:
		Table.draw_chip(c, Vector2(sz.x / 2, 715), 28, bet)


func _draw_hand(cards: Array, centre: Vector2, is_dealer: bool) -> void:
	var n := cards.size()
	var gap := minf(70.0, 520.0 / maxf(n, 1))
	var start := centre.x - (gap * (n - 1) + CARD.x) / 2
	for i in n:
		var target := Vector2(start + i * gap, centre.y)
		var landed: float = dealt.get(_id(cards[i]), -10.0)
		var k := clampf((t - landed) / 0.25, 0, 1)
		var from := Vector2(felt.size.x - 80, 280)
		var p := from.lerp(target, 1.0 - pow(1.0 - k, 3))
		var face_down := is_dealer and i == 1 and hide_hole
		_draw_card(p, cards[i], face_down, (1.0 - k) * 0.6)


func _draw_card(p: Vector2, card: Array, face_down: bool, spin: float) -> void:
	var c := felt
	c.draw_set_transform(p + CARD / 2, spin, Vector2.ONE)
	var r := Rect2(-CARD / 2, CARD)
	c.draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))
	_round_rect(r, Color.WHITE)
	if face_down:
		_round_rect(r.grow(-6), Color("#b22234"))
		for k in 7:
			c.draw_line(r.position + Vector2(10, 14 + k * 16), r.position + Vector2(CARD.x - 10, 6 + k * 16), Color("#d9475a"), 3)
	else:
		var red: bool = card[1] == 1 or card[1] == 2
		var col := Color("#c8102e") if red else Color("#1c1c24")
		var font := get_theme_default_font()
		var rank: String = RANKS[card[0]]
		c.draw_string(font, r.position + Vector2(8, 30), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)
		_suit(r.position + Vector2(20, 46), card[1], 9, col)
		_suit(Vector2(0, 14), card[1], 26, col)
	c.draw_set_transform(Vector2.ZERO)


func _round_rect(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	felt.draw_style_box(sb, r)


## Suits drawn as shapes: 0 spades, 1 hearts, 2 diamonds, 3 clubs.
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
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var r := Rect2(p + Vector2(-w / 2 - 12, -16), Vector2(w + 24, 34))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.7)
	sb.set_corner_radius_all(17)
	felt.draw_style_box(sb, r)
	felt.draw_string(font, p + Vector2(-w / 2, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#fff3c4"))


## Dolores: big hair, red vest, bow tie, seen-it-all eyes. She blinks.
func _draw_dolores(base: Vector2) -> void:
	var c := felt
	c.draw_rect(Rect2(base + Vector2(-80, -110), Vector2(160, 110)), Color("#f4efe4")) # shirt
	c.draw_colored_polygon([base + Vector2(-80, -110), base + Vector2(-20, -110), base + Vector2(-8, 0), base + Vector2(-80, 0)], Color("#a4161a"))
	c.draw_colored_polygon([base + Vector2(80, -110), base + Vector2(20, -110), base + Vector2(8, 0), base + Vector2(80, 0)], Color("#a4161a"))
	c.draw_colored_polygon([base + Vector2(-16, -108), base + Vector2(0, -100), base + Vector2(-16, -92)], Color("#111"))
	c.draw_colored_polygon([base + Vector2(16, -108), base + Vector2(0, -100), base + Vector2(16, -92)], Color("#111"))
	c.draw_rect(Rect2(base + Vector2(-12, -128), Vector2(24, 22)), Color("#e0a982")) # neck
	c.draw_circle(base + Vector2(0, -150), 62, Color("#7a2e8a")) # hair
	c.draw_circle(base + Vector2(0, -205), 40, Color("#7a2e8a"))
	c.draw_circle(base + Vector2(0, -150), 40, Color("#e8b08c")) # face
	var blink := fmod(t, 3.5) < 0.12
	for x in [-15, 15]:
		if blink:
			c.draw_line(base + Vector2(x - 7, -156), base + Vector2(x + 7, -156), Color("#3a2414"), 3)
		else:
			c.draw_circle(base + Vector2(x, -156), 5, Color("#3a2414"))
			c.draw_line(base + Vector2(x - 9, -164), base + Vector2(x + 9, -162), Color("#5a2e3a"), 3) # unimpressed lids
	c.draw_line(base + Vector2(-12, -130), base + Vector2(12, -130), Color("#b23a48"), 4) # flat mouth
	c.draw_circle(base + Vector2(-40, -140), 6, Color("#f7d774")) # earrings
	c.draw_circle(base + Vector2(40, -140), 6, Color("#f7d774"))
	c.draw_rect(Rect2(base + Vector2(-50, -60), Vector2(36, 14)), Color("#f7d774")) # name tag
