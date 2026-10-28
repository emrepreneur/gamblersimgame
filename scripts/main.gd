extends Control
## Builds the UI in code and renders GameState. Log stores {key,args} so a language switch re-renders it.

const GameState := preload("res://scripts/game_state.gd")
const LOG_LINES := 8

var game: GameState
var log_entries: Array = []
var stats_label := Label.new()
var log_label := Label.new()
var buttons := {}


func _ready() -> void:
	if OS.get_locale_language() == "tr":
		TranslationServer.set_locale("tr")
	theme = Theme.new()
	theme.default_font_size = 30

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	box.add_child(stats_label)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(log_label)

	for id in ["BTN_BET_SMALL", "BTN_BET_ALL", "BTN_WORK", "BTN_SELL", "BTN_BORROW", "BTN_END_DAY", "BTN_RESTART", "BTN_LANGUAGE"]:
		var b := Button.new()
		b.custom_minimum_size.y = 88
		b.pressed.connect(_on_pressed.bind(id))
		box.add_child(b)
		buttons[id] = b

	_new_game()


func _new_game() -> void:
	game = GameState.new()
	log_entries = [{"key": "INTRO", "args": []}]
	_render()


func _on_pressed(id: String) -> void:
	var result := {}
	match id:
		"BTN_BET_SMALL": result = game.bet(mini(10, game.money))
		"BTN_BET_ALL": result = game.bet(game.money)
		"BTN_WORK": result = game.work()
		"BTN_SELL": result = game.sell_next()
		"BTN_BORROW": result = game.borrow()
		"BTN_END_DAY": result = game.end_day()
		"BTN_RESTART": _new_game(); return
		"BTN_LANGUAGE":
			TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("tr") else "tr")
	if not result.is_empty():
		log_entries.append(result)
	if game.ending() != "" and log_entries[-1].key != game.ending():
		log_entries.append({"key": game.ending(), "args": []})
	_render()


func _render() -> void:
	stats_label.text = tr("STATS") % [game.day, game.MAX_DAYS, game.money, game.debt, game.hope, game.family, game.actions_left]
	var lines := PackedStringArray()
	for e in log_entries.slice(-LOG_LINES):
		lines.append(tr(e.key) % e.args if e.args else tr(e.key))
	log_label.text = "\n\n".join(lines)

	var over := game.ending() != ""
	var acting := game.can_act()
	for id in buttons:
		buttons[id].text = tr(id)
	buttons.BTN_BET_ALL.text = tr("BTN_BET_ALL") % game.money
	buttons.BTN_BET_SMALL.disabled = not acting or game.money <= 0
	buttons.BTN_BET_ALL.disabled = not acting or game.money <= 0
	buttons.BTN_WORK.disabled = not acting
	buttons.BTN_SELL.disabled = not acting or game.items_left.is_empty()
	buttons.BTN_BORROW.disabled = not acting
	buttons.BTN_END_DAY.disabled = over
	buttons.BTN_RESTART.visible = over
