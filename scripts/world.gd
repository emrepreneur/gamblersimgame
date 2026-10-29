extends Node2D
## The neighbourhood map. Tap the ground to walk, tap a building to walk to its door and go in.

const Building := preload("res://scripts/building.gd")
const Larry := preload("res://scripts/larry.gd")

const GRID := 11
const STRIP_ROWS := 4 # rows 0..3 are the Strip, the rest are back streets

# cell = top corner of footprint, size = footprint in cells, h = wall height in px
const PLACES := [
	{"id": "CASINO", "cell": Vector2i(3, 0), "size": Vector2i(4, 3), "h": 210, "color": "#e8b923"},
	{"id": "VINNIE", "cell": Vector2i(0, 4), "size": Vector2i(2, 2), "h": 70, "color": "#4fa3c7"},
	{"id": "BETS", "cell": Vector2i(8, 4), "size": Vector2i(2, 2), "h": 80, "color": "#3fae6b"},
	{"id": "MOTEL", "cell": Vector2i(0, 8), "size": Vector2i(3, 2), "h": 100, "color": "#d08c4a"},
	{"id": "DINER", "cell": Vector2i(4, 8), "size": Vector2i(2, 2), "h": 60, "color": "#d9534f"},
	{"id": "PAWN", "cell": Vector2i(8, 8), "size": Vector2i(2, 2), "h": 70, "color": "#8e6cc3"},
]

var buildings := {}
var larry: Larry
var going_into := ""
var hud: Label
var panel: PanelContainer


func _ready() -> void:
	var ground := Node2D.new()
	ground.z_index = -1
	ground.draw.connect(_draw_ground.bind(ground))
	add_child(ground)

	var sorted := Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	for p in PLACES:
		var b := Building.new()
		b.setup(p)
		sorted.add_child(b)
		buildings[p.id] = b

	larry = Larry.new()
	larry.position = Game.larry_pos if Game.larry_pos != Vector2.ZERO else buildings.MOTEL.door()
	larry.arrived.connect(_on_arrived)
	sorted.add_child(larry)
	var cam := Camera2D.new()
	larry.add_child(cam)
	cam.position_smoothing_enabled = true

	_build_ui()
	if Game.is_over():
		_open_place("MOTEL")


func _draw_ground(ground: Node2D) -> void:
	for x in GRID:
		for y in GRID:
			var strip := y < STRIP_ROWS
			var road := x == 2 or x == 7 or y == 3 or y == 7
			var c := Color("#4a2b5c") if strip else Color("#3b3f45")
			if road:
				c = Color("#2a2033") if strip else Color("#25282c")
			if (x + y) % 2 == 0:
				c = c.lightened(0.05)
			var p := Building.iso(x, y)
			ground.draw_colored_polygon([p, Building.iso(x + 1, y), Building.iso(x + 1, y + 1), Building.iso(x, y + 1)], c)
	# Neon line where the Strip begins.
	ground.draw_line(Building.iso(0, STRIP_ROWS), Building.iso(GRID, STRIP_ROWS), Color("#ff4fd8"), 4)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if panel.visible or Game.is_over():
		return
	var p := get_global_mouse_position()
	# Front-most building first, so overlapping roofs pick the one in front.
	var ids := buildings.keys()
	ids.sort_custom(func(a, b): return buildings[a].position.y > buildings[b].position.y)
	for id in ids:
		if Geometry2D.is_point_in_polygon(p, buildings[id].hull()):
			going_into = id
			larry.walk_to(buildings[id].door())
			return
	going_into = ""
	# shortcut: straight-line walking, no pathfinding around buildings; add a NavigationRegion2D when the map grows.
	larry.walk_to(_clamp_to_map(p))


func _clamp_to_map(p: Vector2) -> Vector2:
	# Inverse iso, clamp to the grid, back to screen.
	var gx := clampf(p.x / Building.TW + p.y / Building.TH, 0, GRID)
	var gy := clampf(p.y / Building.TH - p.x / Building.TW, 0, GRID)
	return Building.iso(gx, gy)


func _on_arrived() -> void:
	Game.larry_pos = larry.position
	if going_into != "":
		_open_place(going_into)
		going_into = ""


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
				var has_items: bool = s.items_sold < s.ITEMS.size()
				var next_item: String = tr(s.ITEMS[s.items_sold][0]) if has_items else ""
				Game.make_button(box, tr("BTN_SELL") % next_item, _act.bind(id, s.sell_next)).disabled = not has_items
			"VINNIE":
				Game.make_button(box, tr("BTN_BORROW") % s.LOAN_SIZE, _act.bind(id, s.borrow))
				Game.make_button(box, tr("BTN_REPAY"), _act.bind(id, s.repay)).disabled = s.debt == 0 or s.money == 0
			"BETS":
				Game.make_button(box, tr("BTN_SPORTS"), Game.go.bind("sports"))
			"CASINO":
				Game.make_button(box, tr("BTN_ROULETTE"), Game.go.bind("roulette"))
		Game.make_button(box, tr("BTN_LEAVE"), func(): panel.visible = false)
	panel.visible = true


func _act(id: String, action: Callable) -> void:
	Game.record(action.call())
	_refresh_hud()
	_open_place(id)
