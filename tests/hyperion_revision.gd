extends Node
const Design=preload("res://scripts/gameplay/design_data.gd")
var failed:=false
func check(value:bool,text:String) -> void:
	print("PASS " if value else "FAIL ",text)
	failed=failed or not value
func shot(name:String) -> void:
	await get_tree().create_timer(.18).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/hyperion_"+name+".png")
func _ready() -> void:call_deferred("run")
func run() -> void:
	GameState.new_session()
	GameState.starter_found=true
	GameState.intro_briefed=true
	GameState.files_available=true
	GameState.selected_mission=GameState.missions[0].id
	var world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	var ui=world.gameplay_ui
	var cart=get_tree().get_nodes_in_group("cartridges")[0]
	var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	var parts:Array=[]
	for id in ["engine_l","hydro_m","be3u","hydro_s","interstage_heavy","sep_heavy","avionics","payload","fairing_m"]:
		var part:Dictionary=catalog.filter(func(p):return p.id==id)[0].duplicate(true)
		part.stage=1 if id in ["be3u","hydro_s"] else 0
		parts.append(part)
	cart.write_spacecraft(GameState.selected_mission,Design.craft("Rover",[]))
	cart.write_rocket({"parts":parts,"payload_type":"Rover"})
	cart.verification_status="DATA_VERIFIED"
	cart.write_spacecraft(GameState.selected_mission,Design.craft("Rover",["A1.5"]))
	check(cart.rocket_design.parts.size()==parts.size(),"Editing spacecraft preserves the built launcher")
	check(cart.verification_status=="NOT_CHECKED","Editing spacecraft revokes launch clearance")
	var craft_terminal=world.get_node("SpacecraftTerminal")
	craft_terminal.reader.cartridge=cart
	ui._build_terminal_content(craft_terminal)
	await get_tree().process_frame
	var workshop=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("_clear_all"))[0]
	workshop._clear_all()
	check(workshop.ids.is_empty(),"Clear all removes spacecraft modules")
	var save_buttons=workshop.find_children("*","Button",true,false).filter(func(n):return n.text.begins_with("SAVE"))
	check(save_buttons[0].global_position.x>workshop.remove_button.global_position.x,"Spacecraft Save is right of the delete controls")
	await ui.close_modal()
	GameState.editor_drafts.clear()
	var launcher=world.get_node("RocketTerminal")
	launcher.reader.cartridge=cart
	ui._build_terminal_content(launcher)
	ui._choose_stage(1)
	await shot("rocket")
	check(ui._stage_buttons.size()==2 and ui._preview.edit_stage==1,"Stage selection uses explicit lift-off and orbit buttons")
	var upper_index:int=parts.find(parts.filter(func(p):return p.id=="be3u")[0])
	var target=ui._preview.targets.filter(func(p):return p.index==upper_index)[0]
	check(ui._preview.get_meta("interstage_housing").encloses(target.rect),"Upper engine is housed inside the interstage")
	var save_rocket=ui.modal.find_children("*","Button",true,false).filter(func(n):return n.text.begins_with("SAVE"))[0]
	check(save_rocket.global_position.x>ui._remove_part.global_position.x,"Rocket Save is at the right")
	ui._clear_rocket()
	check(ui._parts.is_empty(),"Clear all removes launcher parts")
	check(launcher.save_rocket([],true).contains("SAVED") and cart.rocket_design.parts.is_empty(),"Empty launcher can be saved after a full clear")
	cart.write_rocket({"parts":parts,"payload_type":"Rover"})
	await ui.close_modal()
	GameState.editor_drafts.clear()
	var verifier=world.get_node("VerificationTerminal")
	verifier.reader.cartridge=cart
	ui._build_terminal_content(verifier)
	var console=ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("run_report"))[0]
	check(not console.visible,"Verification first shows design review, not terminal")
	await shot("review")
	var proceed=ui.modal.find_children("*","Button",true,false).filter(func(n):return n.text=="CONTINUE TO DIAGNOSTICS")[0]
	proceed.pressed.emit()
	check(console.visible,"Diagnostics appears after reviewing both drawings")
	console.run_report()
	await get_tree().create_timer(5.2).timeout
	var report:String=console.output.get_parsed_text()
	check(report.contains("PIXL") and not report.contains("Spacecraft: elemental"),"Faults name the missing instrument and tell the player how to fix it")
	await shot("diagnostics")
	await ui.close_modal()
	var original:int=SettingsStore.graphics
	SettingsStore.graphics=0
	SettingsStore.apply_view(get_viewport())
	SettingsStore.apply_world(world)
	var low_shadows:=0
	for light in world.find_children("*","Light3D",true,false):
		if light.shadow_enabled:low_shadows+=1
	check(is_equal_approx(get_viewport().scaling_3d_scale,.55) and low_shadows==0,"Low renders at 55 percent and disables real-time shadows")
	check(world.find_children("*","Node3D",true,false).filter(func(n):return n.has_meta("decorative_fx") and n.visible).is_empty(),"Low disables decorative particle clouds")
	SettingsStore.graphics=1
	SettingsStore.apply_view(get_viewport())
	SettingsStore.apply_world(world)
	check(is_equal_approx(get_viewport().scaling_3d_scale,.9),"Balanced retains 90 percent 3D resolution")
	var visible_labels=world.find_children("*","Label3D",true,false).filter(func(n):return n.is_visible_in_tree())
	check(visible_labels.is_empty(),"No floating room or object text remains")
	check(world.find_children("LABEL_*","MeshInstance3D",true,false).is_empty(),"Embedded model-name lettering is removed too")
	var stable=world.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.has_meta("stable_glass"))
	check(stable.size()==1 and stable[0].mesh is QuadMesh,"Test chamber uses a single stable glass surface")
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.global_position=stable[0].global_position+Vector3(1.4,.25,2.4)
	camera.look_at(stable[0].global_position)
	camera.make_current()
	ui.hud.hide()
	await shot("chamber")
	var stair=world.get_node("Floor01/MIK_Stairs")
	for mesh in stair.find_children("Stringer","MeshInstance3D",true,false):
		var bounds:AABB=mesh.global_transform*mesh.get_aabb()
		check(bounds.end.y<4.02,"Stair side member ends below the upper landing")
	check(GameState.next_cartridge_id().begins_with("HYPERION"),"Spaceport and cartridge branding use Hyperion")
	SettingsStore.graphics=original
	SettingsStore.apply_view(get_viewport())
	SaveStore.world=null
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
