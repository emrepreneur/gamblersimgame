extends Node
## Autoload "Game": holds the one GameState, the event log, and saves after every change.

const GameState := preload("res://scripts/game_state.gd")
const SAVE_PATH := "user://save.json"
const LOG_LINES := 6

var state: GameState
var log: Array = []
var larry_pos := Vector2.ZERO # map position, kept between screens (not saved)


func _ready() -> void:
	if OS.get_locale_language() == "tr":
		TranslationServer.set_locale("tr")
	# Default theme, so it also reaches UI under CanvasLayers (window theme doesn't cross Node2D parents).
	ThemeDB.get_default_theme().default_font_size = 30
	RenderingServer.set_default_clear_color(Color("#1b1420"))
	state = GameState.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else null
	if data is Dictionary:
		state.from_dict(data.get("state", {}))
		log = data.get("log", [])
	if log.is_empty():
		log = [{"key": "INTRO", "args": []}]


## Add results to the log and save. Accepts a result dict or an array of them.
func record(result) -> void:
	for r in (result if result is Array else [result]):
		if not r.is_empty():
			log.append(r)
	if state.is_over() and log[-1].key != "END_DEBT":
		log.append({"key": "END_DEBT", "args": []})
	log = log.slice(-LOG_LINES)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"state": state.to_dict(), "log": log}))


func is_over() -> bool:
	return log[-1].key.begins_with("END_")


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
	return tr(e.key) % e.args if e.args else tr(e.key)


func stats_text() -> String:
	return tr("STATS") % [state.day, state.money, state.debt, state.days_to_rent()]


func go(scene: String) -> void:
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


## Shared screen layout: margin + vertical box, returned for the screen to fill.
func make_screen(owner: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	owner.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func make_button(box: Container, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 80
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
