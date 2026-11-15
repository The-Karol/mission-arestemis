extends Node
const Design = preload("res://scripts/gameplay/design_data.gd")
const Vehicle = preload("res://scripts/gameplay/vehicle_performance.gd")
var failed := false

func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	failed=failed or not ok

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var menu:=preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	var flight: Node3D=menu.flight
	var rise_ok:=true
	for tick in range(280,852,4):
		flight.clock=tick/100.0
		flight._process(0.0)
		var point: Vector2=flight.camera.unproject_position(flight.pivot.global_position)
		var extent: Vector2=flight.camera.get_viewport().get_visible_rect().size
		rise_ok=rise_ok and absf(point.y/extent.y-0.5)<0.045
	check(rise_ok,"Rocket stays level in the chase frame")
	menu.queue_free()
	var world:=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	var actor: CharacterBody3D=world.player
	var guide: CharacterBody3D=world.engineer
	actor.set_controls_enabled(true)
	actor._mouse_delta=Vector2(97,24)
	actor._apply_pending_mouse_look(0.016)
	check(actor.turn_filter.visible,"Fast mouse turn activates world blur")
	actor._apply_pending_mouse_look(0.016)
	check(not actor.turn_filter.visible,"Resting view stays sharp")
	for i in 12: await get_tree().physics_frame
	guide.active=true
	guide._introduced=true
	guide._arrival_dialogue=true
	guide._start_guiding()
	var render_only:=OS.get_cmdline_user_args().has("--capture-design")
	for tick in (0 if render_only else 3900):
		actor.global_position=guide.global_position+Vector3(0.65,0.02,0.63)
		actor.velocity=Vector3.ZERO
		await get_tree().physics_frame
		if guide.state=="at_office": break
	if not render_only: check(guide.state=="at_office","Physical escort from arrivals up the MIK stairs to the office, ending at "+str(guide.global_position))
	if not render_only and guide.state!="at_office": print("Guide path ",guide.agent.get_current_navigation_path())
	guide.active=false
	GameState.new_session()
	GameState.selected_mission=GameState.missions[0].id
	var terminal: ComputerTerminal=world.get_node("SpacecraftTerminal")
	var ui: CanvasLayer=world.gameplay_ui
	ui._build_terminal_content(terminal)
	await get_tree().process_frame
	var editor=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n): return n.has_method("_update_design"))[0]
	var before: float=Design.craft(editor.kind,editor.ids).mass_kg
	var instrument_name: String=Design.by_id["F1.1"].name
	editor.category=Design.by_id["F1.1"].category
	editor._refresh()
	for button in editor.parts.get_children():
		if button is Button and button.text==instrument_name: button.pressed.emit()
	editor._save()
	var d: Dictionary=terminal.reader.cartridge.spacecraft_design
	check(is_equal_approx(d.mass_kg,before+6.9),"Installed hardware changes mass on the physical cartridge")
	if DisplayServer.get_name()!="headless":
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/spacecraft_assembly.png")
	var catalog: Array=ui._catalog
	check(catalog.size()==34 and Design.catalog().size()==80,"All 114 specified hardware entries available")
	var all_valid:=true
	for m in GameState.missions:
		var build:=Design.craft(m.spacecraft_type,m.recommended)
		all_valid=all_valid and build.module_ids.size()==m.recommended.size()
	check(all_valid,"All ten mission loadouts use compatible parts")
	var sample: Array=[]
	for p in catalog:
		if p.id in ["engine_m","tank_s","payload","fairing_m"]:sample.append(p)
	var r:=Vehicle.evaluate(sample,d,GameState.mission())
	check(r.mass>r.payload and is_equal_approx(r.thrust,845) and r.dv>0 and r.payload>d.mass_kg,"Rocket budget includes the saved rover and its delivery package")
	get_tree().quit(1 if failed else 0)
