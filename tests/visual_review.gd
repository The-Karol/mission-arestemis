extends Node

func _ready() -> void:
	call_deferred("review")

func review() -> void:
	var world := load("res://scenes/world/world.tscn").instantiate() as Node3D
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var actor: CharacterBody3D = world.player
	var mode := "project"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review="):
			mode = argument.trim_prefix("--review=")
	GameState.files_available = true
	world.engineer.visible = true
	actor.global_position = Vector3(-32, 4.05, 3.5)
	actor.camera.rotation.x = -0.2
	if mode in ["rocket", "spacecraft", "verification", "mission"]:
		GameState.select_mission(GameState.offered_missions[0].id)
		if actor.ui.is_open():
			actor.ui.close_modal()
		world.engineer.active = false
		if mode == "mission":
			actor.ui.open_mission(GameState.offered_missions[0])
		elif mode == "spacecraft":
			actor.ui.open_terminal(world.get_node("SpacecraftTerminal"))
		else:
			var terminal: ComputerTerminal = world.get_node("RocketTerminal")
			var cart := terminal.reader.produce_cartridge()
			cart.write_spacecraft(GameState.selected_mission, {"type": GameState.mission().spacecraft_type, "components": GameState.mission().instruments})
			await get_tree().create_timer(0.5).timeout
			actor.ui.open_terminal(terminal)
			for part in actor.ui._catalog:
				if part.id in ["engine_m", "tank_m", "fairing_s", "avionics", "payload"]:
					actor.ui._parts.append(part)
			actor.ui._refresh_parts()
	if mode == "hall":
		actor.global_position = Vector3(-18, 4.1, 19)
		actor.head.rotation.y = -0.2
		actor.camera.rotation.x = -0.2
	if mode == "project":
		actor.camera.rotation.x = -0.3
		GameState.set_objective("Choose a mission", "Project Office / Level 02 / Read the three files on the table.", Vector3(-32, 4, 0))
	if mode == "map":
		actor.ui.open_map()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var output := "res://build/review_%s.png" % mode
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("VISUAL_REVIEW ", output, " save=", error)
	get_tree().quit(error)
