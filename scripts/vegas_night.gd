extends Node
## Night-time Las Vegas dressing for the map, all drawn in code:
## starry sky, desert with cacti around the block, street lamps with light pools, glowing neon signs.

const LAMP_GLOW := Color("#ffcf7a")


## Sky: stars on a layer that doesn't move with the camera.
static func add_sky(world: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	world.add_child(layer)
	var sky := Control.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stars := []
	for i in 140:
		stars.append([Vector2(rng.randf() * 720, rng.randf() * 1280), rng.randf_range(0.8, 2.4), rng.randf() * TAU])
	sky.draw.connect(func():
		var h := sky.size.y
		for k in 12: # vertical gradient: deep purple to a warm city glow at the bottom
			var t := k / 12.0
			sky.draw_rect(Rect2(0, h * t, sky.size.x, h / 12.0 + 1), Color("#140c26").lerp(Color("#4a2650"), t * t))
		var now := Time.get_ticks_msec() / 1000.0
		for s in stars:
			var a := 0.5 + 0.5 * sin(now * 2.0 + s[2])
			sky.draw_circle(s[0] * sky.size / Vector2(720, 1280), s[1], Color(1, 1, 0.9, 0.3 + 0.7 * a)))
	var t := Timer.new()
	t.wait_time = 0.1
	t.autostart = true
	t.timeout.connect(sky.queue_redraw)
	sky.add_child(t)


## Desert floor under and around the block, with cacti and rocks.
static func add_desert(parent: Node, grid: int, top_corner: Callable) -> void:
	var d := Node2D.new()
	d.z_index = -5
	parent.add_child(d)
	var pad := 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var props := []
	for i in 110:
		var c := Vector2i(rng.randi_range(-pad, grid + pad), rng.randi_range(-pad, grid + pad))
		if c.x >= -1 and c.x <= grid and c.y >= -1 and c.y <= grid:
			continue
		props.append([top_corner.call(c) + Vector2(rng.randf_range(-30, 30), 33 + 101 - 33), rng.randi() % 3, rng.randf_range(0.7, 1.3)])
	props.sort_custom(func(a, b): return a[0].y < b[0].y)
	d.draw.connect(func():
		var a: Vector2 = top_corner.call(Vector2i(-pad, -pad)) + Vector2(0, 68)
		var b: Vector2 = top_corner.call(Vector2i(grid + pad, -pad)) + Vector2(0, 68)
		var c: Vector2 = top_corner.call(Vector2i(grid + pad, grid + pad)) + Vector2(0, 68)
		var e: Vector2 = top_corner.call(Vector2i(-pad, grid + pad)) + Vector2(0, 68)
		d.draw_colored_polygon([a, b, c, e], Color("#c99a5b"))
		# Dune streaks.
		var r2 := RandomNumberGenerator.new()
		r2.seed = 3
		for i in 90:
			var p: Vector2 = top_corner.call(Vector2i(r2.randi_range(-pad, grid + pad), r2.randi_range(-pad, grid + pad))) + Vector2(0, 68)
			d.draw_line(p, p + Vector2(r2.randf_range(40, 120), r2.randf_range(-20, 20) * 0.5), Color("#b5854a", 0.6), 3)
		for pr in props:
			_draw_prop(d, pr[0], pr[1], pr[2]))


static func _draw_prop(ci: CanvasItem, p: Vector2, kind: int, s: float) -> void:
	ci.draw_set_transform(p, 0, Vector2(s, s))
	ci.draw_circle(Vector2(0, 0), 16, Color(0, 0, 0, 0.18)) # shadow
	match kind:
		0, 1: # saguaro
			var g := Color("#3f8f4a")
			var dark := Color("#2d6b36")
			ci.draw_rect(Rect2(-8, -70, 16, 70), g)
			ci.draw_circle(Vector2(0, -70), 8, g)
			ci.draw_rect(Rect2(-24, -46, 10, 22), g)
			ci.draw_rect(Rect2(-24, -28, 20, 8), g)
			ci.draw_circle(Vector2(-19, -46), 5, g)
			if kind == 0:
				ci.draw_rect(Rect2(14, -58, 10, 24), g)
				ci.draw_rect(Rect2(4, -38, 20, 8), g)
				ci.draw_circle(Vector2(19, -58), 5, g)
			ci.draw_line(Vector2(3, -72), Vector2(3, -4), dark, 3)
		2: # rock
			ci.draw_colored_polygon([Vector2(-22, 0), Vector2(-14, -16), Vector2(4, -22), Vector2(20, -10), Vector2(24, 0)], Color("#8c6a4f"))
			ci.draw_colored_polygon([Vector2(4, -22), Vector2(20, -10), Vector2(24, 0), Vector2(6, 0)], Color("#6e513b"))
	ci.draw_set_transform(Vector2.ZERO)


## Night tint for everything on the map's canvas layer; lights and signs cut through it.
static func add_night(world: Node) -> void:
	var m := CanvasModulate.new()
	m.color = Color("#8c84c4")
	world.add_child(m)


static func light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1, 0.5)
	t.width = 256
	t.height = 256
	return t


## Fake light: an additive glow sprite. Much cheaper than PointLight2D on phones and the web.
static func add_light(parent: Node, p: Vector2, col: Color, energy := 1.0, scale := 1.6) -> Sprite2D:
	var l := Sprite2D.new()
	l.texture = _light_tex
	l.modulate = Color(col, 0.32 * energy)
	l.scale = Vector2(scale * 1.2, scale * 0.65) # flattened: a pool on the ground
	l.position = p
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = mat
	parent.add_child(l)
	return l


static var _light_tex := light_texture()


## Street lamp drawn in code (post + head), with its light pool.
static func add_lamp(parent: Node, p: Vector2) -> void:
	var lamp := Node2D.new()
	lamp.position = p
	parent.add_child(lamp)
	lamp.draw.connect(func():
		lamp.draw_line(Vector2(0, 0), Vector2(0, -62), Color("#2b2b38"), 4)
		lamp.draw_line(Vector2(0, -62), Vector2(12, -66), Color("#2b2b38"), 4)
		lamp.draw_circle(Vector2(14, -64), 6, Color("#fff1c4")))
	add_light(lamp, Vector2(10, 0), LAMP_GLOW, 1.8, 0.9)


## A neon sign: glow halo + bright tube text, flickers now and then. Lives on an unlit layer.
static func add_neon(layer: Node, text: String, col: Color, centre: Vector2, size_px: int, bulbs := false) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var glow := Label.new()
	var tube := Label.new()
	for l in [glow, tube]:
		l.text = text
		l.add_theme_font_size_override("font_size", size_px)
		holder.add_child(l)
	glow.add_theme_color_override("font_color", col)
	glow.add_theme_color_override("font_outline_color", Color(col, 0.35))
	glow.add_theme_constant_override("outline_size", size_px / 2)
	tube.add_theme_color_override("font_color", col.lightened(0.6))
	tube.add_theme_color_override("font_outline_color", col)
	tube.add_theme_constant_override("outline_size", 4)
	tube.reset_size()
	glow.reset_size()
	var sz := tube.size
	holder.size = sz
	holder.position = centre - Vector2(sz.x / 2, sz.y)
	if bulbs:
		# Marquee: a frame of bulbs chasing around the sign.
		var frame := Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.position = Vector2(-18, -10)
		frame.size = sz + Vector2(36, 20)
		holder.add_child(frame)
		holder.move_child(frame, 0)
		frame.draw.connect(func():
			var r := Rect2(Vector2.ZERO, frame.size)
			frame.draw_rect(r, Color("#1b1030", 0.85))
			frame.draw_rect(r, Color("#e8b923"), false, 3)
			var phase := int(Time.get_ticks_msec() / 120)
			var pts := []
			var n := 18
			for i in n:
				pts.append(r.position + Vector2(r.size.x * i / n, 0))
			for i in 4:
				pts.append(r.position + Vector2(r.size.x, r.size.y * i / 4))
			for i in n:
				pts.append(r.position + Vector2(r.size.x * (n - i) / n, r.size.y))
			for i in 4:
				pts.append(r.position + Vector2(0, r.size.y * (4 - i) / 4))
			for i in pts.size():
				var on := (i + phase) % 3 == 0
				frame.draw_circle(pts[i], 5, Color("#fff3a0") if on else Color("#7a5a10")))
		var t := Timer.new()
		t.wait_time = 0.12
		t.autostart = true
		t.timeout.connect(frame.queue_redraw)
		frame.add_child(t)
	# Random flicker.
	var flick := Timer.new()
	flick.wait_time = randf_range(2.0, 6.0)
	flick.autostart = true
	flick.timeout.connect(func():
		var tw := holder.create_tween()
		tw.tween_property(tube, "modulate:a", 0.35, 0.05)
		tw.tween_property(tube, "modulate:a", 1.0, 0.05)
		tw.tween_property(tube, "modulate:a", 0.5, 0.04)
		tw.tween_property(tube, "modulate:a", 1.0, 0.08)
		flick.wait_time = randf_range(2.0, 7.0))
	holder.add_child(flick)
	return holder
