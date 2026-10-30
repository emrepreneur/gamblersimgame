extends SceneTree
## Opens every screen, then plays through Joey's visit by pressing his buttons. Catches runtime errors.
## Run: godot --headless --script res://tests/smoke_screens.gd

func buttons() -> Array:
	return current_scene.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)


func _init() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.new_game()
	for scene in ["world", "sports", "roulette", "race", "motel", "blackjack", "world"]:
		change_scene_to_file("res://scenes/%s.tscn" % scene)
		await process_frame
		await process_frame
		print("opened ", scene, " buttons=", buttons().size())

	# Joey shows up on load when a loan is due; press buttons until he's gone.
	for round in 3:
		game.new_game()
		game.state.borrow(100)
		game.state.day = game.state.due_day
		game.state.money = 30 * round
		reload_current_scene()
		# Joey walks over first; wait until his panel is up.
		for f in 1200:
			await process_frame
			if current_scene and current_scene.get("panel") and current_scene.panel.visible:
				break
		var pressed := []
		for i in 6:
			var bs := buttons().filter(func(b): return b.text != "English" and b.text != "Türkçe")
			if bs.is_empty() or not game.state.collection_due():
				break
			var b: Button = bs[(round + i) % bs.size()]
			pressed.append(b.text)
			b.pressed.emit()
			await process_frame
		print("joey round ", round, ": ", pressed, " -> step=", game.state.step, " debt=", game.state.debt)
	# Pawn shop: sell two items, open the panel, buy one back via its button.
	game.new_game()
	reload_current_scene()
	await process_frame
	await process_frame
	game.state.sell_next(); game.state.sell_next()
	current_scene._open_place("PAWN")
	await process_frame
	var labels := buttons().map(func(b): return b.text)
	print("pawn: ", labels)
	for b in buttons():
		if b.text.begins_with(tr("BTN_BUYBACK").get_slice("%", 0)) and not b.disabled:
			b.pressed.emit()
			break
	await process_frame
	print("after buyback: owned=", game.state.owned.size(), " shelf=", game.state.shelf.size(), " money=", game.state.money)
	game.new_game()
	quit()
