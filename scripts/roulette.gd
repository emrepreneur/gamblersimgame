extends Control
## Roulette at the Golden Jackpot: drop chips on the felt, spin, watch the ball land.

const Wheel := preload("res://scripts/roulette_wheel.gd")
const Table := preload("res://scripts/roulette_table.gd")
const CHIPS := [5, 10, 25, 50, 100]

var wheel: Wheel
var table: Table
var hud: Label
var toast: Label
var spin_btn: Button
var clear_btn: Button
var chip_row: HBoxContainer
var chip := 10
var pending := 0 # winnings already in the state but not revealed yet
var sfx := {}
var coins: CPUParticles2D


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2a1f3d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for n in ["chips-handle-1", "chips-stack-1", "chips-collide-1", "dice-shake-1"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.ogg" % n)
		add_child(p)
		sfx[n] = p

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var top := PanelContainer.new()
	box.add_child(top)
	hud = Label.new()
	top.add_child(hud)

	wheel = Wheel.new()
	wheel.custom_minimum_size = Vector2(0, 520)
	wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(wheel)
	wheel.landed.connect(_on_landed)

	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.custom_minimum_size.y = 76
	toast.add_theme_color_override("font_color", Color("#fff3c4"))
	toast.add_theme_color_override("font_outline_color", Color("#1b1420"))
	toast.add_theme_constant_override("outline_size", 8)
	toast.text = tr("ROULETTE_PLACE")
	box.add_child(toast)

	table = Table.new()
	table.custom_minimum_size = Vector2(0, 230)
	box.add_child(table)
	table.bet_placed.connect(_on_bet)

	chip_row = HBoxContainer.new()
	chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chip_row.add_theme_constant_override("separation", 14)
	box.add_child(chip_row)
	for v in CHIPS:
		var c := Control.new()
		c.custom_minimum_size = Vector2(96, 96)
		c.draw.connect(func():
			var lift := -10.0 if v == chip else 0.0
			if v == chip:
				c.draw_circle(Vector2(48, 50), 46, Color("#f7d774", 0.6))
			Table.draw_chip(c, Vector2(48, 48 + lift), 40, v))
		c.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				chip = v
				sfx["chips-handle-1"].play()
				for k in chip_row.get_children(): k.queue_redraw())
		chip_row.add_child(c)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	clear_btn = Game.make_button(row, tr("ROULETTE_CLEAR"), _clear)
	spin_btn = Game.make_button(row, tr("ROULETTE_SPIN"), _spin)
	spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := Game.make_button(row, tr("BTN_BACK_SHORT"), Game.go.bind("world"))
	for b in [clear_btn, back]:
		b.custom_minimum_size.x = 150

	coins = CPUParticles2D.new()
	coins.emitting = false
	coins.one_shot = true
	coins.amount = 60
	coins.lifetime = 1.6
	coins.explosiveness = 0.9
	coins.spread = 180
	coins.initial_velocity_min = 350
	coins.initial_velocity_max = 750
	coins.gravity = Vector2(0, 1100)
	coins.angular_velocity_min = -400
	coins.angular_velocity_max = 400
	coins.scale_amount_min = 0.7
	coins.scale_amount_max = 1.2
	coins.texture = _coin_texture()
	add_child(coins)

	if Game.state.shadowed or Game.is_over():
		toast.text = tr("SHADOW_BOUNCER")
	_refresh()


func _staked() -> int:
	var t := 0
	for k in table.bets:
		t += table.bets[k]
	return t


func _refresh() -> void:
	hud.text = tr("ROULETTE_HUD") % [Game.state.money - pending, _staked()]
	var busy := wheel.spinning
	spin_btn.disabled = busy or table.bets.is_empty() or Game.state.shadowed
	clear_btn.disabled = busy or table.bets.is_empty()
	table.queue_redraw()


func _on_bet(bet: String) -> void:
	if wheel.spinning or Game.state.shadowed:
		return
	if table.highlight >= 0: # first chip after a spin clears the old result
		table.highlight = -1
	var amount := mini(chip, Game.state.money - _staked())
	if amount <= 0:
		toast.text = tr("ROULETTE_BROKE")
		return
	table.bets[bet] = table.bets.get(bet, 0) + amount
	sfx["chips-collide-1"].play()
	_refresh()


func _clear() -> void:
	table.bets.clear()
	_refresh()


func _spin() -> void:
	var bets := table.bets.duplicate()
	var result: Dictionary = Game.state.spin_roulette_bets(bets)
	if result.is_empty():
		return
	sfx["dice-shake-1"].play()
	toast.text = tr("ROULETTE_NO_MORE")
	table.highlight = -1
	pending = result.win
	wheel.spin_to(result.number)
	_refresh()
	await wheel.landed
	pending = 0
	var won: bool = result.win > 0
	var amount: int = result.win if won else result.staked
	toast.text = tr("SPIN_WIN" if won else "SPIN_LOSE") % [result.number, amount]
	Game.record({"key": "SPIN_WIN" if won else "SPIN_LOSE", "args": [result.number, amount]})
	table.highlight = result.number
	table.flash = 0.0
	table.bets.clear()
	if won:
		sfx["chips-stack-1"].play()
		coins.position = wheel.global_position + wheel.size / 2
		coins.restart()
		var t := create_tween()
		toast.scale = Vector2.ONE * 1.3
		toast.pivot_offset = toast.size / 2
		t.tween_property(toast, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	_refresh()


func _on_landed() -> void:
	sfx["chips-collide-1"].play()


static func _coin_texture() -> ImageTexture:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d < 13:
				var shade := 1.0 - (x + y) / 80.0
				var c := Color("#f7d774") if d < 9 else Color("#d49a1e")
				img.set_pixel(x, y, c * Color(shade, shade, shade, 1) if d < 12 else Color("#8a5a10"))
	return ImageTexture.create_from_image(img)
