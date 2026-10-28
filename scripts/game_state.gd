extends RefCounted
## Pure game logic, no UI. Every result is {key, args} so the UI can tr() it in any language.

const MAX_DAYS := 30
const ACTIONS_PER_DAY := 3
const DAILY_INTEREST_PCT := 10
const DEBT_LIMIT := 1000
# Expected return per bet: 0.02*10 + 0.38*2 = 0.96, so the house always wins in the long run.
const JACKPOT_CHANCE := 0.02
const WIN_CHANCE := 0.40
const WORK_PAY := 30
const LOAN_SIZE := 100

# Sold in this order. [price, family trust lost]
const ITEMS := {
	"ITEM_IRON": [15, 5],
	"ITEM_MICROWAVE": [40, 8],
	"ITEM_GUITAR": [80, 10],
	"ITEM_TV": [120, 15],
	"ITEM_RING": [300, 35],
}

var rng := RandomNumberGenerator.new()
var day := 1
var money := 50
var debt := 0
var hope := 60
var family := 60
var actions_left := ACTIONS_PER_DAY
var items_left: Array = ITEMS.keys()
var sold: Array = []


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func can_act() -> bool:
	return actions_left > 0 and ending() == ""


func bet(amount: int) -> Dictionary:
	if not can_act() or amount <= 0 or amount > money:
		return {}
	actions_left -= 1
	money -= amount
	var roll := rng.randf()
	if roll < JACKPOT_CHANCE:
		money += amount * 10
		_mood(25, 0)
		return {"key": "BET_JACKPOT", "args": [amount * 10]}
	if roll < WIN_CHANCE:
		money += amount * 2
		_mood(10, 0)
		return {"key": "BET_WIN", "args": [amount * 2]}
	_mood(-10, -3)
	return {"key": "BET_LOSE_%d" % rng.randi_range(1, 3), "args": [amount]}


func work() -> Dictionary:
	if not can_act():
		return {}
	actions_left -= 1
	money += WORK_PAY
	_mood(-5, 5)
	return {"key": "WORK", "args": [WORK_PAY]}


func sell_next() -> Dictionary:
	if not can_act() or items_left.is_empty():
		return {}
	actions_left -= 1
	var item: String = items_left.pop_front()
	sold.append(item)
	money += ITEMS[item][0]
	_mood(-2, -ITEMS[item][1])
	return {"key": "SELL_" + item, "args": [ITEMS[item][0]]}


func borrow() -> Dictionary:
	if not can_act():
		return {}
	actions_left -= 1
	money += LOAN_SIZE
	debt += LOAN_SIZE
	_mood(-5, 0)
	return {"key": "BORROW", "args": [LOAN_SIZE]}


func end_day() -> Dictionary:
	if ending() != "":
		return {}
	debt += (debt * DAILY_INTEREST_PCT + 99) / 100 # integer ceil, floats gave 111 for 100
	var events := ["EVENT_QUIET", "EVENT_LUCKY_DREAM", "EVENT_MOM_MONEY", "EVENT_KID_DRAWING"]
	if "ITEM_IRON" in sold:
		events.append("EVENT_WIFE_IRON")
	if debt > 0:
		events.append("EVENT_COLLECTOR")
	var event: String = events[rng.randi() % events.size()]
	match event:
		"EVENT_LUCKY_DREAM": _mood(10, 0)
		"EVENT_MOM_MONEY": money += 40; _mood(-5, 0)
		"EVENT_KID_DRAWING": _mood(5, 5)
		"EVENT_WIFE_IRON": _mood(0, -15)
		"EVENT_COLLECTOR": money -= mini(money, 50); _mood(-10, -5)
	day += 1
	actions_left = ACTIONS_PER_DAY
	return {"key": event, "args": []}


## "" while the game goes on, otherwise the ending's translation key.
func ending() -> String:
	if family <= 0:
		return "END_ALONE"
	if hope <= 0:
		return "END_HOPELESS"
	if debt >= DEBT_LIMIT:
		return "END_DEBT"
	if day > MAX_DAYS:
		return "END_SURVIVED"
	return ""


func _mood(hope_delta: int, family_delta: int) -> void:
	hope = clampi(hope + hope_delta, 0, 100)
	family = clampi(family + family_delta, 0, 100)
