extends Node
var failed:=false
func check(value:bool,message:String) -> void:
	print("PASS " if value else "FAIL ",message)
	failed=failed or not value
func shot(label:String) -> void:
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/map_revision_"+label+".png")
func _ready() -> void:call_deferred("run")
func run() -> void:
	SceneManager.menu_intro_seen=true
	var menu=preload("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu._title.text=="Mission Arestemis","Updated game title")
	await shot("menu")
	var old_guidance:=SettingsStore.guidance
	SettingsStore.guidance=-1
	menu._play()
	await shot("guidance")
	SettingsStore.guidance=old_guidance
	menu.queue_free()
	await get_tree().process_frame
	var world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not world.get_node("Floor01").has_node("KKA_Stairs"),"Clean-room stairs removed")
	var spaces=world.get_world_3d().direct_space_state
	for floor_name in ["Floor01","Floor02"]:
		for room in world.get_node(floor_name).get_children():
			if room.get("room_title")==null:continue
			if room.position.x==-32 and room.room_title!="TECHNICAL CORRIDOR":
				check(room.get_node("DoorsAnchor").get_child_count()==1,"One MIK entrance: "+floor_name+" "+room.room_title)
		var y:float=0 if floor_name=="Floor01" else 4
		for z in [-14.0,-10.0,-6.0,-2.0]:
			var ray:=PhysicsRayQueryParameters3D.create(Vector3(7,y+0.6,z),Vector3(7,y-0.5,z),1)
			var hit:Dictionary=spaces.intersect_ray(ray)
			check(not hit.is_empty() and absf(hit.position.y-y)<0.03,"Solid clean-room floor at "+str(Vector3(7,y,z)))
	var supported:=0
	for node in world.find_children("*","Node3D",true,false):
		if node.has_meta("support_surface"):
			check(absf(node.position.y-node.get_meta("support_surface")-0.002)<0.001,"Supported prop: "+str(node.name))
			supported+=1
	check(supported>12,"Small items attached to work surfaces")
	var map:RID=world.navigation.get_navigation_map()
	print("REGION ",world.navigation.navigation_mesh.get_polygon_count()," ",map," agent ",world.engineer.agent.get_navigation_map()," world ",world.get_world_3d().navigation_map)
	await get_tree().create_timer(0.2).timeout
	for frame in 180:
		if NavigationServer3D.map_get_iteration_id(map)>0:break
		await get_tree().physics_frame
	var start:=NavigationServer3D.map_get_closest_point(map,Vector3(-30,4.1,1.5))
	var finish:=NavigationServer3D.map_get_closest_point(map,Vector3(7,4.1,4))
	var path:=NavigationServer3D.map_get_path(map,start,finish,true)
	print("LAB_ROUTE ",start," -> ",finish," points=",path.size())
	check(path.size()>1,"Upper labs accessible through MIK gallery")
	var cam:=Camera3D.new()
	world.add_child(cam)
	cam.position=Vector3(6,5.6,-5.7)
	cam.look_at(Vector3(7,4,-12))
	cam.make_current()
	world.gameplay_ui.hud.hide()
	await shot("cleanroom")
	cam.position=Vector3(-24.5,5.65,5)
	cam.look_at(Vector3(-27,5.3,0))
	await shot("corridor")
	var position_before:Vector3=world.player.global_position
	world._on_pause_requested()
	var pause=world._pause_overlay
	check(get_tree().paused,"Pause stops simulation")
	pause._open_settings()
	check(is_instance_valid(pause._settings_page) and get_tree().paused,"Settings open without leaving paused world")
	await shot("settings")
	pause._settings_page._back()
	await get_tree().process_frame
	check(get_tree().paused and world.player.global_position==position_before,"Returning preserves current game and pause")
	pause._resume()
	await get_tree().process_frame
	check(not get_tree().paused and world.player.controls_enabled,"Resume restores player controls")
	var elevator:=preload("res://scenes/world/elevator_intro.tscn").instantiate()
	world.add_child(elevator)
	var mirror=elevator.get_child(elevator.get_child_count()-1)
	for child in elevator.get_children():
		if child.get_script()==preload("res://scripts/gameplay/lift_mirror.gd"):mirror=child
	cam.global_position=elevator.global_position+Vector3(-0.45,1.65,-0.6)
	cam.look_at(mirror.global_position)
	check(mirror.viewport.size.x==240 and mirror.viewport.positional_shadow_atlas_size==0,"Mirror uses low-resolution shadow-free reflection")
	await shot("mirror")
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
