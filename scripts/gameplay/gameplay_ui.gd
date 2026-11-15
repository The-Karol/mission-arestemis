extends CanvasLayer

signal modal_closed

var player: CharacterBody3D
var hud: Control
var objective_label: Label
var objective_hint: Label
var location_label: Label
var mission_folder: Button
var dossier_overlay: Control
var prompt: Label
var toast: Label
var carry_label: Label
var modal: Control
var toast_tween: Tween
var _tour_steps: Array = []
var _tour: Control
var _terminal: ComputerTerminal
var _parts: Array = []
var _catalog: Array = []
const PAPER := Color("e3d8be")
const INK := Color("27382e")
var category_buttons := {}
var _stage_buttons:Dictionary={}
const Design = preload("res://scripts/gameplay/design_data.gd")
const Vehicle = preload("res://scripts/gameplay/vehicle_performance.gd")
var _edit_stage := 0
var _category := "ENGINES"
var _part_list: VBoxContainer
var _remove_part: Button
var _selected_part := -1
var _preview: Control
var _stats: HBoxContainer
var _result: Label
var _distance_time := 0.0
var inspection_camera: Camera3D
var _transitioning := false
var _return_pose := Transform3D.IDENTITY
var _return_fov := 75.0
var _conversation_tween: Tween

func _ready() -> void:
	layer = 8
	_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	hud = Control.new()
	add_child(hud)
	SpaceUI.fill(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective_panel := SpaceUI.panel(hud, 16)
	objective_panel.position = Vector2(24, 24)
	objective_panel.custom_minimum_size = Vector2(410, 100)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var objective_column := SpaceUI.column(objective_panel, 5)
	SpaceUI.label(objective_column, "HYPERION   /   CURRENT OBJECTIVE", 12, SpaceUI.ACCENT)
	objective_label = SpaceUI.label(objective_column, "", 19, SpaceUI.INK, true)
	objective_label.custom_minimum_size.x = 405
	objective_hint = SpaceUI.label(objective_column, "", 13, SpaceUI.MUTED, true)
	objective_hint.custom_minimum_size.x = 405
	location_label = Label.new()
	location_label.hide()
	hud.add_child(location_label)
	mission_folder=SpaceUI.briefing_button(hud,"MISSION DOSSIER  [J]",open_dossier)
	mission_folder.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mission_folder.offset_left=-265
	mission_folder.offset_right=-24
	mission_folder.offset_top=24
	mission_folder.offset_bottom=82
	mission_folder.icon=preload("res://assets/ui/mission_folder.svg")
	mission_folder.expand_icon=true
	mission_folder.add_theme_constant_override("icon_max_width",34)
	mission_folder.tooltip_text="Press J to read your selected mission again."

	prompt = SpaceUI.label(hud, "", 19, SpaceUI.INK)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_top = 36
	prompt.offset_bottom = 70
	prompt.offset_left = -360
	prompt.offset_right = 360
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	carry_label = SpaceUI.label(hud, "WASD  MOVE     SHIFT  RUN     SPACE  JUMP     E  INTERACT     ESC  PAUSE", 12, SpaceUI.MUTED)
	carry_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	carry_label.offset_left = 24
	carry_label.offset_top = -36
	carry_label.offset_bottom = -14
	toast = SpaceUI.label(hud, "", 17, SpaceUI.ACCENT)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -520
	toast.offset_right = 520
	toast.offset_top = -100
	toast.offset_bottom = -52
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameState.objective_changed.connect(_update_objective)
	_update_objective()

func configure(actor: CharacterBody3D) -> void:
	player = actor
	player.ui = self
	player.message_requested.connect(show_message)

func _update_objective() -> void:
	if is_instance_valid(mission_folder):
		mission_folder.visible=not GameState.selected_mission.is_empty()
		mission_folder.text=str(GameState.mission().get("short_title","MISSION DOSSIER"))+"  [J]"
	objective_label.text = GameState.objective
	objective_hint.text = GameState.objective_hint

func set_prompt(text: String) -> void:
	prompt.text = text if not is_open() else ""

func show_message(text: String) -> void:
	if is_instance_valid(toast_tween):
		toast_tween.kill()
	toast.text = text
	toast.modulate.a = 1
	toast_tween = create_tween()
	toast_tween.tween_interval(4)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)

func is_open() -> bool:
	return is_instance_valid(modal)

func close_modal() -> void:
	if _transitioning: return
	if is_instance_valid(_terminal) and is_instance_valid(modal):
		GameState.editor_drafts.merge(SaveStore.capture(get_parent()).draft,true)
	if is_instance_valid(_tour): _tour.queue_free()
	player.request_walk_capture()
	if _terminal: GameAudio.ambience("facility")
	_transitioning = true
	if is_instance_valid(_conversation_tween): _conversation_tween.kill()
	if is_instance_valid(inspection_camera):
		if is_instance_valid(_terminal) and is_instance_valid(modal):
			_terminal.show_interface(modal)
		elif is_instance_valid(modal):
			modal.hide()
		await move_inspection(_return_pose,_return_fov,0.85)
		player.camera.make_current()
		inspection_camera.queue_free()
		inspection_camera = null
		player.astronaut.show()
	if is_instance_valid(_terminal): _terminal.end_interface()
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null
	_terminal = null
	hud.visible = true
	_transitioning = false
	player.set_controls_enabled(true)
	modal_closed.emit()

func _start_inspection() -> void:
	player.enter_mode("inspection")
	hud.hide()
	_return_pose = player.camera.global_transform
	_return_fov = player.camera.fov
	inspection_camera = Camera3D.new()
	get_parent().add_child(inspection_camera)
	inspection_camera.global_transform = _return_pose
	inspection_camera.fov = _return_fov
	inspection_camera.near = 0.025
	inspection_camera.cull_mask = player.camera.cull_mask
	inspection_camera.make_current()
	player.astronaut.hide()

func move_inspection(target: Transform3D, target_fov: float, duration: float) -> void:
	var start := inspection_camera.global_transform
	var fov := inspection_camera.fov
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(weight: float):
		inspection_camera.global_transform = start.interpolate_with(target,weight)
		inspection_camera.fov = lerpf(fov,target_fov,weight),0.0,1.0,duration)
	await tween.finished

func open_mission_table(table: Node3D) -> void:
	if is_open() or _transitioning: return
	_start_inspection()
	modal = Control.new()
	modal.set_script(preload("res://scripts/gameplay/mission_desk_ui.gd"))
	modal.table = table
	modal.ui = self
	add_child(modal)
	_transitioning = true
	await move_inspection(table.camera_pose(),44.0,1.15)
	_transitioning = false

func _shell(title_text: String, subtitle: String = "") -> VBoxContainer:
	if is_open():
		close_modal()
	player.enter_mode("terminal")
	hud.visible = false
	modal = Control.new()
	add_child(modal)
	SpaceUI.fill(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.015, 0.02, 0.91)
	modal.add_child(shade)
	SpaceUI.fill(shade)
	var panel := SpaceUI.panel(modal, 16)
	SpaceUI.fill(panel)
	panel.anchor_left = 0.035
	panel.anchor_right = 0.965
	panel.anchor_top = 0.045
	panel.anchor_bottom = 0.95
	var column := SpaceUI.column(panel, 8)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := SpaceUI.label(header, title_text, 21, SpaceUI.GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not GameState.selected_mission.is_empty():SpaceUI.button(header,"MISSION [J]",open_dossier,36)
	SpaceUI.button(header, "EXIT TERMINAL  /  ESC", close_modal, 36)
	if not subtitle.is_empty():
		SpaceUI.label(column, subtitle, 14, SpaceUI.MUTED, true)
	column.add_child(HSeparator.new())
	return column

func show_dialogue(name_text: String, lines: Array, callback: Callable = Callable(), speaker: Node3D = null) -> void:
	if is_open():
		await close_modal()
	var guide := speaker if speaker else get_tree().get_first_node_in_group("guide") as Node3D
	if is_instance_valid(guide) and guide.visible and player.global_position.distance_to(guide.global_position)<5.5:
		_start_inspection()
		var origin := inspection_camera.global_position
		var subject := guide.global_position+Vector3.UP*0.86
		var distance := origin.distance_to(subject)
		var right := (subject-origin).cross(Vector3.UP).normalized()
		var pose := inspection_camera.global_transform.looking_at(subject-right*0.22)
		var fov := clampf(rad_to_deg(2.0*atan(1.26/maxf(distance,0.1))),36.0,80.0)
		_conversation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_conversation_tween.tween_property(inspection_camera,"global_transform",pose,0.5)
		_conversation_tween.tween_property(inspection_camera,"fov",fov,0.5)
	player.enter_mode("dialogue")
	hud.visible = false
	modal = preload("res://scenes/dialogue/dialogue_ui.tscn").instantiate() as Control
	modal.configure(name_text, lines)
	add_child(modal)
	modal.finished.connect(func() -> void:
		await close_modal()
		if callback.is_valid():
			callback.call(), CONNECT_ONE_SHOT)

func open_mission(mission: Dictionary) -> void:
	var column := _shell("HYPERION / MISSION ARCHIVE", "PROJECT OFFICE   /   LEVEL 02   /   SELECT ONE OF THREE PROPOSALS")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := SpaceUI.column(scroll, 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceUI.label(content, str(mission.title), 32, SpaceUI.INK, true)
	SpaceUI.label(content, "%s     /     %s     /     %s" % [mission.target_body, mission.spacecraft_type, str(mission.difficulty).to_upper()], 17, SpaceUI.ACCENT, true)
	SpaceUI.label(content, str(mission.description), 20, SpaceUI.INK, true)
	SpaceUI.label(content, "PRIMARY OBJECTIVE", 13, SpaceUI.GREEN)
	SpaceUI.label(content, str(mission.primary_objective), 19, SpaceUI.INK, true)
	SpaceUI.label(content, "SECONDARY OBJECTIVES\n- " + "\n- ".join(mission.secondary_objectives), 17, SpaceUI.INK, true)
	SpaceUI.label(content, "TRAJECTORY / " + str(mission.recommended_orbit), 16, SpaceUI.GREEN, true)
	SpaceUI.label(content, "DESIGN CONSIDERATIONS\n" + str(mission.constraints), 17, SpaceUI.MUTED, true)
	var choice := SpaceUI.button(column, "SELECT MISSION  >", func() -> void: _confirm_mission(mission))
	if not GameState.selected_mission.is_empty():
		choice.disabled = true
		choice.text = "ACTIVE MISSION" if GameState.selected_mission == mission.id else "MISSION ALREADY SELECTED"
	SpaceUI.button(column, "BACK TO THE THREE FILES", close_modal)

func _confirm_mission(mission: Dictionary) -> void:
	var column := _shell("CONFIRM ASSIGNMENT")
	SpaceUI.label(column, "Lead %s?" % mission.title, 30, SpaceUI.INK, true)
	SpaceUI.label(column, "This assigns one mission for this visit to Hyperion. The other proposals will remain available to read.", 20, SpaceUI.MUTED, true)
	SpaceUI.button(column, "CONFIRM MISSION", func() -> void:
		close_modal()
		GameState.select_mission(mission.id))
	SpaceUI.button(column, "CANCEL / READ BRIEF AGAIN", func() -> void: open_mission(mission))

func open_map() -> void:
	pass

func open_terminal(terminal: ComputerTerminal) -> void:
	if is_open() or _transitioning: return
	_build_terminal_content(terminal)
	_start_inspection()
	_transitioning = true
	GameAudio.play_effect("boot")
	GameAudio.ambience("terminal")
	terminal.boot()
	modal.hide()
	# Watch the CRT power on before the interface resolves onto its glass.
	await get_tree().create_timer(0.35).timeout
	terminal.show_interface(modal)
	modal.show()
	await move_inspection(terminal.camera_pose(),35.0,1.25)
	modal.reparent(self)
	SpaceUI.fill(modal)
	_transitioning = false
	_offer_terminal_tour(terminal)

func _offer_terminal_tour(terminal: ComputerTerminal) -> void:
	if GameState.sandbox or SettingsStore.guidance!=1 or terminal.terminal_type in SettingsStore.seen_guides or _tour_steps.is_empty():return
	var tour:=preload("res://scripts/gameplay/terminal_tour.gd").new()
	_tour=tour
	tour.start(modal,_tour_steps)
	tour.finished.connect(func():
		SettingsStore.seen_guides.append(terminal.terminal_type)
		SettingsStore.save_settings(),CONNECT_ONE_SHOT)

func _build_terminal_content(terminal: ComputerTerminal) -> void:
	_tour_steps.clear()
	var column := _shell(terminal.title)
	_terminal = terminal
	if terminal.terminal_type=="verification":
		_open_verification(column,terminal)
		return
	if GameState.sandbox:
		_build_sandbox_ui(column)
		return
	var error := terminal.access_error()
	if not error.is_empty():
		GameAudio.play_effect("error",-17)
		SpaceUI.label(column, "ACCESS / ACTION REQUIRED", 14, SpaceUI.ACCENT)
		SpaceUI.label(column, error, 26, SpaceUI.INK, true)
		SpaceUI.label(column, "Close this screen to interact with the cartridge reader beside the computer.", 18, SpaceUI.MUTED, true)
		return
	var mission := GameState.mission()
	if terminal.terminal_type == "rocket":
		_build_rocket_ui(column)
		return
	if terminal.terminal_type=="spacecraft":
		_open_craft(column)
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var content := SpaceUI.column(scroll, 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Design.mission_plate(content,mission,108,SpaceUI.GREEN)
	match terminal.terminal_type:
		"launch":
			SpaceUI.label(content, "04 / MISSION CONTROL", 28)
			var flight_data: Dictionary=terminal.reader.cartridge.rocket_design.get("performance",{})
			if flight_data.has("payload"):
				SpaceUI.label(content,"Launch payload %.2f t    /    Lift-off %.2f t    /    %.0f kN" % [flight_data.payload/1000,flight_data.mass/1000,flight_data.thrust],21,SpaceUI.GREEN,true)
				SpaceUI.label(content,"Velocity budget   %.2f / %.2f km/s" % [flight_data.dv/1000,flight_data.target/1000],17,SpaceUI.INK,true)
			SpaceUI.label(content,"Design cartridge received and verified.",17,SpaceUI.GREEN)
			SpaceUI.label(content, "Launch the verified vehicle. Follow the ascent, deployment and mission operations.", 19, SpaceUI.INK, true)
			SpaceUI.button(column, "BEGIN LAUNCH SEQUENCE", _begin_launch)
			_tour_steps=[["Mission control","Launch starts the final countdown and mission cinematic. The debrief grades your verified spacecraft and launcher.",content]]

var _flight:Control
func _begin_launch() -> void:
	if is_instance_valid(_flight):return
	var error:=_terminal.access_error()
	if not error.is_empty():
		show_message(error)
		return
	if is_instance_valid(_tour):_tour.queue_free()
	var cart:DataCartridge=_terminal.reader.cartridge
	_flight=preload("res://scripts/gameplay/launch_sequence.gd").new()
	_flight.mission=GameState.mission().duplicate(true)
	_flight.craft=cart.spacecraft_design.duplicate(true)
	_flight.parts=cart.rocket_design.get("parts",[]).duplicate(true)
	_flight.performance=preload("res://scripts/gameplay/vehicle_performance.gd").evaluate(_flight.parts,_flight.craft,_flight.mission)
	modal.hide()
	player.enter_mode("launch")
	add_child(_flight)
	_flight.finished.connect(func():
		_flight.queue_free()
		_flight=null
		await close_modal()
		SaveStore.save_now())

func _open_verification(column: VBoxContainer, terminal: ComputerTerminal) -> void:
	var review:=VBoxContainer.new()
	review.size_flags_vertical=Control.SIZE_EXPAND_FILL
	column.add_child(review)
	SpaceUI.label(review,"REVIEW THE SAVED DESIGNS",18,SpaceUI.GREEN)
	SpaceUI.label(review,"Confirm the payload and launcher before running diagnostics.",14,SpaceUI.MUTED,true)
	var drawings:=HBoxContainer.new()
	drawings.size_flags_vertical=Control.SIZE_EXPAND_FILL
	review.add_child(drawings)
	var review_craft:=Design.payload_design(terminal)
	var saved_parts:Array=GameState.sandbox_parts if GameState.sandbox else (terminal.reader.cartridge.rocket_design.get("parts",[]) if terminal.reader.has_cartridge() else [])
	for kind in ["SPACECRAFT","LAUNCH VEHICLE"]:
		var pane:=SpaceUI.panel(drawings,10)
		pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var contents:=SpaceUI.column(pane,5)
		SpaceUI.label(contents,kind,14,SpaceUI.ACCENT)
		if kind=="SPACECRAFT":
			SpaceUI.label(contents,"%s / %.0f kg / %d modules"%[review_craft.type,review_craft.mass_kg,review_craft.module_ids.size()],13,SpaceUI.INK,true)
			var drawing:=preload("res://scripts/gameplay/craft_view.gd").new()
			drawing.size_flags_vertical=Control.SIZE_EXPAND_FILL
			drawing.custom_minimum_size=Vector2(250,260)
			contents.add_child(drawing)
			drawing.rebuild(review_craft.type,review_craft.module_ids)
		else:
			SpaceUI.label(contents,"%d saved parts / the current spacecraft is the payload"%saved_parts.size(),13,SpaceUI.INK,true)
			var drawing:=preload("res://scripts/gameplay/rocket_blueprint.gd").new()
			drawing.parts=saved_parts
			drawing.read_only=true
			drawing.size_flags_vertical=Control.SIZE_EXPAND_FILL
			drawing.custom_minimum_size=Vector2(250,260)
			contents.add_child(drawing)
	var proceed:=SpaceUI.button(review,"CONTINUE TO DIAGNOSTICS",func():pass,40)
	var console:=preload("res://scripts/gameplay/check_console.gd").new()
	column.add_child(console)
	var slot: String="sandbox designs" if GameState.sandbox else ("no cartridge" if not terminal.reader.has_cartridge() else terminal.reader.cartridge.cartridge_id)
	console.hide()
	proceed.pressed.connect(func():review.hide();console.show())
	console.open(func() -> String:
		if GameState.sandbox:
			var craft:=Design.payload_design(terminal)
			var perf:=Vehicle.evaluate(GameState.sandbox_parts,craft,{})
			var faults: Array=perf.errors.duplicate()
			for issue in Design.missing_systems(craft,{}):faults.append(preload("res://scripts/gameplay/design_help.gd").repair(str(issue),craft,{}))
			var report := "WORKSHOP   /   engineering review\nVEHICLE   %.2f t | %.0f kN | TWR %.2f\nASCENT    dV %.2f / %.2f km/s\nPOWER     %.0f W supply / %.0f W load\n" % [perf.mass/1000.0,perf.thrust,perf.twr,perf.dv/1000.0,perf.target/1000.0,craft.generation_w,craft.load_w]
			if faults.is_empty(): return report+"PASS  /  Workshop design meets the targets."
			report+="FAIL  /  %d systems need revision:\n" % faults.size()
			for i in faults.size(): report+="ERROR %02d  /  %s\n" % [i+1,faults[i]]
			return report+"NEXT  /  Revise the spacecraft or launcher and run diagnostics again."
		return terminal.run_verification(),slot)
	SpaceUI.button(console,"Review designs again",func():console.hide();review.show(),34)
	_tour_steps=[["Review and verify","Inspect both saved designs, then continue to diagnostics. Red lines explain exactly which equipment to replace and where.",proceed]]

func _open_craft(column: VBoxContainer) -> void:
	var workshop:=preload("res://scripts/gameplay/craft_workshop.gd").new()
	column.add_child(workshop)
	workshop.open(_terminal)
	_tour_steps=[["Read the mission card","The large card lists the goal and the target orbit. The right panel tracks instruments and power; hover each line for details.",workshop.requirements],
		["Fit your spacecraft","Choose a system in the left column, then click a part name to install it. Hover any name for its purpose and ratings.",workshop.parts],
		["Pick, remove, save","Click a module in the drawing to select it. Press Delete or use Remove to delete it, then save the spacecraft to the cartridge.",workshop.remove_button]]

func _build_rocket_ui(column: VBoxContainer) -> void:
	_parts = GameState.editor_drafts.get("rocket",GameState.sandbox_parts if GameState.sandbox else _terminal.reader.cartridge.rocket_design.get("parts", [])).duplicate(true)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var index_panel := SpaceUI.panel(body,10)
	index_panel.add_theme_stylebox_override("panel",SpaceUI.style(PAPER.darkened(0.05),9,Color("9d967f")))
	var categories := SpaceUI.column(index_panel,5)
	category_buttons.clear()
	categories.custom_minimum_size.x = 126
	SpaceUI.label(categories,"EDIT STAGE",12,INK)
	_stage_buttons.clear()
	for index in 2:
		var button:=SpaceUI.button(categories,"1  LIFT-OFF" if index==0 else "2  ORBIT",_choose_stage.bind(index),35)
		button.tooltip_text="Stage 1 lifts the complete vehicle from the pad. Fit its own sea-level engine and matching tanks." if index==0 else "Optional upper stage. Fit its own engine and tanks. The interstage houses its nozzle; a separation ring releases Stage 1."
		_stage_buttons[index]=button

	for category in ["ENGINES", "FUEL TANKS", "BOOSTERS", "INTERSTAGES", "SEPARATION", "FAIRINGS", "AVIONICS", "PAYLOAD"]:
		var button := SpaceUI.button(categories, category, func() -> void:
			_category = category
			_refresh_catalog(), 35)
		category_buttons[category] = button
		button.tooltip_text=preload("res://scripts/gameplay/design_help.gd").category(category)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var scroll := ScrollContainer.new()
	var sheets := SpaceUI.panel(body,8)
	sheets.add_theme_stylebox_override("panel",SpaceUI.style(PAPER,10,Color("9d967f")))
	scroll.custom_minimum_size.x = 196
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheets.add_child(scroll)
	_part_list = SpaceUI.column(scroll, 8)
	_part_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := SpaceUI.column(body, 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceUI.label(right, "ASSEMBLY DRAWING", 14, SpaceUI.GREEN)
	_preview = Control.new()
	_preview.set_script(preload("res://scripts/gameplay/rocket_blueprint.gd"))
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(240, 150)
	right.add_child(_preview)
	_preview.picked.connect(_pick_part)
	_selected_part = -1
	_choose_stage(_edit_stage)
	var payload := Design.payload_design(_terminal)
	# PAYLOAD CARD - visible spacecraft illustration, key specs and target orbit.
	var brief_panel := SpaceUI.panel(body,10)
	brief_panel.add_theme_stylebox_override("panel",SpaceUI.style(PAPER.darkened(0.04),10,Color("9d967f")))
	brief_panel.custom_minimum_size.x = 200
	var brief := SpaceUI.column(brief_panel,6)
	SpaceUI.label(brief,"PAYLOAD",13,Color("875329"))
	Design.illustration(brief,Design.BUSES[payload.type][2],120,INK)
	var payload_name := SpaceUI.label(brief,payload.type,21,INK,true)
	payload_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var m := GameState.mission()
	SpaceUI.label(brief,"%.0f kg    /    diameter %.2f m" % [payload.mass_kg,payload.diameter_m],15,INK,true)
	SpaceUI.label(brief,"%.0f W load    /    %.1f kWh" % [payload.load_w,payload.battery_kwh],13,Color("596b5a"),true)
	brief.add_child(HSeparator.new())
	SpaceUI.label(brief,"TARGET ORBIT",13,Color("875329"))
	var orbit := SpaceUI.label(brief,str(m.get("recommended_orbit","400 km  /  low Earth orbit")),19,INK,true)
	orbit.tooltip_text=preload("res://scripts/gameplay/design_help.gd").METRICS.Orbit+"\n"+str(m.get("recommended_orbit","400 km low Earth orbit"))
	orbit.mouse_filter=Control.MOUSE_FILTER_PASS
	orbit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orbit.custom_minimum_size.x = 180
	if m.get("delivery_kg",0)>0:
		SpaceUI.label(brief,"Delivery system  +%.0f kg" % m.delivery_kg,14,Color("596b5a"),true)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation",16)
	column.add_child(_stats)
	_result = SpaceUI.label(column, "Select a component to add it to the vehicle.", 14, SpaceUI.MUTED, true)
	var row := HBoxContainer.new()
	column.add_child(row)
	_remove_part = SpaceUI.button(row,"Remove selected",_delete_part)
	SpaceUI.button(row,"Clear all",_clear_rocket)
	var gap:=Control.new()
	gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	SpaceUI.button(row, "SAVE CONCEPT" if GameState.sandbox else "SAVE TO CARTRIDGE", func() -> void:
		if GameState.sandbox:
			GameAudio.play_effect("saved")
			GameState.sandbox_parts = _parts.duplicate(true)
			_result.text = "Workshop concept saved for this session."
		else: _result.text = _terminal.save_rocket(_parts,_parts.is_empty()))
	_refresh_catalog()
	_refresh_parts()
	_tour_steps=[["Plan the ascent","The payload card gives the spacecraft mass, diameter and target orbit. Size the adapter and fairing for this craft.",brief_panel],
		["Build each stage","Choose the core or upper stage, then click a part name to fit it. Match liquid-engine and tank fuels.",categories],
		["Read the drawing","Click an installed part to highlight it and remove it. Check thrust and required velocity below, then save the vehicle.",_preview]]

func _build_sandbox_ui(column: VBoxContainer) -> void:
	if _terminal.terminal_type not in ["rocket","spacecraft"]: SpaceUI.label(column,"SANDBOX / FREE DESIGN WORKSHOP",18,SpaceUI.ACCENT)
	if _terminal.terminal_type == "rocket":
		_build_rocket_ui(column)
	elif _terminal.terminal_type == "spacecraft":
		_open_craft(column)
	else:
		SpaceUI.label(column,"WORKSHOP DESIGN RECORD",28)
		SpaceUI.label(column,"Spacecraft: %s\nRocket components: %d" % [GameState.sandbox_spacecraft,GameState.sandbox_parts.size()],23,SpaceUI.GREEN)
		SpaceUI.label(column,"Free design exploration. Flight simulation is not available yet.",20,SpaceUI.MUTED,true)

func _refresh_catalog() -> void:
	SpaceUI.clear(_part_list)
	for key in category_buttons:
		var b: Button = category_buttons[key]
		var selected: bool = key == _category
		b.add_theme_stylebox_override("normal",SpaceUI.style(Color("354d40") if selected else PAPER,7,Color("a69c82")))
		b.add_theme_color_override("font_color",PAPER if selected else INK)
	SpaceUI.label(_part_list, _category.capitalize(), 21, INK)
	for part in _catalog:
		if part.category != _category:
			continue
		var button := SpaceUI.button(_part_list,part.name,func():
			var choice: Dictionary = part.duplicate(true)
			choice.stage = 0 if part.category in ["BOOSTERS","INTERSTAGES","SEPARATION"] else _edit_stage
			var fitting_error:=preload("res://scripts/gameplay/rocket_assembly_rules.gd").addition_error(_parts,choice)
			if not fitting_error.is_empty():
				_result.text=fitting_error
				GameAudio.play_effect("error",-19)
				return
			_parts.append(choice)
			_selected_part = _parts.size()-1
			_refresh_parts(),33)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",14)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = Design.part_help(part)
		button.icon = Design.texture(part.get("plate",part.id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",42)
		button.add_theme_constant_override("h_separation",9)
		button.custom_minimum_size.y = 54

func _pick_part(index: int) -> void:
	_selected_part = index
	_preview.selected = index
	_preview.queue_redraw()
	_remove_part.disabled = index < 0
	_remove_part.text = "Remove selected" if index < 0 else "Remove   /   " + str(_parts[index].name)

func _delete_part() -> void:
	if _selected_part < 0 or _selected_part >= _parts.size(): return
	_parts.remove_at(_selected_part)
	GameAudio.play_effect("separation",-21)
	_selected_part = -1
	_refresh_parts()

func _refresh_parts() -> void:
	_pick_part(_selected_part)
	_preview.targets.clear()
	_preview.parts = _parts
	_preview.queue_redraw()
	var m := GameState.mission()
	var payload := Design.payload_design(_terminal)
	var r := Vehicle.evaluate(_parts,payload,m)
	SpaceUI.clear(_stats)
	var figures:Dictionary={"Mass":"%.2f t"%[r.mass/1000],"Thrust":"%.0f kN"%r.thrust,"TWR":"%.2f"%r.twr,"dV":"%.2f / %.2f km/s"%[r.dv/1000,r.target/1000],"Payload":"%.2f / %.2f t"%[r.payload/1000,r.capacity/1000]}
	for key in figures:
		var label:=SpaceUI.label(_stats,key+" "+figures[key],14,SpaceUI.INK)
		label.mouse_filter=Control.MOUSE_FILTER_PASS
		label.tooltip_text=preload("res://scripts/gameplay/design_help.gd").METRICS[key]
	_result.text = "Ready for target orbit" if r.errors.is_empty() else str(r.errors[0])
	_result.tooltip_text = "\n".join(r.errors)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_distance_time += delta
	if _distance_time > 0.2:
		_distance_time = 0
		if player.controls_enabled:
			var in_bay := Rect2(-22,-16,22,32).has_point(Vector2(player.global_position.x,player.global_position.z))
			GameAudio.ambience("machinery" if in_bay else "facility")

		if is_instance_valid(player.carried_item):
			carry_label.text = "CARRYING  %s  /  %s      /      Q  PLACE     E  INSERT / INTERACT" % [player.carried_item.cartridge_id, DataCartridge.DataType.keys()[player.carried_item.data_type]]
		else:
			carry_label.text = "WASD  MOVE     SHIFT  RUN     E  INTERACT     ARROWS  LOOK     ESC  PAUSE"

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_flight):return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_J:
		if not GameState.selected_mission.is_empty() and player.mode!="dialogue":
			get_viewport().set_input_as_handled()
			if is_open() and modal.get_meta("mission_dossier",false):close_modal()
			else:open_dossier()
		return
	if is_instance_valid(_tour): return
	if is_open() and is_instance_valid(_terminal) and _terminal.terminal_type=="rocket" and _selected_part>=0 and event is InputEventKey and event.keycode==KEY_DELETE and event.pressed and not event.echo:
		_delete_part()
		get_viewport().set_input_as_handled()
		return
	if is_open() and player.mode != "dialogue" and event.is_action_pressed("ui_cancel"):
		if modal.has_method("_back"): modal._back()
		else: close_modal()
		get_viewport().set_input_as_handled()

func open_dossier() -> void:
	if GameState.selected_mission.is_empty():return
	if is_open():
		if is_instance_valid(dossier_overlay) or player.mode=="dialogue":return
		dossier_overlay=preload("res://scripts/gameplay/mission_dossier.gd").new()
		dossier_overlay.mission=GameState.mission()
		dossier_overlay.exit_requested.connect(func():dossier_overlay.queue_free())
		modal.add_child(dossier_overlay)
		return
	player.enter_mode("mission")
	hud.hide()
	modal=preload("res://scripts/gameplay/mission_dossier.gd").new()
	modal.set_meta("mission_dossier",true)
	modal.mission=GameState.mission()
	modal.exit_requested.connect(close_modal)
	add_child(modal)

func _clear_rocket() -> void:
	_parts.clear()
	_selected_part=-1
	_refresh_parts()
	_result.text="All launcher parts removed. Save to update the cartridge."

func _choose_stage(index:int) -> void:
	_edit_stage=index
	for key in _stage_buttons:
		var button:Button=_stage_buttons[key]
		button.add_theme_stylebox_override("normal",SpaceUI.style(Color("354d40") if key==index else PAPER,7,Color("a69c82")))
		button.add_theme_color_override("font_color",PAPER if key==index else INK)
	if is_instance_valid(_preview):
		_preview.edit_stage=index
		_preview.queue_redraw()
