extends Node3D

const FLOOR_ONE := preload("res://scenes/world/floor_01.tscn")
const FLOOR_TWO := preload("res://scenes/world/floor_02.tscn")
const CONNECTOR := preload("res://scenes/world/connector_corridor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ELEVATOR_SCENE := preload("res://scenes/world/elevator_intro.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const ENGINEER_SCENE := preload("res://scenes/npc/engineer_guide.tscn")

@export var skip_elevator_intro := false

signal presentation_ready
var ready_to_play := false

var player: CharacterBody3D
var _pause_overlay: CanvasLayer
var engineer: CharacterBody3D
var gameplay_ui: CanvasLayer
var navigation: NavigationRegion3D

func _ready() -> void:
	GameAudio.menu_music(false)
	var resuming:=not SaveStore.pending.is_empty()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameAudio.ambience("facility")
	tree_exiting.connect(func(): GameAudio.ambience(""))
	var first_floor = FLOOR_ONE.instantiate()
	first_floor.name = "Floor01"
	add_child(first_floor)
	var second_floor = FLOOR_TWO.instantiate()
	second_floor.name = "Floor02"
	add_child(second_floor)
	var connector = CONNECTOR.instantiate()
	connector.name = "CUZConnector"
	add_child(connector)
	var upper_connector = CONNECTOR.instantiate()
	upper_connector.name = "CUZConnectorFloor02"
	upper_connector.position.y = 4.0
	add_child(upper_connector)
	var shell := Node3D.new()
	shell.set_script(preload("res://scripts/gameplay/facility_shell.gd"))
	shell.name = "FacilityShell"
	add_child(shell)
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player"
	add_child(player)
	player.pause_requested.connect(_on_pause_requested)
	gameplay_ui = preload("res://scenes/ui/gameplay_ui.tscn").instantiate()
	add_child(gameplay_ui)
	gameplay_ui.configure(player)
	var dressing := Node3D.new()
	dressing.set_script(preload("res://scripts/gameplay/facility_dressing.gd"))
	dressing.name = "FacilityDressing"
	add_child(dressing)
	dressing.dress(self)
	var table := preload("res://scenes/missions/mission_selection_table.tscn").instantiate()
	table.position = Vector3(-32, 4, 0)
	add_child(table)
	for entry in [["spacecraft", Vector3(10, 4, 5.5)], ["rocket", Vector3(-17, 0, -5.5)], ["verification", Vector3(10, 4, 13)], ["launch", Vector3(54, 0, 5.15)]]:
		var terminal := preload("res://scenes/computers/computer_terminal.tscn").instantiate()
		terminal.terminal_type = entry[0]
		terminal.position = entry[1]
		terminal.name = str(entry[0]).to_pascal_case() + "Terminal"
		add_child(terminal)
	navigation = NavigationRegion3D.new()
	navigation.name = "FacilityNavigation"
	if ResourceLoader.exists("res://data/facility_navigation.tres"):
		navigation.navigation_mesh = load("res://data/facility_navigation.tres")
	add_child(navigation)
	var trail := MeshInstance3D.new()
	trail.set_script(preload("res://scripts/gameplay/objective_trail.gd"))
	trail.name = "ObjectiveTrail"
	trail.player = player
	add_child(trail)
	engineer = ENGINEER_SCENE.instantiate()
	engineer.name = "Engineer"
	engineer.position = Vector3(-31.58, 0.05, 17.8)
	engineer.player = player
	engineer.visible = false
	add_child(engineer)
	var test_spawn := OS.get_cmdline_user_args().has("--bake-nav") or OS.get_cmdline_user_args().has("--test") or OS.has_feature("qa")
	if test_spawn or GameState.sandbox or skip_elevator_intro or resuming:
		var landing_door := SpaceVisuals.model(shell,"architecture/elevator_door",Vector3(-32,0,20.12),PI,2.4,false)
		landing_door.scale.y = 2.60 / (landing_door.get_meta("model_bounds") as AABB).size.y
		SpaceVisuals.box(shell,"ClosedLandingBacking",Vector3(2.45,2.65,0.12),Vector3(-32,1.325,20.34),Color("50575a"),true)
	if not GameState.sandbox and not resuming:_place_starter_cartridge(first_floor)
	for label:Label3D in find_children("*","Label3D",true,false):label.hide()
	SettingsStore.apply_world(self)
	SpaceStaticGeometry.combine(self, [first_floor, second_floor, connector, upper_connector, dressing, shell])
	var visibility := preload("res://scripts/gameplay/bridge_visibility.gd").new()
	add_child(visibility)
	visibility.configure([first_floor,second_floor])
	var static_visibility:=preload("res://scripts/gameplay/facility_visibility.gd").new()
	add_child(static_visibility)
	static_visibility.configure(self)
	if test_spawn and not GameState.sandbox:
		player.global_position = Vector3(-32,0.1,18)
		player.reset_physics_interpolation()
		ready_to_play = true
		presentation_ready.emit()
		return
	var elevator: Node3D
	if resuming:
		player.global_position=SaveStore.vector(SaveStore.pending.player.position)
	elif GameState.sandbox:
		player.global_position = Vector3(7.3,4.1,7.8)
		player.head.rotation.y = 0.48
		GameState.files_available = true
	elif skip_elevator_intro:
		player.global_position = $DebugSpawn.global_position
	else:
		elevator = ELEVATOR_SCENE.instantiate()
		elevator.name = "ElevatorIntro"
		add_child(elevator)
		player.global_position = elevator.player_start.global_position
	player.reset_physics_interpolation()
	if OS.has_feature("web"):
		await preload("res://scripts/gameplay/shader_warmup.gd").prepare(self)
		# Draw the actual arrival view before revealing it or accepting movement.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	ready_to_play = true
	presentation_ready.emit()
	print("Facility ready")
	SaveStore.bind_world(self)
	if resuming:
		SaveStore.apply_world(self)
	elif is_instance_valid(elevator):
		_run_elevator_intro(elevator)
	else:
		player.set_controls_enabled(true)
		if skip_elevator_intro: engineer.begin()
		if GameState.sandbox and not test_spawn:call_deferred("_sandbox_welcome")

func _run_elevator_intro(elevator: Node3D) -> void:
	await elevator.play_intro(player)
	player.set_controls_enabled(true)
	engineer.begin()

func _on_pause_requested() -> void:
	if is_instance_valid(_pause_overlay):
		return
	_pause_overlay = PAUSE_SCENE.instantiate() as CanvasLayer
	get_tree().root.add_child(_pause_overlay)
	_pause_overlay.configure(player)
	_pause_overlay.tree_exited.connect(func() -> void: _pause_overlay = null)

func _place_starter_cartridge(floor_node: Node3D) -> void:
	for room in floor_node.get_children():
		if room.get("room_title")!="MISSION PLANNING":continue
		for holder in room.get_node("PropsAnchor").get_children():
			if holder.get_meta("asset_path","")!="environment/engineering_desk":continue
			var cartridge:=preload("res://scenes/items/data_cartridge.tscn").instantiate()
			cartridge.set_meta("starter_cartridge",true)
			holder.add_child(cartridge)
			cartridge.position=Vector3(0.35,SpaceVisuals.surface_height(holder,"desk_top")+0.012,0.12)
			GameState.starter_location=cartridge.global_position
			if GameState.intro_briefed and not GameState.starter_found:
				GameState.set_objective("Find your data cartridge","CUZ  /  Level 01  /  Mission Planning. Check the desk, then return to the Engineer.",cartridge.global_position)
			return

func _restore_terminal(kind:String) -> void:
	await get_tree().create_timer(.55).timeout
	for terminal in get_tree().get_nodes_in_group("terminals"):
		if terminal.terminal_type==kind:
			gameplay_ui.open_terminal(terminal)
			return

func _sandbox_welcome() -> void:
	await get_tree().create_timer(.7).timeout
	for crew in find_children("*","Area3D",true,false):
		if crew.get_script()==preload("res://scripts/gameplay/station_crew.gd") and crew.role=="scientist":
			crew.interact(player)
			return
