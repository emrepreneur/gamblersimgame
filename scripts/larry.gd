extends Node2D
## Placeholder Larry: drawn in code, walks in a straight line to a target.

signal arrived

const SPEED := 240.0

var target := Vector2.ZERO
var walking := false
var t := 0.0
var facing := 1.0


func walk_to(p: Vector2) -> void:
	target = p
	walking = true


func _process(delta: float) -> void:
	if not walking:
		return
	t += delta
	var step := target - position
	if step.length() <= SPEED * delta:
		position = target
		walking = false
		queue_redraw()
		arrived.emit()
		return
	if absf(step.x) > 1:
		facing = signf(step.x)
	position += step.normalized() * SPEED * delta
	queue_redraw()


func _draw() -> void:
	var bob := absf(sin(t * 12.0)) * 4.0 if walking else 0.0
	var swing := sin(t * 12.0) * 6.0 if walking else 0.0
	draw_set_transform(Vector2(0, -bob), 0, Vector2(facing, 1))
	draw_circle(Vector2(0, bob), 16, Color(0, 0, 0, 0.25)) # shadow (stays on the ground)
	draw_line(Vector2(-6, -24), Vector2(-6 + swing, 0), Color("#3b3b58"), 7) # legs
	draw_line(Vector2(6, -24), Vector2(6 - swing, 0), Color("#3b3b58"), 7)
	draw_rect(Rect2(-14, -58, 28, 36), Color("#c0392b")) # loud shirt
	draw_rect(Rect2(-14, -58, 6, 36), Color("#f1c40f"))
	draw_circle(Vector2(0, -72), 14, Color("#f2c9a0")) # head
	draw_rect(Rect2(-16, -90, 32, 6), Color("#5d4037")) # hat brim
	draw_rect(Rect2(-10, -100, 20, 12), Color("#5d4037"))
	draw_circle(Vector2(6, -74), 2.5, Color.BLACK) # eye
	draw_line(Vector2(0, -64), Vector2(9, -65), Color("#7a3e2b"), 2) # smirk
