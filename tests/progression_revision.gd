extends Node
const Design=preload("res://scripts/gameplay/design_data.gd")
const Rules=preload("res://scripts/gameplay/rocket_assembly_rules.gd")
var failed:=false
func check(value:bool,message:String) -> void:
	print("PASS " if value else "FAIL ",message)
	failed=failed or not value
func _ready() -> void:call_deferred("run")
func run() -> void:
	GameState.new_session()
	var world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	await get_tree().process_frame
	var carts=get_tree().get_nodes_in_group("cartridges")
	check(carts.size()==1 and not GameState.starter_found,"Campaign starts with one uncollected cartridge")
	var cart=carts[0]
	check(cart.global_position.x>44 and cart.global_position.z< -8,"First cartridge is in CUZ mission planning")
	check(GameState.objective=="Meet the Engineer","First objective introduces the engineer")
	world.engineer.begin()
	check(GameState.objective=="Meet the Engineer","Engineer introduction precedes the search")
	world.engineer._introduced=true
	world.engineer._finish_introduction()
	check(GameState.objective_target==cart.global_position,"Search begins after the engineer briefing")
	world.player.take_item(cart)
	check(GameState.starter_found and GameState.objective.contains("Engineer"),"Picking up cartridge advances to the guide")
	GameState.files_available=true
	var mission:Dictionary=GameState.offered_missions[0]
	check(GameState.select_mission(mission.id),"Remaining mission flow unlocks after cartridge retrieval")
	var terminal=world.get_node("SpacecraftTerminal")
	check(terminal.access_error().contains("Insert"),"Spacecraft station requires the found cartridge")
	terminal.reader.insert_cartridge(world.player)
	await get_tree().create_timer(.45).timeout
	var initial:Dictionary=Design.payload_design(terminal)
	check(initial.module_ids.is_empty(),"New spacecraft has no automatically fitted modules")
	var workshop=preload("res://scripts/gameplay/craft_workshop.gd").new()
	add_child(workshop)
	workshop.open(terminal)
	await get_tree().process_frame
	check(workshop.ids.is_empty() and workshop.preview.modules.is_empty(),"Empty craft view contains only its fixed chassis")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/empty_spacecraft.png")
	var internal_id: String="A1.4"
	workshop.ids=[internal_id]
	workshop._update_design()
	check(workshop.internal_tiles.get_child_count()==1,"Internal module has a visible selectable card")
	workshop.internal_tiles.get_child(0).pressed.emit()
	workshop._delete_selected()
	check(workshop.ids.is_empty() and workshop.internal_tiles.get_child_count()==0,"Deleting internal system removes its visual card")
	var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	var booster:Dictionary=catalog.filter(func(p):return p.category=="BOOSTERS")[0]
	var fitted:Array=[]
	for i in 4:
		check(Rules.addition_error(fitted,booster).is_empty(),"Booster mount "+str(i+1))
		fitted.append(booster.duplicate())
	check(not Rules.addition_error(fitted,booster).is_empty(),"Fifth booster rejected")
	for i in 4:fitted.append(booster.duplicate())
	check(not Rules.validate(fitted).is_empty(),"Old eight-booster designs fail validation")
	cart.write_spacecraft(mission.id,Design.craft(mission.spacecraft_type,[]))
	cart.write_rocket({"parts":[],"payload_type":mission.spacecraft_type})
	var verification=world.get_node("VerificationTerminal")
	terminal.reader.cartridge=null
	verification.reader.cartridge=cart
	var report:String=verification.run_verification()
	check(report.contains("FAIL") and GameState.objective_target==Vector3(10,4,5.5),"Craft fault produces repair objective at Spacecraft Design")
	var craft:Dictionary=Design.craft(mission.spacecraft_type,mission.recommended)
	# A controlled fully equipped payload isolates launcher-only faults.
	var backup:Array=mission.required.duplicate()
	var old_code:String=mission.code
	mission.code="TEST"
	mission.required=[]
	cart.write_spacecraft(mission.id,Design.craft(mission.spacecraft_type,["A1.3","A1.9","A1.6","E9"]))
	cart.write_rocket({"parts":[],"payload_type":mission.spacecraft_type})
	verification.run_verification()
	check(GameState.objective_target==Vector3(-17,0,-5.5),"Launcher-only fault directs player to Rocket Assembly")
	mission.required=backup
	mission.code=old_code
	workshop.queue_free()
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
