extends RefCounted
## One Texas Hold'em table with four seats. Seat 0 is Larry, the rest are regulars. Pure rules, no UI.
## Cards are [rank 2..14, suit 0..3].

const SEATS := 4
const SB := 1
const BB := 2
const MAX_RAISES := 3 # per betting round, so a round always ends
const RAKE_PCT := 5 # the house takes this from every contested pot
const BOT_STACK := 100
const SAMPLES := 30
# Regulars: [name key, margin (calls only if equity beats pot odds by this much), bluff chance, tell chance]
const BOTS := [[],
	["PK_SUE", 0.10, 0.03, 0.0], # tight: when she bets, she has it
	["PK_REV", 0.0, 0.30, 0.6], # bluffs a lot, and tugs his collar when he does
	["PK_RUTH", -0.18, 0.0, 0.0], # calls anything, never folds a pair
]

var rng: RandomNumberGenerator
var stacks := [0, BOT_STACK, BOT_STACK, BOT_STACK]
var button := 0
var deck: Array = []
var hole: Array = [[], [], [], []]
var board: Array = []
var street := 0 # 0 preflop, 1 flop, 2 turn, 3 river
var bets := [0, 0, 0, 0] # this betting round
var total := [0, 0, 0, 0] # this hand
var folded := [false, false, false, false]
var acted := [false, false, false, false]
var raises := 0
var in_hand := false
var events: Array = [] # what happened since the UI last looked: {seat, act, amount, tell, pot, stacks, board}
var result := {} # set when the hand ends: {key, args, won, shown}


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng


func pot() -> int:
	return total[0] + total[1] + total[2] + total[3]


func to_call(seat: int) -> int:
	return mini(bets.max() - bets[seat], stacks[seat])


func raise_by() -> int:
	return maxi(BB * 2, pot() / 2)


func start_hand() -> bool:
	if in_hand or stacks[0] < BB:
		return false
	for i in range(1, SEATS):
		if stacks[i] < BB * 10: # a busted regular digs out another roll
			stacks[i] = BOT_STACK
	deck = []
	for suit in 4:
		for rank in range(2, 15):
			deck.append([rank, suit])
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = deck[i]; deck[i] = deck[j]; deck[j] = tmp
	button = (button + 1) % SEATS
	board = []
	street = 0
	raises = 0
	result = {}
	events = []
	in_hand = true
	for i in SEATS:
		bets[i] = 0; total[i] = 0; folded[i] = false; acted[i] = false
		hole[i] = [deck.pop_back(), deck.pop_back()]
	_put((button + 1) % SEATS, SB)
	_put((button + 2) % SEATS, BB)
	_log({"seat": -1, "act": "street", "amount": 0, "tell": false}) # so the screen shows the blinds going in
	_advance((button + 3) % SEATS)
	return true


## Larry's move: "fold", "call" (also check), "raise" or "allin".
func larry(action: String) -> void:
	if not in_hand or _next_to_act(0) != 0:
		return
	events = []
	_act(0, action, false)
	_advance(1)


func _put(seat: int, amount: int) -> void:
	amount = mini(amount, stacks[seat])
	stacks[seat] -= amount
	bets[seat] += amount
	total[seat] += amount


func _act(seat: int, action: String, tell: bool) -> void:
	var before: int = bets.max()
	var call := to_call(seat)
	if action == "raise" and raises >= MAX_RAISES:
		action = "call"
	match action:
		"fold":
			folded[seat] = true
		"call":
			_put(seat, call)
			action = "check" if call == 0 else "call"
		"raise":
			_put(seat, call + raise_by())
		"allin":
			_put(seat, stacks[seat])
	if bets[seat] > before: # a real raise reopens the betting
		raises += 1
		acted = [false, false, false, false]
	acted[seat] = true
	_log({"seat": seat, "act": action, "amount": bets[seat], "tell": tell})


func _log(e: Dictionary) -> void:
	e.pot = pot()
	e.stacks = stacks.duplicate()
	e.board = board.size()
	events.append(e)


## First seat from `from` that still owes a decision, or -1 when the round is done.
func _next_to_act(from: int) -> int:
	var live := 0 # still in and with chips
	for i in SEATS:
		if not folded[i] and stacks[i] > 0:
			live += 1
	for k in SEATS:
		var i := (from + k) % SEATS
		if folded[i] or stacks[i] == 0:
			continue
		if bets[i] < bets.max() or (not acted[i] and live > 1):
			return i
	return -1


func _advance(from: int) -> void:
	while in_hand:
		if folded.count(false) == 1:
			_finish()
			return
		var seat := _next_to_act(from)
		if seat == 0:
			return # waiting for Larry
		if seat == -1:
			if street == 3:
				_finish()
				return
			street += 1
			for n in (3 if street == 1 else 1):
				board.append(deck.pop_back())
			bets = [0, 0, 0, 0]
			acted = [false, false, false, false]
			raises = 0
			_log({"seat": -1, "act": "street", "amount": 0, "tell": false})
			from = (button + 1) % SEATS
			continue
		_bot(seat)
		from = (seat + 1) % SEATS


func _bot(seat: int) -> void:
	var b: Array = BOTS[seat]
	var s := strength(seat)
	var call := to_call(seat)
	var bluff: bool = s < 0.5 and rng.randf() < b[2]
	var action := "call"
	if call == 0:
		if s > 0.65 + b[1] * 0.5 or bluff:
			action = "raise"
	else:
		var odds := float(call) / (pot() + call)
		if s > 0.8 or bluff:
			action = "raise"
		elif s <= odds + 0.08 + b[1]:
			action = "fold"
	var is_bluff := bluff and action == "raise" and raises < MAX_RAISES
	# The tell shows on most bluffs and, to keep Larry honest, on the odd real hand.
	_act(seat, action, rng.randf() < (b[3] if is_bluff else b[3] * 0.1))


## Chance to beat one random hand, by dealing the rest of the cards out a few times.
func strength(seat: int) -> float:
	var rest := deck.duplicate()
	for i in SEATS:
		if i != seat:
			rest.append_array(hole[i]) # the bot can't see these, so they're still "in the deck" for it
	var wins := 0.0
	var need := 5 - board.size()
	for n in SAMPLES:
		for k in need + 2: # partial shuffle: the first need+2 cards are a fresh draw
			var j := rng.randi_range(k, rest.size() - 1)
			var tmp = rest[k]; rest[k] = rest[j]; rest[j] = tmp
		var full := board + rest.slice(2, 2 + need)
		var mine := score(hole[seat] + full)
		var theirs := score([rest[0], rest[1]] + full)
		wins += 1.0 if mine > theirs else (0.5 if mine == theirs else 0.0)
	return wins / SAMPLES


func _finish() -> void:
	in_hand = false
	while folded.count(false) > 1 and board.size() < 5: # all-in before the river: run it out
		board.append(deck.pop_back())
	var showdown := folded.count(false) > 1
	var won := [0, 0, 0, 0]
	var scores := []
	for i in SEATS:
		scores.append(score(hole[i] + board) if showdown and not folded[i] else [-1])
	# Side pots: peel the pot off in layers, one per distinct amount put in.
	var levels := total.duplicate()
	levels.sort()
	var prev := 0
	for lvl in levels:
		if lvl == prev:
			continue
		var layer := 0
		var payers := 0
		var best := []
		var winners := []
		for i in SEATS:
			layer += mini(total[i], lvl) - mini(total[i], prev)
			if total[i] >= lvl:
				payers += 1
				if not folded[i]:
					if winners.is_empty() or scores[i] > best:
						best = scores[i]; winners = [i]
					elif scores[i] == best:
						winners.append(i)
		prev = lvl
		if winners.is_empty():
			continue
		if payers > 1:
			layer -= layer * RAKE_PCT / 100
		for w in winners:
			won[w] += layer / winners.size()
		won[winners[0]] += layer % winners.size()
	for i in SEATS:
		stacks[i] += won[i]
	var net: int = won[0] - total[0]
	var top := 1 # the regular who took the most, for the "you lost to" line
	for i in range(1, SEATS):
		if won[i] > won[top]:
			top = i
	var hand := "PK_HAND_%d" % scores[top][0] if showdown else ""
	if folded[0]:
		result = {"key": "PK_FOLDED" if total[0] > 0 else "PK_FOLDED_FREE", "args": [total[0]] if total[0] > 0 else []}
	elif not showdown:
		result = {"key": "PK_STOLE", "args": [net]}
	elif net > 0:
		result = {"key": "PK_WON", "args": [net, "PK_HAND_%d" % scores[0][0]]}
	elif net == 0:
		result = {"key": "PK_SPLIT", "args": [won[0]]}
	else:
		result = {"key": "PK_LOST", "args": [BOTS[top][0], hand, -net]}
	result.net = net
	result.showdown = showdown
	_log({"seat": -1, "act": "end", "amount": 0, "tell": false})


## Best five of the given cards as a comparable array: [category 0..8, tie-breakers...].
static func score(cards: Array) -> Array:
	var counts := {}
	var suits := [[], [], [], []]
	for c in cards:
		counts[c[0]] = counts.get(c[0], 0) + 1
		suits[c[1]].append(c[0])
	var flush: Array = []
	for s in suits:
		if s.size() >= 5:
			flush = s
			flush.sort()
			flush.reverse()
	if not flush.is_empty() and _straight(flush) > 0:
		return [8, _straight(flush)]
	var ranks := counts.keys()
	ranks.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and a > b))
	var top: int = counts[ranks[0]]
	var second: int = counts[ranks[1]] if ranks.size() > 1 else 0
	var high := counts.keys() # every rank, high to low, for kickers and straights
	high.sort()
	high.reverse()
	if top == 4:
		return [7, ranks[0]] + _kick(high, [ranks[0]], 1)
	if top == 3 and second >= 2:
		return [6, ranks[0], ranks[1]]
	if not flush.is_empty():
		return [5] + flush.slice(0, 5)
	if _straight(high) > 0:
		return [4, _straight(high)]
	if top == 3:
		return [3, ranks[0]] + _kick(high, [ranks[0]], 2)
	if top == 2 and second == 2:
		return [2, ranks[0], ranks[1]] + _kick(high, [ranks[0], ranks[1]], 1)
	if top == 2:
		return [1, ranks[0]] + _kick(high, [ranks[0]], 3)
	return [0] + high.slice(0, 5)


static func _kick(high: Array, used: Array, n: int) -> Array:
	return high.filter(func(r): return not r in used).slice(0, n)


## Top card of the best straight in ranks sorted high to low (no repeats), or 0. The ace also plays low.
static func _straight(high: Array) -> int:
	var u := high.duplicate()
	if 14 in u:
		u.append(1)
	var run := 1
	for i in range(1, u.size()):
		run = run + 1 if u[i] == u[i - 1] - 1 else 1
		if run >= 5:
			return u[i] + 4
	return 0
