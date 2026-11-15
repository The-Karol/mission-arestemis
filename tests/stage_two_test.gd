extends Node

var failures := 0
var checks := 0
var world: Node3D
var actor: CharacterBody3D

func _ready() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func tick(count: int = 1) -> void:
	for index in range(count):
		await get_tree().physics_frame

func wait_reader(reader: CartridgeReader) -> void:
	for frame in range(90):
		if not reader.busy:
			return
		await get_tree().physics_frame

func run() -> void:
	var state := get_tree().root.get_node("GameState")
	check(state.missions.size() == 10, "Ten data-driven missions")
	var combinations: Dictionary = {}
	for iteration in range(30):
		state.new_session()
		var ids: Array = []
		for offer in state.offered_missions:
			ids.append(offer.id)
		check(ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "Three distinct proposals in session %d" % iteration)
		combinations[str(ids)] = true
	check(combinations.size() > 1, "New sessions randomize proposals")
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	actor = world.player
	actor.take_item(get_tree().get_nodes_in_group("cartridges")[0])
	await tick(4)
	check(get_tree().get_nodes_in_group("terminals").size() == 4, "Four physical terminals")
	print("STATIC_VISUALS boxes=", world.get_meta("static_box_count", 0), " batches=", world.get_meta("static_batch_count", 0))
	check(world.navigation.navigation_mesh.get_polygon_count() > 0, "Baked navigation is loaded")
	var engineer: CharacterBody3D = world.engineer
	await tick(120)
	engineer.begin()
	actor.set_controls_enabled(true)
	engineer.talk()
	check(actor.mode == "dialogue" and not actor.controls_enabled, "First meeting locks walking and mouse-look")
	var dialogue: Control = actor.ui.modal
	while is_instance_valid(dialogue) and dialogue.index < dialogue.lines.size():
		dialogue.advance()
		if not actor.ui.is_open():
			break
	check(engineer.state == "guiding" and actor.controls_enabled, "Dialogue callback starts escort")
	actor.global_position = Vector3(-32, 0.1, 18)
	var start: Vector3 = engineer.global_position
	actor.global_position += Vector3(0, 0, 15)
	await tick(60)
	check(engineer.waiting and engineer.global_position.distance_to(start) < 0.2, "Engineer waits for a distant player")
	for frame in range(7000):
		actor.global_position = engineer.global_position + Vector3(0.8, 0.05, 0.8)
		actor.velocity = Vector3.ZERO
		await tick()
		if engineer.state == "at_office":
			break
	check(engineer.state == "at_office" and engineer.global_position.y > 3.5, "Engineer navigates doors, stairs and upper gallery to Project Office")
	print("ENGINEER_END ", engineer.global_position, " state=", engineer.state, " nav_finished=", engineer.agent.is_navigation_finished())
	if engineer.state != "at_office":
		print("ENGINEER_PATH ", engineer.agent.get_current_navigation_path(), " next=", engineer.agent.get_next_path_position())
	await tick(3)
	if actor.ui.is_open():
		actor.ui.modal.finished.emit()
	check(state.files_available, "Arrival dialogue enables mission files")
	# Failures above should not prevent reporting the independent systems.
	state.files_available = true
	var mission_id: String = state.offered_missions[0].id
	var file: Area3D = world.get_node("MissionSelectionTable/MissionFile1")
	file.interact(actor)
	check(actor.ui.is_open() and actor.mode == "terminal", "Physical mission file opens readable UI")
	actor.ui._confirm_mission(state.offered_missions[0])
	check(state.selected_mission == "", "Opening confirmation does not select a mission")
	actor.ui.close_modal()
	var spacecraft: ComputerTerminal = world.get_node("SpacecraftTerminal")
	var rocket: ComputerTerminal = world.get_node("RocketTerminal")
	var verification: ComputerTerminal = world.get_node("VerificationTerminal")
	var launch: ComputerTerminal = world.get_node("LaunchTerminal")
	check(spacecraft.access_error().contains("No active mission"), "Terminal rejects missing mission")
	check(state.select_mission(mission_id), "One offered mission can be selected")
	check(not state.select_mission(state.offered_missions[1].id), "Second mission selection is rejected")
	check(state.mission_stage == state.Stage.SPACECRAFT_DESIGN, "Mission starts at spacecraft design")
	if actor.ui.is_open():
		actor.ui.close_modal()
	check(rocket.access_error().contains("not inserted"), "Rocket terminal rejects an empty reader")
	check(not rocket.reader.remove_cartridge(actor), "Removing from an empty reader fails safely")
	check(spacecraft.reader.insert_cartridge(actor),"Use the cartridge recovered during the first objective")
	await wait_reader(spacecraft.reader)
	actor.ui.open_terminal(spacecraft)
	check(actor.mode == "terminal" and not actor.controls_enabled, "Computer mode blocks movement")
	var result := spacecraft.save_spacecraft()
	check(result.contains("SAVED"), "Spacecraft terminal writes a concept")
	await wait_reader(spacecraft.reader)
	var cart: DataCartridge = spacecraft.reader.cartridge
	check(cart.mission_id == mission_id and not cart.spacecraft_design.is_empty(), "The cartridge owns the mission and spacecraft records")
	actor.ui.close_modal()
	check(spacecraft.reader.remove_cartridge(actor), "Cartridge can be ejected")
	await wait_reader(spacecraft.reader)
	check(actor.carried_item == cart and cart.get_parent() == actor.carry_anchor, "Ejected cartridge attaches to carry anchor")
	var second: DataCartridge = load("res://scenes/items/data_cartridge.tscn").instantiate()
	world.add_child(second)
	check(not actor.take_item(second), "Player cannot carry a second cartridge")
	check(rocket.reader.insert_cartridge(actor), "Cartridge inserts into another computer")
	await wait_reader(rocket.reader)
	check(actor.carried_item == null and rocket.reader.cartridge == cart, "Reader transfers ownership from player's hand")
	actor.take_item(second)
	check(not rocket.reader.insert_cartridge(actor), "Occupied reader rejects insertion")
	check(not rocket.reader.remove_cartridge(actor), "Full hands prevent removal")
	actor.carried_item = null
	second.queue_free()
	check(rocket.reader.cartridge.spacecraft_design.type == state.mission().spacecraft_type, "Spacecraft data survives transfer")
	cart.mission_id = "another_mission"
	check(rocket.access_error().contains("another mission"), "Terminal rejects a cartridge from another mission")
	cart.mission_id = mission_id
	actor.ui.open_terminal(rocket)
	check(actor.ui._catalog.size() >= 13, "Rocket catalog is loaded from separate data")
	check(not rocket.save_rocket([]).contains("SAVED"), "Incomplete rocket concept cannot be saved")
	var parts: Array = []
	for part in actor.ui._catalog:
		if part.id in ["engine_s", "tank_m", "fairing_s", "avionics", "payload"]:
			parts.append(part)
	result = rocket.save_rocket(parts)
	check(result.contains("SAVED") and not cart.rocket_design.is_empty(), "Rocket concept writes to the same cartridge")
	parts.clear()
	check(cart.rocket_design.parts.size() == 5, "Cartridge records are independent copies of UI component arrays")
	actor.ui.close_modal()
	rocket.reader.remove_cartridge(actor)
	await wait_reader(rocket.reader)
	verification.reader.insert_cartridge(actor)
	await wait_reader(verification.reader)
	actor.ui.open_terminal(verification)
	var payload_type: String = cart.rocket_design.payload_type
	cart.rocket_design.payload_type = "Wrong spacecraft"
	check(verification.run_verification().contains("FAIL"), "Verification rejects a mismatched payload")
	cart.rocket_design.payload_type = payload_type
	result = verification.run_verification()
	check(result.contains("FAIL") and cart.verification_status != "DATA_VERIFIED", "Verification rejects the underpowered vehicle and lists its faults")
	actor.ui.close_modal()
	verification.reader.remove_cartridge(actor)
	await wait_reader(verification.reader)
	# Drop and reacquire in an upstairs room without crossing a wall.
	actor.global_position = Vector3(7, 4.1, 10)
	await tick(3)
	check(actor.drop_carried_item(), "Q places the cartridge on a supporting upper-floor surface")
	check(cart.state == "world" and cart.global_position.y > 3.9 and cart.collision_layer == 4, "Dropped cartridge is physical and interactable upstairs")
	cart.interact(actor)
	check(actor.carried_item == cart, "Dropped cartridge can be picked up")
	launch.reader.insert_cartridge(actor)
	await wait_reader(launch.reader)
	check(not launch.access_error().is_empty(), "Mission Control rejects the vehicle until its engineering faults are corrected")
	actor.ui.open_terminal(launch)
	check(actor.ui.is_open(), "Launch status UI opens without running a launch")
	actor.ui.close_modal()
	# Edits must invalidate all downstream approvals.
	cart.write_spacecraft(mission_id, cart.spacecraft_design)
	check(not cart.rocket_design.is_empty() and cart.verification_status == "NOT_CHECKED", "Editing spacecraft preserves the rocket but invalidates approval")
	check(launch.access_error().contains("not been verified"), "Launch rejects the launcher until the updated payload is verified")
	# Raycast occlusion: a world collider must win over an interaction behind it.
	actor.global_position = Vector3(-32, 4.05, 2)
	actor.head.rotation = Vector3.ZERO
	actor.camera.rotation = Vector3(-0.35, 0, 0)
	await tick(2)
	actor._update_interaction()
	check(actor.interaction_ray.collision_mask == 13, "Interaction ray checks world occlusion and interaction areas")
	# Aim the actual camera ray at each tabletop file from a normal standing
	# position. The desk collider must not swallow the interaction.
	for index in range(3):
		var mission_file: Area3D = world.get_node("MissionSelectionTable/MissionFile%d" % (index + 1))
		actor.global_position = Vector3(mission_file.global_position.x, 4.05, 1.7)
		actor.camera.look_at(mission_file.global_position + Vector3.UP * 0.06)
		actor._pitch = actor.camera.rotation.x
		await tick(2)
		actor._update_interaction()
		check(actor.focused_interactable == mission_file, "Camera ray reaches mission file %d above table collision" % (index + 1))
	# An isolated interaction area behind a world collider must be occluded.
	var area := SpaceInteractable.new()
	world.add_child(area)
	area.position = Vector3(-32, 5.4, 1.0)
	SpaceVisuals.interaction_shape(area, Vector3(0.5, 0.5, 0.2))
	SpaceVisuals.box(world, "TestOccluder", Vector3(1, 1, 0.2), Vector3(-32, 5.4, 1.4), Color.GRAY, true)
	actor.global_position = Vector3(-32, 4.05, 2.5)
	actor.camera.look_at(area.global_position)
	actor._pitch = actor.camera.rotation.x
	await tick(2)
	actor._update_interaction()
	check(actor.focused_interactable == null, "World walls block interaction with objects behind them")
	actor.ui.open_map()
	check(actor.ui.is_open() and not actor.controls_enabled, "Map opens with both floors and locks movement")
	actor.ui.close_modal()
	check(actor.controls_enabled, "Closing the map restores walking")
	print("STAGE_TWO_RESULT ", checks - failures, "/", checks, " passed; failures=", failures)
	if OS.has_feature("web"):
		var summary := CanvasLayer.new()
		summary.layer = 30
		add_child(summary)
		var center := CenterContainer.new()
		summary.add_child(center)
		SpaceUI.fill(center)
		var panel := SpaceUI.panel(center, 32)
		var content := SpaceUI.column(panel, 16)
		SpaceUI.label(content, "ORION / WEB SCENARIO TEST", 16, SpaceUI.ACCENT)
		SpaceUI.label(content, "%d / %d CHECKS PASSED" % [checks - failures, checks], 30, SpaceUI.GREEN if failures == 0 else Color.ORANGE_RED)
		SpaceUI.label(content, "Engineer escort / Mission files / Four terminals\nPhysical cartridge transfer / Error handling / Map", 18)
		SpaceUI.label(content, "Godot 4.7.2 / Compatibility / Single-threaded WebAssembly", 14, SpaceUI.MUTED)
		get_tree().paused = true
		return
	get_tree().quit(1 if failures else 0)
