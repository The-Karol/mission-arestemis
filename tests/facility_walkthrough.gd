extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var start := Time.get_ticks_usec()
	var world := preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	print("World ready ms ", (Time.get_ticks_usec()-start)/1000)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	for view in [[Vector3(-9,5.62,17.8),Vector3(-11,4,-5)], [Vector3(34,5.62,4),Vector3(53,4,3)]]:
		camera.global_position = view[0]
		camera.look_at(view[1])
		var frames: Array[float] = []
		for frame in 65:
			var t := Time.get_ticks_usec()
			await get_tree().process_frame
			if frame >= 15: frames.append((Time.get_ticks_usec()-t)/1000.0)
		if OS.get_cmdline_user_args().has("--capture"):
			var name := "high_bay" if camera.position.x < 0 else "observation"
			get_viewport().get_texture().get_image().save_png("res://build/facility_"+name+".png")
		frames.sort()
		print("View ",view[0]," p50/p95 ms ",frames[25]," / ",frames[47]," draws ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if OS.get_cmdline_user_args().has("--capture"):
		world.gameplay_ui.visible = false
		camera.global_position = Vector3(-22.64,5.79,-2.1)
		camera.look_at(Vector3(-11,2.55,-5.9))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/facility_integration_line.png")
		world.gameplay_ui.visible = true
	var failed := false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for span in [[Vector3(-26,5.6,19),Vector3(-28,5.6,19)], [Vector3(-32,5.5,19.4),Vector3(-32,5.5,20.5)], [Vector3(-24.5,5.4,-15.4),Vector3(-24.5,5.4,-16.6)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(span[0],span[1],1))
		if hit.is_empty():
			push_error("Unsealed gallery at %s" % span[0])
			failed = true
	var line := world.find_child("IntegrationLine",true,false) as Node3D
	var previous := -INF
	for title in ["PropulsionSection","UpperStageSection","PayloadSection"]:
		var section := line.get_node(title) as Node3D
		var extent: Vector2 = section.get_meta("axial_span")
		var station := line.global_position + Vector3(0,2.2,(extent.x+extent.y)*0.5)
		var solid := not space.intersect_ray(PhysicsRayQueryParameters3D.create(station+Vector3.LEFT*1.8,station+Vector3.RIGHT*1.8,1)).is_empty()
		var supported := line.has_node(title+"Carriage")
		var open_joint := true
		if is_finite(previous):
			var gap := line.global_position + Vector3(0,2.2,(previous+extent.x)*0.5)
			open_joint = space.intersect_ray(PhysicsRayQueryParameters3D.create(gap+Vector3.LEFT*1.8,gap+Vector3.RIGHT*1.8,1)).is_empty() and is_equal_approx(extent.x-previous,0.66)
		previous = extent.y
		print(title," solid / support / joint ",solid," ",supported," ",open_joint)
		failed = failed or not (solid and supported and open_joint)
	var map: RID = world.get_world_3d().navigation_map
	for run in [[Vector3(19,0,4),Vector3(54,0,6.35)], [Vector3(28.7,0,3.2),Vector3(45.4,4,4)], [Vector3(20,4,4),Vector3(49,4,-14)], [Vector3(-11,4,18.3),Vector3(-31,4,0)], [Vector3(-24,0,0),Vector3(-17,0,-4.15)]]:
		var path := NavigationServer3D.map_get_path(map,run[0],run[1],true)
		var arrived := not path.is_empty() and path[-1].distance_to(run[1])<0.9
		if run[0].y < 1 and run[1].y > 3:
			var uses_lobby_stair := false
			for i in range(1,path.size()):
				if path[i-1].y <= 2 and path[i].y > 2:
					var middle := path[i-1].lerp(path[i],(2-path[i-1].y)/(path[i].y-path[i-1].y))
					uses_lobby_stair = middle.distance_to(Vector3(35,2,-0.35))<2.5
			arrived = arrived and uses_lobby_stair
		print("Route ",run," reached ",arrived)
		failed = failed or not arrived
	var dialogue := preload("res://scenes/dialogue/dialogue_ui.tscn").instantiate()
	add_child(dialogue)
	dialogue.configure("Engineer",["Aero"])
	dialogue._process(0.03)
	var first_pitch: float = dialogue.voice.pitch_scale
	var audible: bool = dialogue.voice.stream != null and dialogue.voice.bus == &"SFX"
	dialogue.configure("Assembly specialist",["Aero"])
	dialogue._process(0.03)
	var distinct: bool = dialogue.voice.pitch_scale < first_pitch
	dialogue.advance()
	var silent_skip: bool = not dialogue.voice.playing
	print("Voiced dialogue / speaker pitch / skip ",audible," ",distinct," ",silent_skip)
	failed = failed or not (audible and distinct and silent_skip)
	dialogue.queue_free()
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
