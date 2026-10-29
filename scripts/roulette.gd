extends Control
## Roulette mini game: choose a bet, watch the number roll, get paid (or not).

const SPIN_TIME := 2.0

var wheel: Label
var number_pick: SpinBox
var bet_buttons: Array = []


func _ready() -> void:
	var box := Game.make_screen(self)
	Game.make_label(box, Game.stats_text())
	Game.make_stake_row(box)

	wheel = Game.make_label(box, "?")
	wheel.add_theme_font_size_override("font_size", 140)
	wheel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for bet in ["red", "black", "even", "odd"]:
		bet_buttons.append(Game.make_button(grid, tr("ROULETTE_" + bet.to_upper()), _spin.bind(bet)))
	number_pick = SpinBox.new()
	number_pick.max_value = 36
	number_pick.custom_minimum_size.y = 80
	grid.add_child(number_pick)
	bet_buttons.append(Game.make_button(grid, tr("ROULETTE_NUMBER"), func(): _spin(str(int(number_pick.value)))))
	for b in bet_buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = Game.stake() <= 0 or Game.is_over()

	Game.make_label(box, Game.log_text(), true)
	Game.make_button(box, tr("BTN_BACK"), Game.go.bind("world"))


func _spin(bet: String) -> void:
	var amount := Game.stake()
	var result: Dictionary = Game.state.spin_roulette(bet, amount)
	if result.is_empty():
		return
	for b in bet_buttons:
		b.disabled = true
	# Fake rolling numbers that slow down, then land on the real result.
	var tween := create_tween()
	tween.tween_method(func(_t): wheel.text = str(randi_range(0, 36)), 0.0, 1.0, SPIN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	wheel.text = str(result.number)
	var key := "SPIN_WIN" if result.win > 0 else "SPIN_LOSE"
	Game.record({"key": key, "args": [result.number, result.win if result.win > 0 else amount]})
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
