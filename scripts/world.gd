extends Node2D
## The neighbourhood map, built from Kenney isometric tiles.
## Tap the ground to walk (A* around buildings), tap a building to walk to its door and go in.

const Character := preload("res://scripts/character.gd")
const Night := preload("res://scripts/vegas_night.gd")

const GRID := 12
const HW := 66.0 # half tile width
const HH := 33.0 # half tile height
const FLOOR_UP := 49.5 # next floor sits this far below the previous sprite's top
const ROAD_X := [3, 8] # columns that are roads
const ROAD_Y := [3, 8] # rows that are roads
const STRIP_ROWS := 3 # rows above the first road are the Strip

# Each place: tiles it covers, and the sprite stack per tile (ground floor, upper floors..., roof).
const PLACES := {
	"CASINO": {"tiles": [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)],
		"stack": ["002", "000", "000", "000", "000"], "sign": "#ff4fd8"},
	"MOTEL": {"tiles": [Vector2i(1, 4)], "stack": ["040", "048", "074"], "sign": "#ffb347"},
	"DINER": {"tiles": [Vector2i(4, 4)], "stack": ["012"], "sign": "#ff6b6b"},
	"BETS": {"tiles": [Vector2i(9, 4)], "stack": ["029"], "sign": "#7ee081"},
	"VINNIE": {"tiles": [Vector2i(1, 9)], "stack": ["045", "016"], "sign": "#6ec6ff"},
	"PAWN": {"tiles": [Vector2i(4, 9)], "stack": ["024", "048"], "sign": "#c39bff"},
	"DERBY": {"tiles": [Vector2i(10, 9)], "stack": ["030"], "sign": "#ffd23f"},
}
# Filler buildings: [tile, stack]
const FILLERS := [
	[Vector2i(0, 1), ["001", "000", "000", "000"]], [Vector2i(1, 2), ["003", "000", "000"]],
	[Vector2i(6, 2), ["009", "007", "007", "007"]], [Vector2i(7, 1), ["010", "000", "000", "000", "000"]],
	[Vector2i(9, 2), ["004", "008", "008"]], [Vector2i(10, 1), ["002", "000", "000", "000"]],
	[Vector2i(11, 2), ["011", "000", "000"]], [Vector2i(0, 0), ["017", "015"]],
	[Vector2i(2, 5), ["036", "072"]], [Vector2i(5, 5), ["027"]], [Vector2i(6, 4), ["020", "024"]],
	[Vector2i(10, 5), ["033", "080"]], [Vector2i(11, 4), ["041", "039"]], [Vector2i(7, 6), ["046"]],
	[Vector2i(0, 6), ["022", "023"]], [Vector2i(2, 10), ["037", "081"]], [Vector2i(5, 10), ["026"]],
	[Vector2i(6, 9), ["030", "031", "076"]], [Vector2i(9, 10), ["042", "043"]], 
	[Vector2i(11, 10), ["035", "032"]], [Vector2i(0, 11), ["018"]], [Vector2i(7, 11), ["021", "016"]],
]
const TREES := [Vector2i(2, 6), Vector2i(6, 6), Vector2i(10, 6), Vector2i(1, 11), Vector2i(6, 11), Vector2i(10, 11), Vector2i(2, 0), Vector2i(9, 0)]

var astar := AStarGrid2D.new()
var place_at := {} # Vector2i -> place id
var hit_sprites: Array = [] # [Sprite2D, place id], front-most last
var larry: Character
var joey: Character
var going_into := ""
var hud: Label
var signs := CanvasLayer.new() # neon signs move with the map but skip the night tint
var panel: PanelContainer


static func top_corner(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HW, (cell.x + cell.y) * HH)


## Where a character stands on a tile (centre of its top face).
static func centre(cell: Vector2i) -> Vector2:
	return top_corner(cell) + Vector2(0, HH)


static func cell_at(p: Vector2) -> Vector2i:
	var u := p.x / HW
	var v := p.y / HH
	return Vector2i(floori((u + v) / 2.0), floori((v - u) / 2.0))


func _ready() -> void:
	astar.region = Rect2i(0, 0, GRID, GRID)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	Night.add_sky(self)
	Night.add_night(self)
	Night.add_desert(self, GRID, func(c): return top_corner(c))
	signs.follow_viewport_enabled = true
	add_child(signs)
	var glows := Node2D.new() # unlit glow pools, under the signs
	signs.add_child(glows)
	var ground := Node2D.new()
	add_child(ground)
	var things := Node2D.new()
	things.y_sort_enabled = true
	add_child(things)

	var stacks := {}
	for id in PLACES:
		for t in PLACES[id].tiles:
			stacks[t] = PLACES[id].stack
			place_at[t] = id
	for f in FILLERS:
		stacks[f[0]] = f[1]

	# Ground first, back to front, so tile thickness overlaps correctly.
	for s in GRID * 2:
		for x in GRID:
			var y := s - x
			if y < 0 or y >= GRID:
				continue
			var cell := Vector2i(x, y)
			if stacks.has(cell):
				astar.set_point_solid(cell)
				_add_building(things, cell, stacks[cell])
			else:
				_add_sprite(ground, "res://assets/city/cityTiles_%s.png" % _ground_tile(cell), top_corner(cell), false)

	for id in PLACES:
		_add_sign(id)
		Night.add_light(glows, centre(_front_door(id)), Color(PLACES[id].sign), 1.0, 1.2)
	Night.add_light(glows, centre(Vector2i(5, 3)), Color("#ff4fd8"), 1.0, 3.0) # casino wash
	# Street lamps on sidewalks next to roads.
	for x in GRID:
		for y in GRID:
			var c := Vector2i(x, y)
			var by_road := (x + 1 in ROAD_X or y + 1 in ROAD_Y) and not (x in ROAD_X or y in ROAD_Y)
			if by_road and not astar.is_point_solid(c) and (x + y) % 3 == 0:
				Night.add_lamp(things, centre(c) + Vector2(0, 8))

	larry = Character.new()
	larry.setup("res://assets/characters/character-male-b.glb")
	larry.position = Game.larry_pos if Game.larry_pos != Vector2.ZERO else centre(_door(PLACES.MOTEL.tiles[0]))
	larry.arrived.connect(_on_arrived)
	things.add_child(larry)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.zoom = Vector2.ONE * 0.8
	larry.add_child(cam)
	Night.add_light(larry, Vector2.ZERO, Color("#fff1d6"), 0.8, 0.6)

	_build_ui()
	if Game.is_over():
		_open_place("MOTEL")
	elif Game.state.collection_due():
		_joey_arrives(things)


func _ground_tile(c: Vector2i) -> String:
	var rx := c.x in ROAD_X
	var ry := c.y in ROAD_Y
	if rx and ry:
		return "089"
	if rx:
		return "081"
	if ry:
		return "073"
	if c in TREES:
		return "078"
	return "072"


func _add_sprite(parent: Node, path: String, top_left_anchor: Vector2, bottom := true) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.centered = false
	var size := sp.texture.get_size()
	# bottom = anchor is the bottom-centre of the image, else its top-centre.
	sp.position = top_left_anchor - Vector2(size.x / 2.0, size.y if bottom else 0.0)
	parent.add_child(sp)
	return sp


## One building on one tile: ground floor aligned with the ground tiles, then floors stacked up.
func _add_building(parent: Node, cell: Vector2i, stack: Array) -> void:
	var node := Node2D.new()
	node.position = centre(cell) # y-sort by tile centre, same as characters
	parent.add_child(node)
	var bottom := top_corner(cell) + Vector2(0, 101) - node.position
	var top_y := 0.0
	for i in stack.size():
		var anchor := bottom if i == 0 else Vector2(0, top_y + FLOOR_UP)
		var sp := _add_sprite(node, "res://assets/buildings/buildingTiles_%s.png" % stack[i], anchor)
		top_y = sp.position.y
		hit_sprites.append([sp, place_at.get(cell, "")])


func _add_sign(id: String) -> void:
	var tiles: Array = PLACES[id].tiles
	var top := INF
	var sum := Vector2.ZERO
	for t in tiles:
		sum += centre(t)
	for pair in hit_sprites:
		if pair[1] == id:
			top = minf(top, pair[0].global_position.y)
	var big: bool = id == "CASINO"
	Night.add_neon(signs, tr("PLACE_" + id), Color(PLACES[id].sign), Vector2(sum.x / tiles.size(), top - (14 if big else 4)), 40 if big else 24, big)


## For multi-tile places: the free neighbour closest to the viewer (largest x+y), so Larry isn't hidden.
func _front_door(id: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	for t in PLACES[id].tiles:
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = t + d
			if astar.is_in_boundsv(n) and not astar.is_point_solid(n) and (best.x < 0 or n.x + n.y > best.x + best.y):
				best = n
	return best


## Nearest walkable tile next to a building tile, preferring the road side.
func _door(cell: Vector2i) -> Vector2i:
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return n
	return cell


func _path_to(cell: Vector2i) -> Array:
	var from := cell_at(larry.position - Vector2(0, 1))
	from = from.clamp(Vector2i.ZERO, Vector2i(GRID - 1, GRID - 1))
	var pts := []
	for c in astar.get_id_path(from, cell, true):
		pts.append(centre(c))
	return pts


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if panel.visible or Game.is_over() or joey != null:
		return
	var p := get_global_mouse_position()
	# Buildings: front-most opaque pixel wins.
	var best := ""
	var best_y := -INF
	for pair in hit_sprites:
		var sp: Sprite2D = pair[0]
		if pair[1] != "" and sp.is_pixel_opaque(sp.to_local(p)) and sp.get_parent().position.y > best_y:
			best = pair[1]
			best_y = sp.get_parent().position.y
	if best != "":
		going_into = best
		var door := _front_door(best)
		larry.walk(_path_to(door))
		return
	var cell := cell_at(p)
	if not astar.is_in_boundsv(cell) or astar.is_point_solid(cell):
		return
	going_into = ""
	larry.walk(_path_to(cell))


func _on_arrived() -> void:
	Game.larry_pos = larry.position
	if going_into != "":
		larry.face(centre(PLACES[going_into].tiles[0]) - larry.position)
		_open_place(going_into)
		going_into = ""


## Joey walks in from the nearest road end and blocks Larry until the debt is dealt with.
func _joey_arrives(parent: Node) -> void:
	joey = Character.new()
	joey.setup("res://assets/characters/character-male-a.glb")
	var larry_cell := cell_at(larry.position - Vector2(0, 1))
	joey.position = centre(Vector2i(ROAD_X[0], GRID - 1))
	parent.add_child(joey)
	var target := larry_cell + Vector2i(1, 0)
	if not astar.is_in_boundsv(target) or astar.is_point_solid(target):
		target = larry_cell + Vector2i(0, 1)
	var pts := []
	for c in astar.get_id_path(cell_at(joey.position - Vector2(0, 1)), target, true):
		pts.append(centre(c))
	joey.arrived.connect(func():
		joey.face(larry.position - joey.position)
		larry.face(joey.position - larry.position)
		_open_place("JOEY"), CONNECT_ONE_SHOT)
	joey.walk(pts)


func _joey_leaves() -> void:
	if joey == null:
		return
	var j := joey
	joey = null
	var pts := []
	for c in astar.get_id_path(cell_at(j.position - Vector2(0, 1)), Vector2i(ROAD_X[0], GRID - 1), true):
		pts.append(centre(c))
	j.arrived.connect(j.queue_free)
	j.walk(pts)


# --- UI ------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	hud = Label.new()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hud)
	var lang := Button.new()
	lang.pressed.connect(func():
		TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("tr") else "tr")
		get_tree().reload_current_scene())
	lang.text = tr("BTN_LANGUAGE")
	row.add_child(lang)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.visible = false
	layer.add_child(panel)
	_refresh_hud()


func _refresh_hud() -> void:
	hud.text = Game.stats_text()


func _open_place(id: String) -> void:
	var s = Game.state
	for c in panel.get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)

	Game.make_label(box, tr("PLACE_" + id)).add_theme_font_size_override("font_size", 40)
	Game.make_label(box, Game.entry_text(Game.log[-1]))

	if Game.is_over():
		Game.make_button(box, tr("BTN_RESTART"), func():
			Game.new_game(); Game.larry_pos = Vector2.ZERO; get_tree().reload_current_scene())
	else:
		match id:
			"MOTEL":
				Game.make_button(box, tr("BTN_SLEEP"), _act.bind(id, s.sleep))
			"DINER":
				Game.make_button(box, tr("BTN_WORK") % s.WORK_PAY, _act.bind(id, s.work)).disabled = s.worked_today
			"PAWN":
				Game.make_button(box, tr("BTN_SELL") % [tr(s.next_item()), s.next_item_value()], _act.bind(id, s.sell_next)).disabled = s.owned.is_empty()
				if not s.shelf.is_empty():
					Game.make_label(box, tr("PAWN_SHELF"))
				for e in s.shelf:
					var cost: int = s.buyback_price(e[1])
					var days_left: int = s.SHELF_DAYS - (s.day - e[2])
					Game.make_button(box, tr("BTN_BUYBACK") % [tr(e[0]), cost, days_left], _act.bind(id, s.buy_back.bind(e[0]))).disabled = cost > s.money
			"VINNIE":
				var limit: int = s.loan_limit()
				if limit > 0:
					for amount in ([100, limit] if limit > 100 else [100]):
						Game.make_button(box, tr("BTN_BORROW") % amount, _act.bind(id, s.borrow.bind(amount)))
				else:
					Game.make_label(box, tr("VINNIE_NO_LOAN"))
				Game.make_button(box, tr("BTN_REPAY"), _act.bind(id, s.repay)).disabled = s.debt == 0 or s.money == 0
			"BETS", "CASINO":
				if s.shadowed:
					Game.make_label(box, tr("SHADOW_BOUNCER"))
				else:
					Game.make_button(box, tr("BTN_SPORTS" if id == "BETS" else "BTN_ROULETTE"), Game.go.bind("sports" if id == "BETS" else "roulette"))
			"DERBY":
				Game.make_button(box, tr("BTN_DERBY"), Game.go.bind("race"))
			"JOEY":
				_joey_buttons(box)
				_show()
				return
		Game.make_button(box, tr("BTN_LEAVE"), func(): panel.visible = false)
	panel.visible = true


func _show() -> void:
	panel.visible = true


## Joey blocks the screen until Larry deals with him (or goes to sleep).
func _joey_buttons(box: VBoxContainer) -> void:
	var s = Game.state
	if not s.offer.is_empty():
		Game.make_label(box, tr("NEGO_OFFER") % s.offer)
		Game.make_button(box, tr("BTN_ACCEPT"), _act.bind("JOEY", s.accept_offer))
		Game.make_button(box, tr("BTN_PUSH"), _act.bind("JOEY", s.push_offer))
		return
	Game.make_label(box, tr("JOEY_HERE") % s.debt)
	Game.make_button(box, tr("BTN_PAY_JOEY") % mini(s.money, s.debt), _act.bind("JOEY", s.pay_joey)).disabled = s.money <= 0
	if not s.negotiated:
		for line in ["tip", "mom", "flatter"]:
			Game.make_button(box, tr("NEGO_LINE_" + line.to_upper()), _act.bind("JOEY", s.negotiate.bind(line)))
	if not s.owned.is_empty():
		Game.make_button(box, tr("BTN_COLLATERAL") % [tr(s.next_item()), s.next_item_value() / 2], _act.bind("JOEY", s.give_collateral))
	Game.make_button(box, tr("BTN_RUN"), _act.bind("JOEY", s.run_from_joey))


func _act(id: String, action: Callable) -> void:
	Game.record(action.call())
	_refresh_hud()
	if id == "JOEY" and not Game.state.collection_due() and Game.state.offer.is_empty():
		id = "VINNIE_DONE"
	if id == "VINNIE_DONE":
		_joey_leaves()
		_result_only()
	else:
		_open_place(id)


## After Joey leaves: show what happened and a close button.
func _result_only() -> void:
	for c in panel.get_children():
		c.queue_free()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var lines := PackedStringArray()
	for e in Game.log.slice(-2):
		lines.append(Game.entry_text(e))
	Game.make_label(box, "\n\n".join(lines))
	Game.make_button(box, tr("BTN_LEAVE"), func(): panel.visible = false)
	panel.visible = true
