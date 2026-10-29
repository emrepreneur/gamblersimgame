extends Control
## Quick bet: pick a side, see the result instantly.

func _ready() -> void:
	var s = Game.state
	var box := Game.make_screen(self)
	Game.make_label(box, Game.stats_text())
	Game.make_stake_row(box)

	if s.matches.is_empty():
		Game.make_label(box, tr("SPORT_NO_MATCHES"))
	for i in s.matches.size():
		var m: Array = s.matches[i]
		Game.make_label(box, "%s  vs  %s" % [tr("TEAM_%d" % m[0]), tr("TEAM_%d" % m[1])])
		var row := HBoxContainer.new()
		box.add_child(row)
		for home in [true, false]:
			var chance: float = m[2] if home else 1.0 - m[2]
			var b := Game.make_button(row, "%s  x%.2f" % [tr("TEAM_%d" % m[0 if home else 1]), s.odds(chance)], _bet.bind(i, home))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = Game.stake() <= 0 or Game.is_over()

	Game.make_label(box, Game.log_text(), true)
	Game.make_button(box, tr("BTN_BACK"), Game.go.bind("home"))


func _bet(index: int, home: bool) -> void:
	Game.record(Game.state.bet_match(index, home, Game.stake()))
	get_tree().reload_current_scene()
