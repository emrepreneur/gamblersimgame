extends SceneTree
## Opens every screen (catches runtime errors). Run: godot --headless --script res://tests/smoke_screens.gd
func _init() -> void:
	await process_frame
	for scene in ["world", "sports", "roulette", "world"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await process_frame
		await process_frame
		print("opened ", scene, " buttons=", current_scene.find_children("*", "Button", true, false).size())
	quit()
