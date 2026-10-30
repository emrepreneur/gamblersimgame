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
	["ITEM_BLAZER", 40], ["ITEM_SUIT", 200], # not owned at start; bought from Sal's rack
]
const START_ITEMS := 6
# Homes: [key, price to move in, weekly rent]. Can't pay rent: drop one level (eviction only from the motel).
const HOMES := [["HOME_MOTEL", 0, 200], ["HOME_FLAT", 1000, 350], ["HOME_SUITE", 5000, 800], ["HOME_RANCH", 25000, 1500]]
const LOAN_PER_HOME := 200 # Vinnie lends more to a man with an address
const EVENT_PCT := 40
const EVENTS := ["EV_EARL", "EV_TIP", "EV_MOM", "EV_PARCEL", "EV_EX", "EV_SAL", "EV_MEETING", "EV_ROACH"]
const OUTFITS := {"ITEM_BLAZER": 80, "ITEM_SUIT": 400} # Sal's rack prices
const CASINO_OUTFIT := 1 # blazer or better to get past Tiny

var rng := RandomNumberGenerator.new()
var day := 1
var money := 100
var debt := 0
var owned: Array = ITEMS.slice(0, START_ITEMS).map(func(i): return i[0]) # item keys Larry has, in ITEMS order
var taken: Array = [] # items Vinnie's people took (the motel room shows a note)
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
var home := 0 # index into HOMES
var badges: Array = [] # earned badge keys
var event := "" # morning event waiting for Larry's choice
var event_arg := 0 # e.g. the team in the cousin's tip
var escaped_joey := false


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_new_matches()
	_new_field()


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
	return sell(next_item())


func sell(key: String) -> Dictionary:
	if not key in owned or is_over():
		return {}
	owned.erase(key)
	var price := item_value(key)
	money += price
	shelf.append([key, price, day])
	return {"key": "SELL_" + key, "args": [price]}


## 0 tracksuit, 1 blazer, 2 suit.
func outfit() -> int:
	return 2 if "ITEM_SUIT" in owned else (1 if "ITEM_BLAZER" in owned else 0)


func buy_outfit(key: String) -> Dictionary:
	if not OUTFITS.has(key) or key in owned or money < OUTFITS[key] or is_over():
		return {}
	money -= OUTFITS[key]
	_give(key)
	return {"key": "OUTFIT_BOUGHT", "args": [key, OUTFITS[key]]}


func _give(key: String) -> void:
	owned.append(key)
	var order := ITEMS.map(func(it): return it[0])
	owned.sort_custom(func(a, b): return order.find(a) < order.find(b))


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
		_give(key)
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
		if money < rent():
			if home == 0:
				evicted = true
				return log + [{"key": "END_EVICTED", "args": []}]
			home -= 1
			log.append({"key": "HOME_DOWN", "args": [HOMES[home][0]]})
		else:
			money -= rent()
			log.append({"key": "RENT_PAID", "args": [rent()]})
	day += 1
	for i in range(shelf.size() - 1, -1, -1):
		if day - shelf[i][2] > SHELF_DAYS:
			log.append({"key": "PAWN_GONE", "args": [shelf[i][0]]})
			shelf.remove_at(i)
	worked_today = false
	negotiated = false
	offer = []
	_new_matches()
	if own_in_field() >= 0: # entry doesn't carry over to a new day
		_new_field()
	if due_day == day + 1:
		log.append({"key": "VINNIE_TEXT", "args": []})
	event = ""
	if rng.randi_range(1, 100) <= EVENT_PCT:
		var options := EVENTS.filter(_event_possible)
		event = options[rng.randi() % options.size()]
		event_arg = (matches[0][1] if matches[0][2] >= 0.5 else matches[0][0]) if event == "EV_TIP" else 0 # the underdog, naturally
		var args := {"EV_TIP": ["TEAM_%d" % event_arg], "EV_ROACH": [roach.get("name", "")]}
		log.append({"key": event, "args": args.get(event, [])})
		return log
	var quiet: String = ["EVENT_QUIET", "EVENT_LUCKY_DREAM", "EVENT_FOUND_CHIP"][rng.randi() % 3]
	if quiet == "EVENT_FOUND_CHIP":
		money += 25
	log.append({"key": quiet, "args": []})
	return log


# --- Homes, badges, morning events -----------------------------------------

func rent() -> int:
	return HOMES[home][2]


func next_home_price() -> int:
	return HOMES[home + 1][1] if home + 1 < HOMES.size() else 0


func move_up() -> Dictionary:
	var price := next_home_price()
	if price == 0 or money < price or is_over():
		return {}
	money -= price
	home += 1
	return {"key": "HOME_MOVED_%d" % home, "args": [price]}


## Badges earned since the last check, as log results.
func check_badges() -> Array:
	var out := []
	var earned := {
		"BADGE_DAY7": day >= 7, "BADGE_DAY30": day >= 30, "BADGE_DAY100": day >= 100,
		"BADGE_GRAND": money >= 1000, "BADGE_EMPTY": owned.is_empty(),
		"BADGE_ESCAPED": escaped_joey, "BADGE_ROACH3": roach.get("wins", 0) >= 3, "BADGE_RANCH": home == HOMES.size() - 1,
	}
	for k in earned:
		if earned[k] and not k in badges:
			badges.append(k)
			out.append({"key": "BADGE_GOT", "args": [k]})
	return out


func _event_possible(e: String) -> bool:
	match e:
		"EV_EARL": return "ITEM_MICROWAVE" in owned
		"EV_SAL": return not shelf.is_empty()
		"EV_ROACH": return not roach.is_empty()
		"EV_EX": return money > 0
	return true


## choice 0 = first button, 1 = second.
func resolve_event(choice: int) -> Dictionary:
	if event == "" or is_over():
		return {}
	var e := event
	event = ""
	var yes := choice == 0
	match e:
		"EV_EARL":
			if not yes:
				return {"key": "EV_EARL_NO", "args": []}
			if rng.randf() < 0.5:
				owned.erase("ITEM_MICROWAVE")
				return {"key": "EV_EARL_GONE", "args": []}
			money += 30
			return {"key": "EV_EARL_BACK", "args": [30]}
		"EV_TIP":
			if yes and money >= 20:
				money -= 20
				return {"key": "EV_TIP_PAID", "args": ["TEAM_%d" % event_arg]}
			return {"key": "EV_TIP_NO", "args": []}
		"EV_MOM":
			if yes:
				money += 50
				return {"key": "EV_MOM_MONEY", "args": [50]}
			return {"key": "EV_MOM_LIE", "args": []}
		"EV_PARCEL":
			if yes:
				money += 40
				return {"key": "EV_PARCEL_SOLD", "args": [40]}
			return {"key": "EV_PARCEL_LEFT", "args": []}
		"EV_EX":
			if yes:
				var paid := mini(money, 100)
				money -= paid
				return {"key": "EV_EX_PAID", "args": [paid]}
			if rng.randf() < 0.4:
				var fee := mini(money, 150)
				money -= fee
				return {"key": "EV_EX_LAWYER", "args": [fee]}
			return {"key": "EV_EX_FORGOT", "args": []}
		"EV_SAL":
			var it: Array = shelf[0]
			var cost: int = it[1] * 120 / 100
			if yes and money >= cost:
				money -= cost
				shelf.remove_at(0)
				_give(it[0])
				return {"key": "EV_SAL_BOUGHT", "args": [it[0], cost]}
			return {"key": "EV_SAL_NO", "args": []}
		"EV_MEETING":
			if yes:
				money += 20
				return {"key": "EV_MEETING_WENT", "args": [20]}
			money += 1
			return {"key": "EV_MEETING_SOLD", "args": [1]}
		"EV_ROACH":
			if yes and rng.randf() < 0.6:
				return {"key": "EV_ROACH_FOUND", "args": [roach.name]}
			var name: String = roach.name
			roach = {}
			return {"key": "EV_ROACH_GONE", "args": [name]}
	return {}


# --- Vinnie: loans --------------------------------------------------------

## Biggest loan Vinnie will give right now. Grows with reputation.
func loan_limit() -> int:
	return 0 if debt > 0 or step >= 3 else 100 + rep * 4 + home * LOAN_PER_HOME


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
	taken.append(item[0])
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
		escaped_joey = true
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
				taken.append(item[0])
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


# --- Roach derby (illegal, back alley) -----------------------------------

const ROACH_NAMES := ["Sir Crunch", "Lil' Greasy", "Speedy Pete", "The Professor", "Big Tony",
	"Crumbs", "Night Train", "Mama's Boy", "Dirty Dave", "Lucky Strike", "Señor Scuttle", "Fast Eddie"]
const RACE_FIELD := 5
const RAID_PCT := 8
const ROACH_PRICE := 150
const TRAIN_COST := 20
const ENTRY_FEE := 25
const PURSE := 120
const ROACH_MAX := 10

var field: Array = [] # [[name, speed], ...]; own roach is the one named roach.name
var roach := {} # Larry's own: {name, speed, trained_day, raced_day}


func _new_field(with_own := false) -> void:
	field.clear()
	var names := ROACH_NAMES.duplicate()
	names.shuffle()
	for i in RACE_FIELD - (1 if with_own else 0):
		field.append([names[i], rng.randi_range(2, 7)])
	if with_own:
		field.insert(rng.randi() % RACE_FIELD, [roach.name, roach.speed])


## Win chance of each roach in the field: speed squared, normalised.
func field_chances() -> Array:
	var total := 0.0
	for r in field:
		total += r[1] * r[1]
	return field.map(func(r): return r[1] * r[1] / total)


static func roach_odds(chance: float) -> float:
	return snappedf(0.85 / chance, 0.1)


## Finish order (field indices), weighted by speed. Seeded rng, so tests can predict it.
func _finish_order() -> Array:
	var left := range(field.size())
	var order := []
	while not left.is_empty():
		var total := 0.0
		for i in left:
			total += field[i][1] * field[i][1]
		var pick := rng.randf() * total
		for i in left:
			pick -= field[i][1] * field[i][1]
			if pick <= 0:
				order.append(i)
				left.erase(i)
				break
	return order


## bets: {field index: amount}. own_entered: Larry's roach is in this field.
## Returns {order, win, staked, raid, purse}.
func run_race(bets: Dictionary) -> Dictionary:
	if field.is_empty():
		_new_field()
	var staked := 0
	for i in bets:
		if bets[i] <= 0 or i < 0 or i >= field.size():
			return {}
		staked += bets[i]
	if staked > money or is_over() or shadowed:
		return {}
	var own := own_in_field()
	if staked == 0 and own < 0:
		return {}
	money -= staked
	var out := {"order": [], "win": 0, "staked": staked, "raid": false, "purse": 0}
	if rng.randi_range(1, 100) <= RAID_PCT:
		out.raid = true
	else:
		out.order = _finish_order()
		var chances := field_chances()
		var first: int = out.order[0]
		if bets.has(first):
			out.win = int(bets[first] * roach_odds(chances[first]))
		if own == first:
			out.purse = PURSE + roach.speed * 10
			roach.wins = roach.get("wins", 0) + 1
		money += out.win + out.purse
	_new_field()
	return out


func own_in_field() -> int:
	if roach.is_empty():
		return -1
	for i in field.size():
		if field[i][0] == roach.name:
			return i
	return -1


func buy_roach() -> Dictionary:
	if not roach.is_empty() or money < ROACH_PRICE or is_over():
		return {}
	money -= ROACH_PRICE
	var name: String = ROACH_NAMES[rng.randi() % ROACH_NAMES.size()]
	roach = {"name": "Larry's " + name, "speed": 3, "trained_day": 0, "raced_day": 0}
	return {"key": "ROACH_BOUGHT", "args": [roach.name, ROACH_PRICE]}


func train_roach() -> Dictionary:
	if roach.is_empty() or roach.trained_day == day or money < TRAIN_COST or roach.speed >= ROACH_MAX:
		return {}
	money -= TRAIN_COST
	roach.trained_day = day
	if rng.randi_range(1, 100) <= 25:
		return {"key": "ROACH_LAZY", "args": [TRAIN_COST]}
	roach.speed += 1
	return {"key": "ROACH_TRAINED", "args": [roach.speed]}


## Put Larry's roach in the next race (once a day, costs an entry fee).
func enter_roach() -> Dictionary:
	if roach.is_empty() or roach.raced_day == day or money < ENTRY_FEE or own_in_field() >= 0:
		return {}
	money -= ENTRY_FEE
	roach.raced_day = day
	_new_field(true)
	return {"key": "ROACH_ENTERED", "args": [ENTRY_FEE]}


# --- Blackjack (casino) ----------------------------------------------------
# Cards are [rank 1..13, suit 0..3]. Dealer stands on all 17s, blackjack pays 3:2, one deck reshuffled per hand.

var bj := {} # {bet, player: [cards], dealer: [cards], deck: [cards]}; empty = no hand in play


static func hand_value(cards: Array) -> int:
	var total := 0
	var aces := 0
	for c in cards:
		var r: int = c[0]
		if r == 1:
			aces += 1
			total += 11
		else:
			total += mini(r, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _draw_card() -> Array:
	return bj.deck.pop_back()


func bj_deal(bet: int) -> Dictionary:
	if not bj.is_empty() or bet <= 0 or bet > money or is_over() or shadowed:
		return {}
	money -= bet
	var deck := []
	for suit in 4:
		for rank in range(1, 14):
			deck.append([rank, suit])
	for i in range(deck.size() - 1, 0, -1): # shuffle with our own rng so tests are repeatable
		var j := rng.randi_range(0, i)
		var tmp = deck[i]; deck[i] = deck[j]; deck[j] = tmp
	bj = {"bet": bet, "player": [], "dealer": [], "deck": deck}
	bj.player.append(_draw_card()); bj.dealer.append(_draw_card())
	bj.player.append(_draw_card()); bj.dealer.append(_draw_card())
	if hand_value(bj.player) == 21 or hand_value(bj.dealer) == 21:
		return _bj_settle()
	return {"key": "BJ_DEALT", "args": []}


func bj_hit() -> Dictionary:
	if bj.is_empty():
		return {}
	bj.player.append(_draw_card())
	if hand_value(bj.player) > 21:
		return _bj_settle()
	return {"key": "BJ_HIT", "args": [hand_value(bj.player)]}


func bj_stand() -> Dictionary:
	if bj.is_empty():
		return {}
	while hand_value(bj.dealer) < 17:
		bj.dealer.append(_draw_card())
	return _bj_settle()


## Double the bet, take exactly one card, then stand.
func bj_double() -> Dictionary:
	if bj.is_empty() or bj.player.size() != 2 or money < bj.bet:
		return {}
	money -= bj.bet
	bj.bet *= 2
	bj.player.append(_draw_card())
	if hand_value(bj.player) > 21:
		return _bj_settle()
	return bj_stand()


## Pays out and ends the hand. Result keeps the final hands so the table can show them.
func _bj_settle() -> Dictionary:
	var p := hand_value(bj.player)
	var d := hand_value(bj.dealer)
	var bet: int = bj.bet
	var natural: bool = p == 21 and bj.player.size() == 2
	var key := ""
	var paid := 0
	if p > 21:
		key = "BJ_BUST"
	elif natural and not (d == 21 and bj.dealer.size() == 2):
		key = "BJ_BLACKJACK"; paid = bet + bet * 3 / 2
	elif d > 21:
		key = "BJ_DEALER_BUST"; paid = bet * 2
	elif p > d:
		key = "BJ_WIN"; paid = bet * 2
	elif p == d:
		key = "BJ_PUSH"; paid = bet
	else:
		key = "BJ_LOSE"
	money += paid
	var out := {"key": key, "args": [p, d, paid if paid > bet else bet], "player": bj.player, "dealer": bj.dealer, "paid": paid}
	bj = {}
	return out


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

const SAVED := ["field", "roach", "day", "money", "debt", "owned", "taken", "shelf", "worked_today", "evicted", "matches",
	"due_day", "step", "rep", "used_mom", "negotiated", "offer", "shadowed",
	"home", "badges", "event", "event_arg", "escaped_joey"]


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
	for k in ["day", "money", "debt", "due_day", "step", "rep", "home", "event_arg"]:
		set(k, int(get(k)))
	offer = offer.map(func(v): return int(v))
	field = field.map(func(r): return [r[0], int(r[1])])
	for k in ["speed", "trained_day", "raced_day", "wins"]:
		if roach.has(k):
			roach[k] = int(roach[k])
	shelf = shelf.map(func(e): return [e[0], int(e[1]), int(e[2])])
	for m in matches:
		m[0] = int(m[0]); m[1] = int(m[1])
