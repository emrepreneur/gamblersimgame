extends Node2D
## A 3D Kenney mini character rendered live into a sprite, so it fits the 2D isometric map.
## Walks along a list of map points, playing its walk/idle animations.

signal arrived

const VIEW := Vector2i(200, 240)
const SPEED := 240.0 # px/s on the map

var path: Array = []
var anim: AnimationPlayer
var model: Node3D
var sprite := Sprite2D.new()


func setup(glb: String, scale_px := 1.0) -> void:
	var vp := SubViewport.new()
	vp.size = VIEW
	vp.transparent_bg = true
	vp.own_world_3d = true
	add_child(vp)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	# Dimetric 2:1 view, same as the Kenney isometric tiles: 45° yaw, ~30° down.
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(4, 3.27 + 0.55, 4), Vector3(0, 0.55, 0))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.85)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)

	model = load(glb).instantiate()
	vp.add_child(model)
	anim = model.find_children("*", "AnimationPlayer", true, false)[0]
	for a in ["idle", "walk"]:
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.play("idle")

	sprite.texture = vp.get_texture()
	sprite.scale = Vector2.ONE * scale_px
	# Feet (bottom-centre of the view, minus a little margin) sit on the node's position.
	sprite.offset = Vector2(0, -VIEW.y / 2.0 + 28)
	add_child(sprite)


func walk(points: Array) -> void:
	path = points
	if path.is_empty():
		arrived.emit()
		return
	anim.speed_scale = 1.5 # legs keep up with the faster pace
	anim.play("walk")


func face(screen_dir: Vector2) -> void:
	# Screen direction back to map axes: +x map = down-right, +y map = down-left on screen.
	var gx := screen_dir.x / 66.0 + screen_dir.y / 33.0
	var gy := screen_dir.y / 33.0 - screen_dir.x / 66.0
	if absf(gx) + absf(gy) > 0.01:
		model.rotation.y = atan2(gx, gy)


func play(name: String) -> void:
	anim.play(name)


func _process(delta: float) -> void:
	if path.is_empty():
		return
	var target: Vector2 = path[0]
	var step := target - position
	face(step)
	if step.length() <= SPEED * delta:
		position = target
		path.pop_front()
		if path.is_empty():
			anim.speed_scale = 1.0
			anim.play("idle")
			arrived.emit()
		return
	position += step.normalized() * SPEED * delta
