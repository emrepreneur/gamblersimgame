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
	check(g.matches.size() == 3, "3 matches per day")
	check(g.bet_match(0, true, 0).is_empty() and g.bet_match(0, true, 999).is_empty(), "invalid bets rejected")
	g.bet_match(0, true, 10)
	check(g.matches.size() == 2, "one bet per match")
	g.work()
	check(g.work().is_empty(), "work once per day")
	check(g.sell_next().key == "SELL_ITEM_IRON", "iron sells first")
	g.borrow()
	var money_before := g.money
	g.sleep()
	check(g.debt == 110 and g.day == 2 and not g.worked_today and g.matches.size() == 3, "new day: interest, reset")
	check(g.money <= money_before - g.FOOD_COST + 25, "food is paid")

	# Rent: day 7 sleep pays rent or evicts.
	var r := GameState.new(2)
	r.day = 7; r.money = 50
	check(r.sleep()[0].key == "END_EVICTED", "evicted without rent")
	r.day = 7; r.money = 500
	check(r.sleep()[0].key == "RENT_PAID" and r.day == 8, "rent paid")

	# Roulette payouts.
	check(GameState.roulette_payout("red", 1) == 2 and GameState.roulette_payout("red", 2) == 0, "red")
	check(GameState.roulette_payout("black", 0) == 0 and GameState.roulette_payout("even", 0) == 0, "zero loses outside bets")
	check(GameState.roulette_payout("17", 17) == 36 and GameState.roulette_payout("17", 18) == 0, "straight number")

	# House edge on both games over many bets.
	var h := GameState.new(42)
	var spun := 0
	var sport := 0
	for i in 20000:
		h.money = 10
		spun += h.spin_roulette("red", 10).win - 10
		h.money = 10
		if h.matches.is_empty():
			h._new_matches()
		h.bet_match(0, i % 2 == 0, 10)
		sport += h.money - 10
	check(spun < 0, "roulette house edge (net %d)" % spun)
	check(sport < 0, "sports house edge (net %d)" % sport)

	# Save round trip.
	var a := GameState.new(3)
	a.money = 77; a.debt = 33; a.day = 5
	var b := GameState.new(4)
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	check(b.money == 77 and b.debt == 33 and b.day == 5 and str(b.matches) == str(a.matches), "save round trip")

	# Every key the code can emit must exist in the CSV.
	var csv := FileAccess.get_file_as_string("res://i18n/strings.csv")
	var keys := ["INTRO", "STATS", "WORK", "BORROW", "REPAY", "RENT_PAID", "EVENT_QUIET", "EVENT_LUCKY_DREAM",
		"EVENT_FOUND_CHIP", "EVENT_VINNIE", "END_EVICTED", "END_DEBT", "SPORT_WIN", "SPORT_LOSE_1",
		"SPORT_LOSE_2", "SPORT_NO_MATCHES", "SPIN_WIN", "SPIN_LOSE"]
	for item in GameState.ITEMS:
		keys.append_array([item[0], "SELL_" + item[0]])
	for t in GameState.TEAMS:
		keys.append("TEAM_%d" % t)
	for k in keys:
		check(csv.contains("\n" + k + ","), "missing translation " + k)

	print("tests: %s" % ("OK" if failed == 0 else "%d failed" % failed))
	quit(failed)
