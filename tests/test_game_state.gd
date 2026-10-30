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
	check(g.borrow(100).args == [100, 120, 5] and g.due_day == 6, "loan: +20%, due in 5 days")
	check(g.borrow(100).is_empty(), "one loan at a time")
	var money_before := g.money
	g.sleep()
	check(g.debt == 120 and g.day == 2 and not g.worked_today and g.matches.size() == 3, "new day resets, no daily interest")
	check(g.money <= money_before - g.FOOD_COST + 25, "food is paid")
	check(g.loan_limit() == 0, "no new loan while owing")

	# Pawn shop buy-back.
	var pw := GameState.new(10)
	pw.sell_next(); pw.sell_next() # iron $15, microwave $40
	check(pw.shelf.size() == 2 and pw.next_item() == "ITEM_GUITAR", "sold items go on Sal's shelf")
	pw.money = 100
	check(pw.buy_back("ITEM_MICROWAVE").args == ["ITEM_MICROWAVE", 60] and pw.money == 40, "buy back at +50%")
	check(pw.next_item() == "ITEM_MICROWAVE", "bought-back item returns in order")
	pw.money = 0
	check(pw.buy_back("ITEM_IRON").is_empty(), "can't afford buy-back")
	for i in pw.SHELF_DAYS + 1:
		pw.money = 500; pw.sleep()
	check(pw.shelf.is_empty(), "Sal sells unclaimed items after a while")
	var sv := GameState.new(11)
	sv.sell_next()
	var sv2 := GameState.new(12)
	sv2.from_dict(JSON.parse_string(JSON.stringify(sv.to_dict())))
	check(sv2.shelf == [["ITEM_IRON", 15, 1]] and sv2.owned.size() == sv.owned.size(), "shelf survives save")

	# Joey's visit.
	var v := GameState.new(5)
	v.borrow(100)
	check(not v.collection_due(), "Joey not due yet")
	v.day = v.due_day
	check(v.collection_due(), "Joey due on due day")
	v.money = 60
	var jr = v.pay_joey()
	check(jr.key == "JOEY_PAID_PART" and v.debt == 60 and v.due_day == v.day + 2, "half pays buys 2 days")
	v.day = v.due_day; v.money = 10
	jr = v.pay_joey()
	check(jr is Array and jr[1].key == "STEP_1" and v.step == 1 and v.rep < 50, "too little = ladder step 1")

	# Negotiation.
	var n := GameState.new(6)
	n.borrow(100); n.day = n.due_day
	check(n.negotiate("mom").key == "NEGO_MOM_OK" and n.negotiate("flatter").is_empty(), "one negotiation per deadline")
	var due_before := n.day
	check(n.accept_offer().key == "NEGO_DEAL" and n.debt == 132 and n.due_day == due_before + 3, "deal: 3 days, +10%")
	n.day = n.due_day; n.negotiated = false
	check(n.negotiate("mom").key == "NEGO_MOM_AGAIN", "mom excuse only works once")

	# Patience ladder all the way to the desert.
	var l := GameState.new(7)
	l.borrow(300); l.money = 0
	for i in 5:
		l.day = l.due_day
		l.sleep()
	check(l.step == 0 and l.debt == 0 and l.owned.is_empty() and l.money <= 25, "desert trip wipes everything")
	check(not l.is_over(), "desert trip is not game over")
	var sh := GameState.new(8)
	sh.borrow(100); sh.step = 3; sh._miss()
	check(sh.shadowed and sh.spin_roulette("red", 1).is_empty(), "shadowed: no casino")
	sh.money = 1000; sh.repay()
	check(not sh.shadowed and sh.step == 0, "paying off clears the ladder")

	# Rent: day 7 sleep pays rent or evicts.
	var r := GameState.new(2)
	r.day = 7; r.money = 50
	check(r.sleep()[0].key == "END_EVICTED" and r.is_over(), "evicted without rent")
	r.evicted = false
	r.day = 7; r.money = 500
	check(r.sleep()[0].key == "RENT_PAID" and r.day == 8, "rent paid")

	# Roulette payouts.
	check(GameState.roulette_payout("red", 1) == 2 and GameState.roulette_payout("red", 2) == 0, "red")
	check(GameState.roulette_payout("black", 0) == 0 and GameState.roulette_payout("even", 0) == 0, "zero loses outside bets")
	check(GameState.roulette_payout("17", 17) == 36 and GameState.roulette_payout("17", 18) == 0, "straight number")

	var mb := GameState.new(9)
	mb.money = 100
	var res := mb.spin_roulette_bets({"red": 10, "black": 10, "0": 10})
	check(res.staked == 30 and mb.money == 70 + res.win, "multi-bet: one spin, one payout")
	check(mb.spin_roulette_bets({"red": 500}).is_empty(), "can't bet more than cash")

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
		"EVENT_FOUND_CHIP", "END_EVICTED", "SPORT_WIN", "SPORT_LOSE_1",
		"SPORT_LOSE_2", "SPORT_NO_MATCHES", "SPIN_WIN", "SPIN_LOSE"]
	# Every key literal in the rules file.
	var src := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	var re := RegEx.create_from_string('"key": "([A-Z_0-9]+)"')
	for m in re.search_all(src):
		if not m.get_string(1).ends_with("_"): keys.append(m.get_string(1))
	keys.append_array(["PAWN_SHELF", "BTN_BUYBACK", "STEP_3_1", "STEP_3_2", "STEP_3_3", "NEGO_OFFER", "JOEY_HERE", "STATS_DUE", "PLACE_JOEY"])
	for item in GameState.ITEMS:
		keys.append_array([item[0], "SELL_" + item[0]])
	for t in GameState.TEAMS:
		keys.append("TEAM_%d" % t)
	for k in keys:
		check(csv.contains("\n" + k + ","), "missing translation " + k)

	print("tests: %s" % ("OK" if failed == 0 else "%d failed" % failed))
	quit(failed)
