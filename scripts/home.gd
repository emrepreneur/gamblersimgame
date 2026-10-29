extends Control
## Larry's motel room: stats, the log, and everything that isn't gambling.

func _ready() -> void:
	var s = Game.state
	var box := Game.make_screen(self)
	Game.make_label(box, Game.stats_text())
	Game.make_label(box, Game.log_text(), true)

	if Game.is_over():
		Game.make_button(box, tr("BTN_RESTART"), func(): Game.new_game(); _refresh())
	else:
		Game.make_button(box, tr("BTN_SPORTS"), Game.go.bind("sports"))
		Game.make_button(box, tr("BTN_ROULETTE"), Game.go.bind("roulette"))
		Game.make_button(box, tr("BTN_WORK") % s.WORK_PAY, _act.bind(s.work)).disabled = s.worked_today
		var has_items: bool = s.items_sold < s.ITEMS.size()
		var next_item: String = tr(s.ITEMS[s.items_sold][0]) if has_items else ""
		Game.make_button(box, tr("BTN_SELL") % next_item, _act.bind(s.sell_next)).disabled = not has_items
		Game.make_button(box, tr("BTN_BORROW") % s.LOAN_SIZE, _act.bind(s.borrow))
		Game.make_button(box, tr("BTN_REPAY"), _act.bind(s.repay)).disabled = s.debt == 0 or s.money == 0
		Game.make_button(box, tr("BTN_SLEEP"), _act.bind(s.sleep))
	Game.make_button(box, tr("BTN_LANGUAGE"), _toggle_language)


func _act(action: Callable) -> void:
	Game.record(action.call())
	_refresh()


func _toggle_language() -> void:
	TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("tr") else "tr")
	_refresh()


func _refresh() -> void:
	get_tree().reload_current_scene()
