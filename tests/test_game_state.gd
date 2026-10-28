extends SceneTree
## Run: godot --headless --script res://tests/test_game_state.gd

const GameState := preload("res://scripts/game_state.gd")
var failed := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failed += 1
		printerr("FAIL: " + msg)


func _init() -> void:
	var g := GameState.new(1)
	check(g.bet(0).is_empty() and g.bet(999).is_empty(), "invalid bets rejected")
	g.bet(10)
	check(g.actions_left == 2, "bet uses a move")
	g.sell_next()
	check(g.sold == ["ITEM_IRON"], "iron sells first")
	g.borrow()
	check(not g.can_act() and g.work().is_empty(), "no moves left after 3 actions")
	g.end_day()
	check(g.debt == 110 and g.day == 2 and g.actions_left == 3, "interest + new day")

	# House edge: many small bets should lose money on average.
	var won := 0.0
	var h := GameState.new(42)
	for i in 20000:
		h.actions_left = 3; h.money = 10; h.hope = 50; h.family = 50
		h.bet(10)
		won += h.money - 10
	check(won < 0, "house edge holds (net %d)" % won)

	# Every key the logic can emit must exist in the CSV.
	var csv := FileAccess.get_file_as_string("res://i18n/strings.csv")
	var keys := ["BET_WIN", "BET_JACKPOT", "BET_LOSE_1", "BET_LOSE_2", "BET_LOSE_3", "WORK", "BORROW",
		"EVENT_QUIET", "EVENT_LUCKY_DREAM", "EVENT_MOM_MONEY", "EVENT_KID_DRAWING", "EVENT_WIFE_IRON",
		"EVENT_COLLECTOR", "END_ALONE", "END_HOPELESS", "END_DEBT", "END_SURVIVED"]
	for item in GameState.ITEMS:
		keys.append("SELL_" + item)
	for k in keys:
		check(csv.contains("\n" + k + ","), "missing translation " + k)

	print("tests: %s" % ("OK" if failed == 0 else "%d failed" % failed))
	quit(failed)
