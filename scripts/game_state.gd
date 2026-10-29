extends RefCounted
## Pure game rules, no UI. Results are {key, args} so the UI can tr() them in any language.

const FOOD_COST := 20
const RENT := 200
const RENT_EVERY := 7
const DAILY_INTEREST_PCT := 10
const DEBT_LIMIT := 2000
const LOAN_SIZE := 100
const WORK_PAY := 60
const TEAMS := 8
const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

# Sold in this order: [key, price]
const ITEMS := [
	["ITEM_IRON", 15], ["ITEM_MICROWAVE", 40], ["ITEM_GUITAR", 80],
	["ITEM_TV", 150], ["ITEM_WATCH", 300], ["ITEM_CAR", 1500],
]

var rng := RandomNumberGenerator.new()
var day := 1
var money := 100
var debt := 0
var items_sold := 0
var worked_today := false
var matches: Array = [] # [[home_team, away_team, home_win_chance], ...]


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_new_matches()


# --- Home -----------------------------------------------------------------

func work() -> Dictionary:
	if worked_today or is_over():
		return {}
	worked_today = true
	money += WORK_PAY
	return {"key": "WORK", "args": [WORK_PAY]}


func sell_next() -> Dictionary:
	if items_sold >= ITEMS.size() or is_over():
		return {}
	var item: Array = ITEMS[items_sold]
	items_sold += 1
	money += item[1]
	return {"key": "SELL_" + item[0], "args": [item[1]]}


func borrow() -> Dictionary:
	if is_over():
		return {}
	money += LOAN_SIZE
	debt += LOAN_SIZE
	return {"key": "BORROW", "args": [LOAN_SIZE]}


func repay() -> Dictionary:
	var amount := mini(money, debt)
	if amount <= 0 or is_over():
		return {}
	money -= amount
	debt -= amount
	return {"key": "REPAY", "args": [amount]}


func days_to_rent() -> int:
	return RENT_EVERY - (day - 1) % RENT_EVERY


func sleep() -> Array:
	if is_over():
		return []
	var log := []
	money = maxi(money - FOOD_COST, 0)
	debt += (debt * DAILY_INTEREST_PCT + 99) / 100 # integer ceil
	if days_to_rent() == 1:
		if money < RENT:
			return [{"key": "END_EVICTED", "args": []}]
		money -= RENT
		log.append({"key": "RENT_PAID", "args": [RENT]})
	day += 1
	worked_today = false
	_new_matches()
	var events := ["EVENT_QUIET", "EVENT_LUCKY_DREAM", "EVENT_FOUND_CHIP"]
	if debt > 0:
		events.append("EVENT_VINNIE")
	var event: String = events[rng.randi() % events.size()]
	match event:
		"EVENT_FOUND_CHIP": money += 25
		"EVENT_VINNIE": money -= mini(money, 50)
	log.append({"key": event, "args": []})
	return log


func is_over() -> bool:
	return debt >= DEBT_LIMIT


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
	if index < 0 or index >= matches.size() or amount <= 0 or amount > money or is_over():
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
	if amount <= 0 or amount > money or is_over():
		return {}
	money -= amount
	var n := rng.randi_range(0, 36)
	var payout := roulette_payout(bet, n)
	money += amount * payout
	return {"number": n, "win": amount * payout}


## bet is "red", "black", "even", "odd" or a number "0".."36". Returns the multiplier (incl. stake).
static func roulette_payout(bet: String, n: int) -> int:
	match bet:
		"red": return 2 if n in RED else 0
		"black": return 2 if n != 0 and not n in RED else 0
		"even": return 2 if n != 0 and n % 2 == 0 else 0
		"odd": return 2 if n % 2 == 1 else 0
	return 36 if bet.is_valid_int() and int(bet) == n else 0


# --- Save ----------------------------------------------------------------

const SAVED := ["day", "money", "debt", "items_sold", "worked_today", "matches"]


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
	for k in ["day", "money", "debt", "items_sold"]:
		set(k, int(get(k)))
	for m in matches:
		m[0] = int(m[0]); m[1] = int(m[1])
