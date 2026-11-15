extends Node
var failures := 0
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, title: String) -> void:
	print("PASS " if ok else "FAIL ",title)
	if not ok: failures += 1
func capture(title: String, delay: float = 0.3) -> void:
	await get_tree().create_timer(delay).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/cinematic_%s.png" % title)
func run() -> void:
	var menu := preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await capture("flyby",1.2)
	await capture("pass",1.9)
	await capture("chase",1.4)
	await capture("menu",4.5)
	menu.queue_free()
	await get_tree().process_frame
	var returned_menu := preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(returned_menu)
	check(returned_menu.flight.clock>=8.5 and returned_menu._buttons.modulate.a==1.0,"returning to menu opens on settled flight")
	returned_menu.queue_free()
	await get_tree().process_frame
	GameState.new_session()
	var world := preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var player: CharacterBody3D = world.player
	var ui: CanvasLayer = world.gameplay_ui
	var lift := preload("res://scenes/world/elevator_intro.tscn").instantiate() as Node3D
	world.add_child(lift)
	await lift.play_intro(player)
	player.set_controls_enabled(true)
	world.engineer.begin()
	await capture("greeting",2.7)
	check(ui.is_open() and world.engineer.animation.current_animation == "Idle","lift opens onto animated engineer greeting")
	if ui.is_open(): ui.modal.finished.emit()
	await get_tree().create_timer(1.2).timeout
	check(world.engineer.animation.current_animation == "Walk","guide switches to walking after conversation")
	world.engineer.active = false
	world.engineer.hide()
	player.head.rotation.y = PI
	await capture("mirror",0.4)
	player.head.rotation.y = 0
	player._pitch = -1.30
	player.camera.rotation.x = -1.30
	await capture("suit")
	player._pitch = 0
	player.camera.rotation.x = 0
	lift.queue_free()
	var crew := world.get_node("FacilityDressing").get_children().filter(func(n): return n is SpaceInteractable)
	check(crew.size()==3 and world.engineer.pose.board.get_parent() is BoneAttachment3D,"station crew and hand-held clipboard are present")
	for member in crew:
		if member.role == "scientist":
			player.global_position = member.global_position+Vector3(0,0.05,2.4)
			player.camera.look_at(member.global_position+Vector3.UP)
			member.interact(player)
			await capture("scientist",0.6)
			await ui.close_modal()
	player.set_controls_enabled(false)
	ui.hud.hide()
	for view in [["hall",Vector3(-19,4.05,19),Vector3(-10,3,-4)],["control",Vector3(53,0.05,6.9),Vector3(54,2.2,-6.3)],["project",Vector3(-32,4.05,4.2),Vector3(-32,5.1,-1)],["lab",Vector3(6,4.05,6.5),Vector3(10,5.1,4.6)]]:
		player.global_position = view[1]
		player.camera.look_at(view[2])
		await capture(view[0])
	GameState.files_available = true
	player.global_position = Vector3(-32,4.05,2.2)
	player.camera.look_at(Vector3(-32,5.04,0))
	player._pitch = player.camera.rotation.x
	player.update_eye_offset()
	var original_pose: Transform3D = player.camera.global_transform
	var table := get_tree().get_first_node_in_group("mission_tables")
	await ui.open_mission_table(table)
	check(ui.inspection_camera.current and not player.controls_enabled,"mission desk camera owns inspection")
	await capture("folders")
	await ui.modal.open_folder(table.folders[1])
	check(is_instance_valid(ui.modal.paper) and table.folders[1].open_model.visible,"physical dossier opens onto readable paper")
	await capture("paper")
	# Exercise the real mouse-to-paper mapping, including the release event.
	var desk_ui: Control = ui.modal
	var button_uv: Vector2 = desk_ui.select_button.get_global_rect().get_center()/Vector2(desk_ui.paper_viewport.size)
	var paper_size: Vector2 = desk_ui.paper.mesh.size
	var world_point: Vector3 = desk_ui.paper.to_global(Vector3((button_uv.x-0.5)*paper_size.x,(0.5-button_uv.y)*paper_size.y,0))
	var click_at: Vector2 = ui.inspection_camera.unproject_position(world_point)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = click_at
		click.global_position = click_at
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		desk_ui._input(click)
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	check(GameState.selected_mission == table.folders[1].mission.id,"paper selection button receives projected mouse input")
	if ui.is_open(): await ui.close_modal()
	check(player.camera.current and player.camera.global_basis.is_equal_approx(original_pose.basis) and player.camera.global_position.distance_to(original_pose.origin)<0.1,"inspection returns original player camera")
	player.set_controls_enabled(false)
	var terminal := world.get_node("RocketTerminal")
	player.global_position = terminal.global_position+Vector3(0,0.05,2)
	player.camera.look_at(terminal.global_position+Vector3(0,1.1,0))
	GameState.sandbox = true
	await ui.open_terminal(terminal)
	check(ui.modal.get_parent() == ui and terminal.display.visible,"CRT interface merges into full menu")
	ui._parts = [ui._catalog[1],ui._catalog[4],ui._catalog[8],ui._catalog[9]]
	ui._refresh_parts()
	await capture("terminal")
	await ui.close_modal()
	check(not terminal.display.visible and player.controls_enabled and (DisplayServer.get_name()=="headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),"terminal camera backs out and returns control")
	player.set_controls_enabled(false)
	ui.show_dialogue("Engineer",["Welcome to Orion. Every mission begins with a question.","Let's build something."])
	await get_tree().create_timer(0.25).timeout
	check(ui.modal.line.visible_characters > 0 and ui.modal.line.visible_characters < ui.modal.line.text.length(),"dialogue types progressively")
	ui.modal.advance()
	check(ui.modal.index == 0 and ui.modal.line.visible_characters == -1,"advance first reveals current line")
	ui.modal.advance()
	check(ui.modal.index == 1,"next advance changes line")
	await ui.close_modal()
	terminal.set_focused(true)
	check(not terminal._outline_meshes.is_empty(),"focused terminal gets white mesh outline")
	terminal.set_focused(false)
	GameState.set_objective("Rocket Assembly","",Vector3(-16,0,-5))
	player.global_position = Vector3(-18,0.1,2)
	await get_tree().create_timer(1.0).timeout
	check(world.get_node("ObjectiveTrail").mesh != null,"navigation path produces objective ribbon")
	world._on_pause_requested()
	await capture("pause")
	check(get_tree().paused,"pause freezes simulation")
	world._pause_overlay._resume()
	print("CINEMATIC REVIEW / failures ",failures)
	get_tree().quit(failures)
