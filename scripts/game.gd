extends Node
## Autoload "Game": holds the one GameState, the event log, and saves after every change.

const GameState := preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://save.json"
const LOG_LINES := 6

var state: GameState
var log: Array = []
var click := AudioStreamPlayer.new()
var larry_pos := Vector2.ZERO # map position, kept between screens (not saved)
var hub := "home" # where Back leads: the dashboard, or "world" while Larry is out on the map
var open_place := "" # place the map should open straight away (tapped on a dashboard card)
var shown_money := -1 # last cash figure the dashboard showed, for the count-up

# Design tokens: casino noir.
const NAVY := Color("#081421")
const CHARCOAL := Color("#101820")
const GREEN := Color("#116B50")
const GOLD := Color("#D7B46A")
const IVORY := Color("#F4EEDF")
const BURGUNDY := Color("#8D3045")


func _ready() -> void:
	if OS.get_locale_language() == "tr":
		TranslationServer.set_locale("tr")
	_setup_theme()
	RenderingServer.set_default_clear_color(NAVY)
	add_child(click)
	click.stream = load("res://assets/audio/click.ogg")
	state = GameState.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	if data is Dictionary:
		state.from_dict(data.get("state", {}))
		log = data.get("log", [])
	if log.is_empty():
		log = [{"key": "INTRO", "args": []}]
	# Web preview shortcut: index.html#race opens that screen directly.
	if OS.has_feature("web"):
		var hash := str(JavaScriptBridge.eval("location.hash")).trim_prefix("#")
		if hash != "" and ResourceLoader.exists("res://scenes/%s.tscn" % hash):
			go.call_deferred(hash)


## Add results to the log and save. Accepts a result dict or an array of them.
func record(result) -> void:
	for r in (result if result is Array else [result]) + state.check_badges():
		if not r.is_empty():
			log.append(r)
	log = log.slice(-LOG_LINES)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"state": state.to_dict(), "log": log}))


func is_over() -> bool:
	return state.is_over()


func new_game() -> void:
	state = GameState.new()
	log = []
	record({"key": "INTRO", "args": []})


func log_text() -> String:
	var lines := PackedStringArray()
	for e in log:
		lines.append(entry_text(e))
	return "\n\n".join(lines)


func entry_text(e: Dictionary) -> String:
	# String args are translation keys (item names); numbers pass through.
	var args: Array = e.args.map(func(a): return tr(a) if a is String else a)
	return tr(e.key) % args if args else tr(e.key)


func stats_text() -> String:
	var text: String = tr("STATS") % [state.day, state.money, state.debt, state.days_to_rent()]
	if state.debt > 0:
		text += "   " + tr("STATS_DUE") % maxi(state.due_day - state.day, 0)
	return text


func back() -> void:
	go(hub)


func go(scene: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


## Shared screen layout: margin + vertical box, returned for the screen to fill.
func make_screen(owner: Control) -> VBoxContainer:
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	owner.add_child(bg)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	bg.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func make_button(box: Container, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 80
	b.pressed.connect(click.play)
	b.pressed.connect(on_press)
	box.add_child(b)
	return b


const STAKES := [10, 50, 100, -1] # -1 = all in
var stake_choice := 10


func stake() -> int:
	return state.money if stake_choice == -1 else mini(stake_choice, state.money)


func make_stake_row(box: Container) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var group := ButtonGroup.new()
	for v in STAKES:
		var b := make_button(row, tr("STAKE_ALL") if v == -1 else "$%d" % v, func(): stake_choice = v; get_tree().reload_current_scene())
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = v == stake_choice
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func make_label(box: Container, text: String, expand := false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if expand:
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(l)
	return l


## Kenney UI pack + Baloo 2, set on the default theme so every Control picks it up.
func _setup_theme() -> void:
	var t := ThemeDB.get_default_theme()
	var font: FontFile = load("res://assets/fonts/baloo-2-latin-600-normal.woff2")
	font.fallbacks = [load("res://assets/fonts/baloo-2-latin-ext-600-normal.woff2")] # Turkish letters live in the latin-ext file
	t.default_font = font
	t.default_font_size = 30

	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": GREEN, "hover": GREEN.lightened(0.08), "pressed": GREEN.darkened(0.25), "disabled": CHARCOAL.lightened(0.06)}[state]
		sb.border_color = Color(GOLD, 0.15 if state == "disabled" else 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 20; sb.content_margin_right = 20
		sb.content_margin_top = 12; sb.content_margin_bottom = 12
		t.set_stylebox(state, "Button", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", IVORY)
	t.set_color("font_disabled_color", "Button", Color(IVORY, 0.35))

	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_color("font_color", "Label", IVORY)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = NAVY
	bar_bg.set_corner_radius_all(8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)


func card_style(border := GOLD) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = CHARCOAL
	panel.border_color = Color(border, 0.45)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(22)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 8
	panel.set_content_margin_all(18)
	return panel
