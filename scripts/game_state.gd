extends RefCounted
## Pure game rules, no UI. Results are {key, args} so the UI can tr() them in any language.

const FOOD_COST := 20
const RENT := 200
const RENT_EVERY := 7
const WORK_PAY := 60
const TEAMS := 8
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Vinnie
const LOAN_DAYS := 5
const LOAN_FEE_PCT := 20
const GRACE_DAYS := 3 # new deadline after a missed one
const LAST_STEP := 5 # desert trip

const BUYBACK_PCT := 150 # Sal's markup to buy an item back
const SHELF_DAYS := 5 # then Sal sells it to someone else

# Sold in this order: [key, price]
const ITEMS := [
	["ITEM_IRON", 15], ["ITEM_MICROWAVE", 40], ["ITEM_GUITAR", 80],
	["ITEM_TV", 150], ["ITEM_WATCH", 300], ["ITEM_CAR", 1500],
]

var rng := RandomNumberGenerator.new()
var day := 1
var money := 100
var debt := 0
var owned: Array = ITEMS.map(func(i): return i[0]) # item keys Larry still has, in sell order
var shelf: Array = [] # at Sal's: [key, price Sal paid, day sold]
var worked_today := false
var evicted := false
var matches: Array = [] # [[home_team, away_team, home_win_chance], ...]

var due_day := 0 # day Joey comes; 0 = no loan
var step := 0 # patience ladder, 0..LAST_STEP
var rep := 50 # Vinnie's opinion of Larry, 0..100
var used_mom := false # the hospital excuse only works once
var negotiated := false # one negotiation per deadline
var offer: Array = [] # Vinnie's current [days, pct], empty when none
var shadowed := false # Joey follows Larry; no casino, no betting shop


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_new_matches()


func is_over() -> bool:
	return evicted


# --- Town -----------------------------------------------------------------

func work() -> Dictionary:
	if worked_today or is_over():
		return {}
	worked_today = true
	money += WORK_PAY
	return {"key": "WORK", "args": [WORK_PAY]}


static func item_value(key: String) -> int:
	for i in ITEMS:
		if i[0] == key:
			return i[1]
	return 0


func next_item() -> String:
	return owned[0] if not owned.is_empty() else ""


func next_item_value() -> int:
	return item_value(next_item())


## Removes and returns Larry's next item key ("" if he has nothing left).
func _take_next() -> String:
	return owned.pop_front() if not owned.is_empty() else ""


func sell_next() -> Dictionary:
	if owned.is_empty() or is_over():
		return {}
	var key := _take_next()
	var price := item_value(key)
	money += price
	shelf.append([key, price, day])
	return {"key": "SELL_" + key, "args": [price]}


static func buyback_price(price_paid: int) -> int:
	return price_paid * BUYBACK_PCT / 100


func buy_back(key: String) -> Dictionary:
	for i in shelf.size():
		if shelf[i][0] != key:
			continue
		var cost := buyback_price(shelf[i][1])
		if cost > money or is_over():
			return {}
		money -= cost
		shelf.remove_at(i)
		owned.append(key)
		var order := ITEMS.map(func(it): return it[0])
		owned.sort_custom(func(a, b): return order.find(a) < order.find(b))
		return {"key": "BUYBACK", "args": [key, cost]}
	return {}


func days_to_rent() -> int:
	return RENT_EVERY - (day - 1) % RENT_EVERY


func sleep() -> Array:
	if is_over():
		return []
	var log := []
	if collection_due():
		log.append(_miss()) # going to bed instead of facing Joey counts as missing him
	money = maxi(money - FOOD_COST, 0)
	if days_to_rent() == 1:
		if money < RENT:
			evicted = true
			return log + [{"key": "END_EVICTED", "args": []}]
		money -= RENT
		log.append({"key": "RENT_PAID", "args": [RENT]})
	day += 1
	for i in range(shelf.size() - 1, -1, -1):
		if day - shelf[i][2] > SHELF_DAYS:
			log.append({"key": "PAWN_GONE", "args": [shelf[i][0]]})
			shelf.remove_at(i)
	worked_today = false
	negotiated = false
	offer = []
	_new_matches()
	if due_day == day + 1:
		log.append({"key": "VINNIE_TEXT", "args": []})
	var event: String = ["EVENT_QUIET", "EVENT_LUCKY_DREAM", "EVENT_FOUND_CHIP"][rng.randi() % 3]
	if event == "EVENT_FOUND_CHIP":
		money += 25
	log.append({"key": event, "args": []})
	return log


# --- Vinnie: loans --------------------------------------------------------

## Biggest loan Vinnie will give right now. Grows with reputation.
func loan_limit() -> int:
	return 0 if debt > 0 or step >= 3 else 100 + rep * 4


func borrow(amount: int) -> Dictionary:
	if amount <= 0 or amount > loan_limit() or is_over():
		return {}
	money += amount
	debt = amount + amount * LOAN_FEE_PCT / 100
	due_day = day + LOAN_DAYS
	return {"key": "BORROW", "args": [amount, debt, LOAN_DAYS]}


func repay() -> Dictionary:
	var amount := mini(money, debt)
	if amount <= 0 or is_over():
		return {}
	money -= amount
	debt -= amount
	if debt == 0:
		_cleared(10)
		return {"key": "REPAY_ALL", "args": [amount]}
	return {"key": "REPAY", "args": [amount, debt]}


func _cleared(rep_gain: int) -> void:
	rep = clampi(rep + rep_gain, 0, 100)
	due_day = 0
	step = 0
	shadowed = false
	offer = []


# --- Vinnie: Joey's visit -------------------------------------------------

func collection_due() -> bool:
	return debt > 0 and day >= due_day and not is_over()


## Pay what you can. Half or more buys 2 days, less is a miss.
func pay_joey(): # -> Dictionary, or [result, ladder step] on a miss
	if not collection_due() or money <= 0:
		return {}
	var paid := mini(money, debt)
	var half := (debt + 1) / 2
	money -= paid
	debt -= paid
	if debt == 0:
		_cleared(10)
		return {"key": "JOEY_PAID_ALL", "args": [paid]}
	if paid >= half:
		due_day = day + 2
		return {"key": "JOEY_PAID_PART", "args": [paid, debt]}
	return [{"key": "JOEY_PAID_LITTLE", "args": [paid]}, _miss()]


## Vinnie takes the next item at half its value.
func give_collateral() -> Dictionary:
	if not collection_due() or owned.is_empty():
		return {}
	var item := [_take_next(), 0]
	item[1] = item_value(item[0])
	var value: int = mini(item[1] / 2, debt)
	debt -= value
	if debt == 0:
		_cleared(5)
		return {"key": "JOEY_COLLATERAL_ALL", "args": [item[0], value]}
	due_day = day + 2
	return {"key": "JOEY_COLLATERAL", "args": [item[0], value, debt]}


func run_from_joey(): # -> Dictionary, or [result, ladder step]
	if not collection_due():
		return {}
	rep = maxi(rep - 10, 0)
	if rng.randf() < 0.5:
		due_day = day + 1
		return {"key": "JOEY_ESCAPED", "args": []}
	return [{"key": "JOEY_CAUGHT", "args": []}, _miss()]


## line: "tip", "mom" or "flatter". Sets Vinnie's offer [days, pct].
func negotiate(line: String) -> Dictionary:
	if not collection_due() or negotiated:
		return {}
	negotiated = true
	var key := ""
	match line:
		"tip":
			if rng.randf() < rep / 100.0:
				offer = [3, 10]; key = "NEGO_TIP_OK"
			else:
				offer = [1, 25]; key = "NEGO_TIP_BAD"
		"mom":
			if used_mom:
				rep = maxi(rep - 15, 0)
				offer = [1, 30]; key = "NEGO_MOM_AGAIN"
			else:
				used_mom = true
				offer = [3, 10]; key = "NEGO_MOM_OK"
		"flatter":
			offer = [2, 15]; key = "NEGO_FLATTER"
		_:
			negotiated = false
			return {}
	return {"key": key, "args": offer.duplicate()}


## Push for a better deal: Vinnie improves it or walks away.
func push_offer(): # -> Dictionary, or [result, ladder step]
	if offer.is_empty():
		return {}
	if rng.randf() < 0.5:
		offer = [offer[0] + 1, maxi(offer[1] - 5, 0)]
		return {"key": "NEGO_PUSH_OK", "args": offer.duplicate()}
	return [{"key": "NEGO_WALKED", "args": []}, _miss()]


func accept_offer() -> Dictionary:
	if offer.is_empty():
		return {}
	debt += (debt * offer[1] + 99) / 100 # integer ceil
	due_day = day + offer[0]
	var r := {"key": "NEGO_DEAL", "args": [offer[0], debt]}
	offer = []
	return r


## One step up the patience ladder. Returns the consequence.
func _miss() -> Dictionary:
	step = mini(step + 1, LAST_STEP)
	rep = maxi(rep - 10, 0)
	due_day = day + GRACE_DAYS
	offer = []
	match step:
		1: # Joey empties Larry's pockets
			var took := mini(money, debt)
			money -= took
			debt -= took
			if debt == 0:
				_cleared(0)
			return {"key": "STEP_1", "args": [took]}
		2: # an item vanishes from the motel
			if not owned.is_empty():
				var item := [_take_next(), 0]
				item[1] = item_value(item[0])
				var value: int = mini(item[1] / 2, debt)
				debt -= value
				if debt == 0:
					_cleared(0)
				return {"key": "STEP_2", "args": [item[0], value]}
			return {"key": "STEP_2_NOTHING", "args": []}
		3: # a favour for Vinnie takes the day and knocks some debt off
			var off := mini(debt, 100)
			debt -= off
			worked_today = true
			if debt == 0:
				_cleared(0)
			return {"key": "STEP_3_%d" % rng.randi_range(1, 3), "args": [off]}
		4:
			shadowed = true
			return {"key": "STEP_4", "args": []}
	# Desert trip: everything gone, debt wiped, start from the bottom.
	money = 0
	owned.clear()
	debt = 0
	_cleared(0)
	rep = 20
	return {"key": "STEP_5", "args": []}


# --- Sports betting (quick bet) ------------------------------------------

func _new_matches() -> void:
	matches.clear()
	var teams := range(TEAMS)
	for i in 3:
		var a: int = teams.pop_at(rng.randi() % teams.size())
		var b: int = teams.pop_at(rng.randi() % teams.size())
		matches.append([a, b, snappedf(rng.randf_range(0.25, 0.75), 0.01)])


## Decimal odds with a ~8% house margin.
static func odds(chance: float) -> float:
	return snappedf(0.92 / chance, 0.01)


func bet_match(index: int, home: bool, amount: int) -> Dictionary:
	if index < 0 or index >= matches.size() or amount <= 0 or amount > money or is_over() or shadowed:
		return {}
	var m: Array = matches.pop_at(index) # one bet per match
	var chance: float = m[2] if home else 1.0 - m[2]
	money -= amount
	if rng.randf() < chance:
		var win := int(amount * odds(chance))
		money += win
		return {"key": "SPORT_WIN", "args": [win]}
	return {"key": "SPORT_LOSE_%d" % rng.randi_range(1, 2), "args": [amount]}


# --- Roulette (mini game, European single zero) --------------------------

func spin_roulette(bet: String, amount: int) -> Dictionary:
	return spin_roulette_bets({bet: amount})


## Several chips on the table, one spin. bets: {bet: amount}. Returns {number, win, staked}.
func spin_roulette_bets(bets: Dictionary) -> Dictionary:
	var staked := 0
	for b in bets:
		if bets[b] <= 0:
			return {}
		staked += bets[b]
	if staked <= 0 or staked > money or is_over() or shadowed:
		return {}
	money -= staked
	var n := rng.randi_range(0, 36)
	var win := 0
	for b in bets:
		win += bets[b] * roulette_payout(b, n)
	money += win
	return {"number": n, "win": win, "staked": staked}


## bet is "red", "black", "even", "odd" or a number "0".."36". Returns the multiplier (incl. stake).
static func roulette_payout(bet: String, n: int) -> int:
	match bet:
		"red": return 2 if n in RED else 0
		"black": return 2 if n != 0 and not n in RED else 0
		"even": return 2 if n != 0 and n % 2 == 0 else 0
		"odd": return 2 if n % 2 == 1 else 0
	return 36 if bet.is_valid_int() and int(bet) == n else 0


# --- Save ----------------------------------------------------------------

const SAVED := ["day", "money", "debt", "owned", "shelf", "worked_today", "evicted", "matches",
	"due_day", "step", "rep", "used_mom", "negotiated", "offer", "shadowed"]


func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	return d


func from_dict(d: Dictionary) -> void:
	for k in SAVED:
		if d.has(k):
			set(k, d[k])
	# JSON turns ints into floats
	for k in ["day", "money", "debt", "due_day", "step", "rep"]:
		set(k, int(get(k)))
	offer = offer.map(func(v): return int(v))
	shelf = shelf.map(func(e): return [e[0], int(e[1]), int(e[2])])
	for m in matches:
		m[0] = int(m[0]); m[1] = int(m[1])
