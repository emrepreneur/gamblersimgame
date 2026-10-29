extends Node2D
## Placeholder isometric building drawn in code. Node position = front (bottom) corner of its footprint.

const TW := 128.0
const TH := 64.0

var id := ""
var footprint := Vector2i(2, 2)
var height := 80.0
var color := Color.WHITE
var label: Label


static func iso(x: float, y: float) -> Vector2:
	return Vector2((x - y) * TW / 2.0, (x + y) * TH / 2.0)


func setup(place: Dictionary) -> void:
	id = place.id
	footprint = place.size
	height = place.h
	color = Color(place.color)
	position = iso(place.cell.x + footprint.x, place.cell.y + footprint.y)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("#fff6c2"))
	label.add_theme_color_override("font_outline_color", Color("#1a1022"))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	refresh_label()


func refresh_label() -> void:
	label.text = tr("PLACE_" + id)
	label.reset_size()
	var top := (_left() + _right()) / 2.0 + Vector2(0, -height - 30)
	label.position = top - label.size / 2.0


func _left() -> Vector2: return iso(-footprint.x, 0)
func _right() -> Vector2: return iso(0, -footprint.y)
func _back() -> Vector2: return iso(-footprint.x, -footprint.y)


## Door is just in front of the front corner.
func door() -> Vector2:
	return position + Vector2(0, 18)


## Screen-space outline, for tap hit tests.
func hull() -> PackedVector2Array:
	var up := Vector2(0, -height)
	var pts := PackedVector2Array([_left(), Vector2.ZERO, _right(), _right() + up, _back() + up, _left() + up])
	for i in pts.size():
		pts[i] += position
	return pts


func _draw() -> void:
	var up := Vector2(0, -height)
	var f := Vector2.ZERO
	var l := _left()
	var r := _right()
	draw_colored_polygon([l, f, f + up, l + up], color.darkened(0.25))
	draw_colored_polygon([f, r, r + up, f + up], color.darkened(0.45))
	draw_colored_polygon([l + up, f + up, r + up, _back() + up], color.lightened(0.15))
	# Door on the left face, next to the front corner.
	var d0 := f.lerp(l, 0.12)
	var d1 := f.lerp(l, 0.32)
	draw_colored_polygon([d0, d1, d1 + Vector2(0, -40), d0 + Vector2(0, -40)], Color("#2b1d14"))
	# Windows: a lit row on each face.
	for t in [0.55, 0.8]:
		var w := f.lerp(l, t) + up * 0.55
		draw_colored_polygon([w, w + (l - f) * 0.12, w + (l - f) * 0.12 + Vector2(0, -16), w + Vector2(0, -16)], Color("#ffe08a"))
	for t in [0.3, 0.65]:
		var w := f.lerp(r, t) + up * 0.55
		draw_colored_polygon([w, w + (r - f) * 0.15, w + (r - f) * 0.15 + Vector2(0, -16), w + Vector2(0, -16)], Color("#ffd166"))
	draw_polyline(PackedVector2Array([l + up, f + up, r + up, _back() + up, l + up]), Color(0, 0, 0, 0.35), 2.0)
