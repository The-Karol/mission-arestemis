extends Node
const Design=preload("res://scripts/gameplay/design_data.gd")
var failed:=false
var world:Node3D
var ui:CanvasLayer

func check(value:bool,message:String) -> void:
	print("PASS " if value else "FAIL ",message)
	failed=failed or not value

func _ready() -> void:
	call_deferred("run")

func capture(name:String) -> void:
	await get_tree().create_timer(0.15).timeout
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/workstation_"+name+".png")

func close() -> void:
	await ui.close_modal()
	await get_tree().process_frame

func run() -> void:
	var saved_guidance:=SettingsStore.guidance
	var saved_seen:=SettingsStore.seen_guides.duplicate()
	SettingsStore.guidance=-1
	SceneManager.menu_intro_seen=true
	var menu:=preload("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	menu._play()
	check(menu.has_node("GuideChoice"),"First mission offers optional guidance")
	await capture("guidance_choice")
	menu.queue_free()
	await get_tree().process_frame
	SettingsStore.guidance=1
	SettingsStore.seen_guides=PackedStringArray()
	world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	ui=world.gameplay_ui
	GameState.new_session(true)
	GameState.sandbox_design=Design.craft("Satellite",["A1.1","A1.1","A1.7"])
	ui._build_terminal_content(world.get_node("SpacecraftTerminal"))
	await get_tree().process_frame
	var editor=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("_delete_selected"))[0]
	editor._pick_installed(1)
	check(editor.installed_index==1,"Select a particular duplicate module")
	editor._delete_selected()
	check(editor.ids==["A1.1","A1.7"],"Delete only the selected copy")
	check(editor.internal_tiles.get_child_count()>0,"Internal modules remain available as visual tiles")
	await capture("systems")
	editor._save()
	check(GameState.sandbox_design.module_ids==editor.ids,"Save edited spacecraft")
	await close()
	GameState.new_session()
	GameState.starter_found=true
	world.get_node("SpacecraftTerminal").reader.cartridge=get_tree().get_nodes_in_group("cartridges")[0]
	GameState.selected_mission=GameState.missions[0].id
	GameState.files_available=true
	ui._build_terminal_content(world.get_node("SpacecraftTerminal"))
	await get_tree().process_frame
	editor=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("_delete_selected"))[0]
	await capture("craft")
	ui._offer_terminal_tour(editor.terminal)
	check(is_instance_valid(ui._tour),"First workstation visit starts its guide")
	await capture("guidance")
	ui._tour.advance()
	check(ui._tour.step==1,"Guide advances to the installation explanation")
	ui._tour.dismiss()
	await get_tree().process_frame
	ui._offer_terminal_tour(editor.terminal)
	check(not is_instance_valid(ui._tour) and "spacecraft" in SettingsStore.seen_guides,"Completed guide does not repeat")
	check(editor.requirements.get_child_count()>=2,"Mission checklist is visible")
	var save=editor.terminal.save_spacecraft(Design.craft(editor.kind,editor.ids))
	await get_tree().create_timer(0.5).timeout
	var cartridge=editor.terminal.reader.cartridge
	await close()
	var launcher=world.get_node("RocketTerminal")
	launcher.reader.cartridge=cartridge
	ui._build_terminal_content(launcher)
	var part:Dictionary=ui._catalog[0].duplicate(true)
	ui._parts=[part.duplicate(true),part.duplicate(true)]
	ui._refresh_parts()
	ui._pick_part(1)
	ui._delete_part()
	check(ui._parts.size()==1 and ui._selected_part==-1,"Rocket selection removes only one duplicate")
	ui._parts=ui._catalog.filter(func(p):return p.id in ["engine_m","tank_m","interstage","avionics","payload","fairing_m"]).duplicate(true)
	ui._refresh_parts()
	check(ui._part_list.get_children().any(func(n):return n is Button and n.icon!=null),"Rocket catalogue includes part illustrations")
	await capture("rocket")
	var zone:Dictionary=ui._preview.targets[0]
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=zone.rect.get_center()
	ui._preview._gui_input(click)
	check(ui._selected_part==zone.index,"Clicking a drawing selects its exact part")
	await close()
	var verify=world.get_node("VerificationTerminal")
	verify.reader.cartridge=cartridge
	cartridge.rocket_design={"parts":[],"payload_type":"Rover"}
	ui._build_terminal_content(verify)
	await get_tree().process_frame
	var console=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("run_report"))[0]
	console.run_report()
	await get_tree().create_timer(1.5).timeout
	var report:String=console.output.get_parsed_text()
	check(report.contains("FAIL"),"Incomplete launcher produces diagnostics failure")
	check(report.contains("ERROR 01") and report.contains("ERROR 05") and report.contains("ASCENT"),"Diagnostics lists all faults and measured performance")
	check(cartridge.verification_status!="DATA_VERIFIED","Faulty vehicle cannot receive launch clearance")
	await get_tree().create_timer(3.6).timeout
	await capture("verification")
	await close()
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.position=Vector3(-24.2,1.65,0)
	camera.look_at(Vector3(-27,1.65,0))
	camera.make_current()
	world.player.global_position=Vector3(-10,0.1,9)
	world.player.reset_physics_interpolation()
	ui.hud.hide()
	await capture("door")
	var doors=world.find_children("*","Node3D",true,false).filter(func(n):return n.has_meta("door_bounds"))
	check(doors.size()>22,"Automatic doors in room passages")
	var leaf:Node3D=doors[0].left
	check(leaf is AnimatableBody3D and leaf.collision_layer==8,"Door leaves have independent collision")
	var door:Node3D=doors[0]
	world.player.global_position=door.to_global(Vector3(0,0.15,1.6))
	world.player.reset_physics_interpolation()
	await get_tree().create_timer(0.7).timeout
	check(door.progress>0.98,"Approaching a door fully opens the leaves")
	world.player.global_position=Vector3(-10,0.1,9)
	world.player.reset_physics_interpolation()
	await get_tree().create_timer(0.7).timeout
	check(door.progress<0.02,"Unoccupied passage closes its leaves")
	SettingsStore.guidance=saved_guidance
	SettingsStore.seen_guides=saved_seen
	SettingsStore.save_settings()
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
