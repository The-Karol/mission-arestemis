extends Node3D

var door_headers := {}
var fitted_doors := {}
var contact_shadow := ShaderMaterial.new()

func _header(parent: Node3D, position_world: Vector3, along_x: bool, bottom: float, top: float) -> void:
	var at := Vector3(position_world.x,position_world.y+(bottom+top)*0.5,position_world.z)
	var key := Vector3i((at*100).round())
	if door_headers.has(key): return
	door_headers[key] = true
	var section := Vector3(1.8,top-bottom,0.24) if along_x else Vector3(0.24,top-bottom,1.8)
	var cap := SpaceVisuals.box(parent,"DoorTransom",section,parent.to_local(at),Color.WHITE,true)
	cap.material_override = preload("res://materials/facility_wall.tres")

func dress(world: Node3D) -> void:
	contact_shadow.shader = preload("res://materials/contact_shadow.gdshader")
	for floor_node in [world.get_node("Floor01"), world.get_node("Floor02")]:
		for room in floor_node.get_children():
			if room.get("room_title") != null:
				_dress_room(room)
				_furnish_room(room)
	for entry in [["builder",Vector3(-34.0,0,0.65),1.05],["scientist",Vector3(5.8,4,5.1),1.7],["technician",Vector3(55.9,0,5.45),-1.74]]:
		var crew := preload("res://scripts/gameplay/station_crew.gd").new()
		crew.role = entry[0]
		crew.name = str(entry[0]).to_pascal_case()
		crew.position = entry[1]
		crew.rotation.y = entry[2]
		add_child(crew)
	_wayfinding()
	_hall_structure()
	_control_lobby()
	_gallery_structure()

func _hall_structure() -> void:
	var structure := Color(0.27, 0.33, 0.34)
	SpaceVisuals.box(self, "AssemblyRoof", Vector3(27, 0.3, 36), Vector3(-13.5, 13.65, 2), structure)
	SpaceVisuals.box(self, "UpperSouthShell", Vector3(27, 9.5, 0.22), Vector3(-13.5, 8.75, 20.15), structure)
	var north_return := SpaceVisuals.box(self,"NorthClerestoryReturn",Vector3(5.0,6.1,0.24),Vector3(-24.5,10.45,-16),structure,true)
	north_return.material_override = preload("res://materials/facility_wall.tres")
	var south_return := SpaceVisuals.box(self,"GalleryEastReturn",Vector3(0.24,9.5,4),Vector3(0.05,8.75,18),structure,true)
	south_return.material_override = preload("res://materials/facility_wall.tres")
	var west_return := SpaceVisuals.box(self,"GalleryWestReturn",Vector3(0.24,6.1,4.0),Vector3(-27,10.45,18),structure,true)
	west_return.material_override = preload("res://materials/facility_wall.tres")
	SpaceVisuals.box(self, "UpperWestShell", Vector3(0.22, 6.1, 32), Vector3(-22, 10.45, 0), structure)
	for z in [-12, -4, 4, 12]:
		var upper_cap := SpaceVisuals.box(self, "EastHeader", Vector3(0.24, 6.1, 1.8), Vector3(0, 10.45, z), structure,true)
		upper_cap.material_override = preload("res://materials/facility_wall.tres")
		SpaceVisuals.box(self, "RoofBeam", Vector3(22, 0.35, 0.25), Vector3(-11, 13.2, z), Color(0.16, 0.22, 0.24))
	for z in [-8, 8]:
		var light := OmniLight3D.new()
		light.position = Vector3(-11, 9, z)
		light.omni_range = 20
		light.light_energy = 2.0
		light.light_color = Color("ffdfa9")
		add_child(light)
	for x in [-17.0,-5.0]:
		for z in [-10.0,0.0,10.0]:
			var housing := SpaceVisuals.box(self,"HighBayPendant",Vector3(2.05,0.19,0.68),Vector3(x,12.7,z),Color("384345"))
			SpaceVisuals.box(housing,"Diffuser",Vector3(1.84,0.035,0.51),Vector3.DOWN*0.11,Color("ffe3ac"),false,true)
			for side in [-0.76,0.76]:
				SpaceVisuals.box(housing,"Suspension",Vector3(0.035,0.70,0.035),Vector3(side,0.42,0),Color("675f50"))
	for z in [-9,8]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(-11,11.8,z)
		spot.rotation.x = -PI/2
		spot.light_color = Color(1,0.86,0.67)
		spot.light_energy = 5.0
		spot.spot_range = 20
		spot.spot_angle = 65
		spot.shadow_enabled = false
		add_child(spot)

func _dress_room(room: Node3D) -> void:
	var anchor: Node3D = room.get_node("PropsAnchor")
	var accent: Color = room.zone_color
	var half: Vector2 = room.room_size * 0.5
	room.get_node("RoomLabel").hide()
	for marker in room.get_node("DoorsAnchor").get_children():
		var along_x := str(marker.name).begins_with("North") or str(marker.name).begins_with("South")
		var ground := Vector3(marker.global_position.x,room.global_position.y,marker.global_position.z)
		var top := minf(room.wall_height,4.0)
		# The hall stair crosses the south wall at the upper landing.
		if room.room_title == "MAIN ROCKET ASSEMBLY HALL" and str(marker.name).begins_with("South"): continue
		_header(anchor,ground,along_x,2.55,top)
		if room.wall_height > 6 and room.room_title != "MAIN LAUNCH CONTROL" and str(marker.name).begins_with("East"):
			_header(anchor,ground,along_x,6.55,minf(room.wall_height,7.4))

	# Skirting and waist-height zone bands follow the actual segmented walls,
	# preserving every existing doorway rather than painting over it.
	for wall in room.get_node("Architecture").get_children():
		if wall.is_queued_for_deletion() or not str(wall.name).contains("Wall"):
			continue
		var shape := wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var dimensions: Vector3 = shape.shape.size
		var band := Vector3(dimensions.x + 0.014, 0.075, dimensions.z + 0.014)
		var pos: Vector3 = wall.position
		SpaceVisuals.box(anchor, "ZoneBand", band, Vector3(pos.x, 0.91, pos.z), accent.darkened(0.48))
		band.y = 0.14
		SpaceVisuals.box(anchor, "Skirting", band, Vector3(pos.x, 0.10, pos.z), Color(0.13, 0.18, 0.19))
	if room.room_title not in ["MIK PASSAGE", "MAIN ROCKET ASSEMBLY HALL"]:
		var height := minf(room.wall_height - 0.3, 3.1)
		_ceiling(anchor, "architecture/pendant_light", Vector3(0, room.wall_height, -half.y * 0.4), 1.35)
		var light := OmniLight3D.new()
		light.position = Vector3(0, height - 0.2, 0)
		light.omni_range = maxf(half.x, half.y) + 2
		light.light_color = Color(0.86, 0.92, 1.0) if room.position.x >= 0 else Color(1.0, 0.91, 0.77)
		light.light_energy = 1.25
		light.shadow_enabled = false
		anchor.add_child(light)
		if room.room_title in ["PROJECT OFFICE","WORKSHOP","SPACECRAFT DEVELOPMENT LAB"]:
			light.light_energy = 0.45
			var pool := SpotLight3D.new()
			pool.position = Vector3(0,room.wall_height-0.18,0)
			pool.rotation.x = -PI/2
			pool.light_color = light.light_color
			pool.light_energy = 2.8
			pool.spot_range = 9
			pool.spot_angle = 75
			pool.shadow_enabled = false
			anchor.add_child(pool)
		# A perimeter cove lifts the ceiling and breaks up the flat box silhouette.
		var warm := Color(0.85,0.65,0.37) if room.position.x < 0 else Color(0.35,0.70,0.82)
		SpaceVisuals.box(anchor,"CeilingLightStrip",Vector3(room.room_size.x-0.7,0.035,0.045),Vector3(0,height,-half.y+0.22),warm,false,true)
		for x in [-half.x+0.25,half.x-0.25]:
			SpaceVisuals.box(anchor,"StructuralPillar",Vector3(0.13,height,0.15),Vector3(x,height*0.5,-half.y+0.25),Color(0.17,0.23,0.25))
	if room.room_title == "MIK PASSAGE": return
	for marker in room.get_node("DoorsAnchor").get_children():
		var at: Vector3 = marker.position
		at.y = 0
		var site := anchor.to_global(at)
		# The elevator supplies its own landing leaves; the KKA ramp needs
		# two floors of headroom where it crosses the partition.
		if absf(site.x+32)<0.2 and site.z>19: continue
		var key := Vector3i((site*100).round())
		if fitted_doors.has(key):continue
		fitted_doors[key]=true
		var sliding:=preload("res://scripts/gameplay/passage_doors.gd").new()
		sliding.position=at
		sliding.rotation.y=PI/2 if str(marker.name).begins_with("East") or str(marker.name).begins_with("West") else 0.0
		anchor.add_child(sliding)

# Each room has one authored arrangement; all positions are room-local.
# Keep the central north/south and east/west doorway axes clear.
func _furnish_room(room: Node3D) -> void:
	var anchor: Node3D = room.get_node("PropsAnchor")
	var title: String = room.room_title
	var h: Vector2 = room.room_size * 0.5
	match title:
		"MAIN ROCKET ASSEMBLY HALL":
			var vehicle := Node3D.new()
			vehicle.set_script(preload("res://scripts/gameplay/display_rocket.gd"))
			vehicle.name = "IntegrationLine"
			vehicle.position = Vector3(0,0,-14.40)
			anchor.add_child(vehicle)
			_prop(anchor,"environment/service_platform",Vector3(3.65,0,-6.25),PI/2,2.15)
			_prop(anchor,"environment/equipment_scaffold",Vector3(-4.25,0,-10.75),-PI/2,2.0)
			_prop(anchor,"environment/instrument_locker",Vector3(8.6,0,-13.5),-PI/2,1.2)
			_prop(anchor,"environment/hand_trolley",Vector3(7.3,0,-12.9),-0.42,0.75)
			var tray := _prop(anchor,"architecture/cable_tray",Vector3(9.85,3.50,-4),PI/2,8.6,false)
			var tray_bounds: AABB = tray.get_meta("model_bounds")
			tray.scale.y = 0.17 / tray_bounds.size.y
			tray.scale.z = 0.38 / tray_bounds.size.z
			for z in [-7.7,-5.3,-2.8,-0.4]:
				SpaceVisuals.box(anchor,"TrayHanger",Vector3(0.05,0.28,0.05),Vector3(9.85,3.69,z),Color("5b605d"))
			_integration_equipment(anchor)
			_prop(anchor,"environment/mobile_lift",Vector3(4.8,0,-2),PI,1.6)
			for z in [-11.0,-3.0,9.0]:
				_prop(anchor,"environment/industrial_workbench",Vector3(-8.8,0,z),PI/2,2.2)
				_prop(anchor,"environment/tool_cabinet",Vector3(-9.8,0,z+2),PI/2,0.85)
				_prop(anchor,"environment/technical_container",Vector3(8.7,0,z),-PI/2,1.3)
			_prop(anchor,"environment/overhead_crane",Vector3(0,10,-10.5),0,19,false)
			_prop(anchor,"environment/compressor_unit",Vector3(8.7,0,7),-PI/2,1.4)
			_prop(anchor,"category_c_assembly/stage_handling_dolly",Vector3(-5.7,0,-12.6),PI/2,1.7)
			_prop(anchor,"category_c_assembly/engine_transport_cradle",Vector3(4.1,0,6.6),PI/2,1.6)
			_prop(anchor,"category_c_assembly/assembly_status_display",Vector3(5.5,0,-15.2),0,1.1)
			_prop(anchor,"category_c_assembly/lifting_spreader",Vector3(0,8.5,-10.5),0,2.2,false)
			_prop(anchor,"category_c_assembly/rocket_access_platform_half",Vector3(-3.7,0,-4.0),PI/2,2.8)
			_prop(anchor,"category_c_assembly/rocket_access_platform_half",Vector3(3.7,0,-4.0),-PI/2,2.8)
			var parts_bench:=_prop(anchor,"environment/lab_table",Vector3(-7.1,0,4.8),0,2.6)
			_on_top(parts_bench,"category_c_assembly/rocket_external_antenna",Vector2(-0.8,0),0.24)
			_on_top(parts_bench,"category_c_assembly/rocket_external_sensor",Vector2(-0.25,0),0.25)
			_on_top(parts_bench,"category_c_assembly/fairing_release_latch",Vector2(0.3,0),0.22)
			_on_top(parts_bench,"category_c_assembly/small_correction_thruster",Vector2(0.8,0),0.28)
			var payload_bench:=_prop(anchor,"environment/lab_table",Vector3(7.3,0,5.2),0,2.5)
			_on_top(payload_bench,"category_c_assembly/extra_large_solar_wing",Vector2(-0.5,0),0.85)
			_on_top(payload_bench,"category_c_assembly/telescope_aperture_cover",Vector2(0.6,0),0.6)
			_prop(anchor,"category_c_assembly/gallery_window_panel",Vector3(0,6.0,-15.85),0,4.0,false)
			_hyperion_badge(anchor,Vector3(0,9.5,-15.82))
		"SECURITY CHECKPOINT":
			_prop(anchor,"environment/security_desk",Vector3(-1.8,0,-2),0,2.2)
			_prop(anchor,"environment/office_chair",Vector3(-1.8,0,-0.8),PI,0.65)
			_prop(anchor,"environment/instrument_locker",Vector3(3.4,0,-2.6),0,1.1)
			_prop(anchor,"environment/security_camera",Vector3(-4.5,2.4,-2),PI/2,0.35,false)
			_prop(anchor,"category_c_assembly/security_metal_detector",Vector3(0,0,2.3),0,1.0)
			_prop(anchor,"category_c_assembly/emergency_cabinet",Vector3(-4.3,0,-3.4),PI/2,0.7)
			_prop(anchor,"category_c_assembly/wall_vent_grille",Vector3(4.87,2.5,-2.5),-PI/2,0.5,false)
		"STORAGE":
			for z in [-2.2,2.2]:
				_prop(anchor,"environment/industrial_shelf",Vector3(-3.7,0,z),PI/2,2.4)
				var pallet:=_prop(anchor,"environment/storage_pallet",Vector3(2.5,0,z),0,1.35)
				_on_top(pallet,"category_c_assembly/marked_technical_case",Vector2.ZERO,0.85)
			_prop(anchor,"environment/pallet_jack",Vector3(3.3,0,0.9),PI/2,0.8)
			_prop(anchor,"category_c_assembly/ups_backup_cabinet",Vector3(-4.5,0,0),PI/2,1.0)
			_prop(anchor,"category_c_assembly/assembly_parts_basket",Vector3(0.6,0,0),0,0.9)
			_prop(anchor,"category_c_assembly/emergency_cabinet",Vector3(4.5,0,3.4),PI,0.7)
		"WORKSHOP":
			_prop(anchor,"environment/industrial_workbench",Vector3(-3.9,0,-1.8),PI/2,2.6)
			_prop(anchor,"environment/tool_board",Vector3(-4.8,1.1,-1.8),PI/2,2.1,false)
			_prop(anchor,"environment/drill_press",Vector3(2.8,0,-2.6),0,0.85)
			_prop(anchor,"environment/welding_unit",Vector3(3,0,2.4),PI,0.9)
			_prop(anchor,"environment/workshop_console",Vector3(-3.5,0,2.6),PI,1.5)
			var lamp_table:=_prop(anchor,"environment/lab_table",Vector3(2.8,0,0),0,1.5)
			_on_top(lamp_table,"category_c_assembly/adjustable_desk_lamp",Vector2(-0.4,0),0.3)
			_on_top(lamp_table,"category_c_assembly/cartridge_storage_case",Vector2(0.3,0),0.45)
			_prop(anchor,"category_c_assembly/wall_vent_grille",Vector3(4.87,2.4,-2.5),-PI/2,0.5,false)
		"PROJECT OFFICE":
			_desk(anchor,Vector3(-2.7,0,-4.6),0,"environment/desk_display")
			_prop(anchor,"environment/file_shelf",Vector3(3.5,0,-4.8),0,1.6)
			_prop(anchor,"environment/planning_board",Vector3(2.6,0,-5.5),0,2.5)
			_prop(anchor,"category_c_assembly/orbital_wall_chart",Vector3(-4.85,1.0,1.8),PI/2,1.8,false)
			_prop(anchor,"category_c_assembly/engineering_plotter",Vector3(-3.7,0,4.7),PI,1.4)
			
			_prop(anchor,"category_c_assembly/mission_target_display",Vector3(0,0,-5.6),0,1.3,false)
			var display_table:=_prop(anchor,"environment/lab_table",Vector3(3.4,0,3.8),PI/2,1.5)
			_on_top(display_table,"category_c_assembly/display_rocket_miniature",Vector2(-0.35,0),0.22)
			_on_top(display_table,"category_c_assembly/satellite_display_miniature",Vector2(0.35,0),0.42)
			_prop(anchor,"category_c_assembly/mission_target_photo",Vector3(4.85,1.75,2.2),-PI/2,1.4,false)
		"CLEAN ROOM SUITE", "VEHICLE PREPARATION", "SPACECRAFT DEVELOPMENT LAB", "SPACECRAFT TEST BAY", "TEST LABORATORY":
			# Continuous clean-room floor; keep workstations clear of the doorway axes.
			_prop(anchor,"environment/cleanroom_workstation",Vector3(-4.7,0,-2.5),0,2.4)
			var bench := _prop(anchor,"environment/lab_table",Vector3(-4.6,0,2.7),PI,2.5)
			var bench_top := SpaceVisuals.surface_height(bench,"lab_top")
			SpaceVisuals.model(bench,"environment/lab_electronics_station",Vector3(-0.65,bench_top,0.1),0,0.6,false)
			if title=="SPACECRAFT DEVELOPMENT LAB":
				SpaceVisuals.model(bench,"category_c_assembly/laboratory_test_robot_arm",Vector3(0.65,bench_top,0.1),0,0.52,false)
			else:
				SpaceVisuals.model(bench,"environment/microscope",Vector3(0.65,bench_top,0.1),0,0.45,false)
			SpaceVisuals.model(bench,"environment/oscilloscope",Vector3(0,bench_top,0.1),0,0.55,false)
			_prop(anchor,"environment/instrument_locker",Vector3(5.6,0,-2.5),0,1.0)
			_on_top(bench,"category_c_assembly/laboratory_sample_container",Vector2(0.3,-0.2),0.22)
			_prop(anchor,"category_c_assembly/animated_control_screen",Vector3(6.83,1.7,-0.5),-PI/2,0.85,false)
			_prop(anchor,"environment/cleanroom_cart",Vector3(5.8,0,2.5),-PI/2,0.85)
			_prop(anchor,"environment/mobile_instrument_rack",Vector3(3.9,0,-2.6),0,0.7)
			if room.position.y < 1:
				var stand := _prop(anchor,"environment/spacecraft_test_bed",Vector3(-2.8,0,0.5),0,1.8)
				var craft_path := "spacecraft/satellite/satellite_base" if title == "SPACECRAFT TEST BAY" else "spacecraft/probe/interplanetary_probe_base"
				_prop(anchor,craft_path,Vector3(-2.8,SpaceVisuals.surface_height(stand,"bed"),0.5),0,0.85,false)
			elif title == "TEST LABORATORY":
				_prop(anchor,"environment/vibration_test_stand",Vector3(-2.6,0,0.8),0,1.6)
				_prop(anchor,"environment/test_chamber",Vector3(2,0,-2.6),0,1.7)
			if room.ceiling_enabled:
				_ceiling(anchor,"architecture/hepa_filter",Vector3(-3.8,room.wall_height,0),1.4)
		"MAIN LAUNCH CONTROL":
			_control_room(anchor)
			_prop(anchor,"category_c_assembly/outdoor_light_mast",Vector3(9.5,0,-7.5),0,1.6,false)
			_prop(anchor,"category_c_assembly/pad_signal_beacon",Vector3(9.5,0,-6.3),0,0.9,false)
			_prop(anchor,"category_c_assembly/nebula_backdrop",Vector3(-9.8,3.2,0),PI/2,3.4,false)
		"COMMUNICATIONS AND SERVERS":
			for z in [-3.5,-1.9,1.9,3.5]:
				_prop(anchor,"environment/server_rack",Vector3(-3.8,0,z),PI/2,1.0)
			_desk(anchor,Vector3(2.7,0,-4.2),0,"environment/desk_display")
			_prop(anchor,"environment/cable_connection_panel",Vector3(4.8,0.8,2),-PI/2,1.3,false)
			_prop(anchor,"environment/communication_workstation",Vector3(2.8,0,3.7),PI,1.8)
			_prop(anchor,"category_c_assembly/ups_backup_cabinet",Vector3(-3.8,0,-5.0),0,1.0)
			_prop(anchor,"category_c_assembly/technical_wall_diagram",Vector3(4.85,1.6,-0.5),-PI/2,1.3,false)
		"BRIEFING ROOM":
			_prop(anchor,"environment/briefing_lectern",Vector3(-1,0,-4.2),0,1.2)
			_prop(anchor,"environment/mission_display",Vector3(0,0,-5.2),0,3.8)
			_prop(anchor,"category_c_assembly/nebula_backdrop",Vector3(0,3.0,-5.9),0,3.0,false)
			_prop(anchor,"category_c_assembly/distant_gas_giant",Vector3(-3.5,2.4,-5.95),0,0.9,false)
			_prop(anchor,"category_c_assembly/distant_exoplanet",Vector3(3.5,2.4,-5.95),0,0.9,false)
			for z in [-1.8,0.5,2.8]:
				for x in [-2.2,0,2.2]:
					_prop(anchor,"environment/briefing_chair",Vector3(x,0,z),PI,0.7)
		"MIK PASSAGE", "TECHNICAL CORRIDOR", "STAIR LOBBY":
			if title == "MIK PASSAGE":
				for z in range(-int(h.y)+2,int(h.y),6):
					_ceiling(anchor,"architecture/corridor_light",Vector3(0,room.wall_height,z),1.4)
			else:
				_prop(anchor,"environment/service_wall_panel",Vector3(-h.x+0.18,0.7,2),PI/2,1.1,false)
				_prop(anchor,"environment/pipe_service_panel",Vector3(h.x-0.18,0.4,-2),-PI/2,1.2,false)
			if title == "TECHNICAL CORRIDOR": _arrival_station(anchor)
			if title == "TECHNICAL CORRIDOR":
				_prop(anchor,"category_c_assembly/technical_wall_diagram",Vector3(-4.85,1.6,-1),PI/2,1.2,false)
				_prop(anchor,"category_c_assembly/wall_vent_grille",Vector3(4.85,2.3,0.5),-PI/2,0.5,false)
		_:
			if title.contains("OFFICE") or title in ["ENGINEERING","TECHNICAL SUPPORT","KKA SUPPORT ROOMS","MISSION PLANNING","DATA ANALYSIS","COMMUNICATIONS","OPERATIONS ROOM"]:
				for x in [-h.x+2.0,h.x-2.0]:
					_desk(anchor,Vector3(x,0,-h.y+1.0),0,"environment/desk_display")
				_prop(anchor,"environment/storage_cabinet",Vector3(-h.x+1.2,0,h.y-0.7),PI,1.25)
				_prop(anchor,"environment/file_shelf",Vector3(h.x-1.2,0,h.y-0.7),PI,1.25)
				if title == "ENGINEERING":
					_prop(anchor,"environment/diagnostics_station",Vector3(-h.x+0.8,0,0),PI/2,1.4)
					_prop(anchor,"environment/blueprint_panel",Vector3(h.x-0.15,1.1,1),-PI/2,1.8,false)
				if title == "TECHNICAL SUPPORT":
					_prop(anchor,"environment/electronics_rack",Vector3(-h.x+0.8,0,1.5),PI/2,0.9)
					_prop(anchor,"environment/hand_trolley",Vector3(h.x-0.8,0,2),-PI/2,0.65)

func _integration_equipment(anchor: Node3D) -> void:
	# Each carriage rolls along the same pair of recessed alignment rails.
	for x in [-0.95,0.95]:
		SpaceVisuals.box(anchor,"GuideRecess",Vector3(0.29,0.02,18.7),Vector3(x,0.012,-6.05),Color("303738"))
		SpaceVisuals.box(anchor,"MachinedRail",Vector3(0.11,0.06,18.7),Vector3(x,0.03,-6.05),Color("8b9390"))
		for z in [-15.05,2.95]:
			SpaceVisuals.box(anchor,"RailStop",Vector3(0.26,0.20,0.22),Vector3(x,0.11,z),Color("c1934e"),true)
	_prop(anchor,"environment/service_hose",Vector3(4.3,0,-3.7),-0.23,1.12,false)
	_prop(anchor,"environment/assembly_floodlight",Vector3(-3.2,0,-2.9),-0.53,0.75)
	_prop(anchor,"environment/cable_test_stand",Vector3(5.65,0,-10.55),-PI/2,1.75)
	_prop(anchor,"environment/mobile_instrument_rack",Vector3(4.7,0,-12.15),-PI/2,0.75)
	_prop(anchor,"environment/rocket_test_fixture",Vector3(6.65,0,8.2),0,1.9)
	for entry in [["ENGINE",-10.1],["UPPER STAGE",-4.1],["FAIRING",0.25]]:
		var marking := SpaceVisuals.label(anchor,entry[0],Vector3(-2.4,0.021,entry[1]),Color("c0aa79"),36)
		marking.rotation = Vector3(-PI/2,-PI/2,0)
		marking.pixel_size = 0.007
		marking.outline_size = 0
	_bay_steelwork(anchor)
	var steel := Color("505b5b")
	for x in [-9.32,9.32]:
		for z in [-14.3,-7.9,1.0,10.5,14.3]:
			SpaceVisuals.box(anchor,"ColumnFoot",Vector3(0.69,0.12,0.70),Vector3(x,0.06,z),steel,true)
			SpaceVisuals.box(anchor,"RunwayColumn",Vector3(0.34,10.69,0.38),Vector3(x,5.465,z),steel,true)
		SpaceVisuals.box(anchor,"RunwayWeb",Vector3(0.16,0.47,30),Vector3(x,11.035,0),steel)
		SpaceVisuals.box(anchor,"RunwayCap",Vector3(0.39,0.09,30),Vector3(x,11.28,0),Color("bd9559"))
	for z in [-9,8]:
		_dust_column(anchor,Vector3(0,5,z))

func _bay_steelwork(anchor: Node3D) -> void:
	var steel := Color("545e60")
	var web := Color("6d7775")
	for z in [-14.3,-7.9,1.0,10.5,14.3]:
		for side in [-1.0,1.0]:
			var x: float = side*9.32
			SpaceVisuals.box(anchor,"UpperColumn",Vector3(0.36,2.36,0.38),Vector3(x,12.30,z),steel)
			_strut(anchor,Vector3(x,11.65,z),Vector3(x-side*1.9,12.56,z),0.19,web)
		SpaceVisuals.box(anchor,"TrussBottomChord",Vector3(19.0,0.16,0.18),Vector3(0,12.54,z),steel)
		SpaceVisuals.box(anchor,"TrussTopChord",Vector3(19.0,0.15,0.18),Vector3(0,13.42,z),steel)
		for bay in 10:
			var x := -9.32+bay*1.864
			var y0 := 12.54 if bay%2==0 else 13.42
			var y1 := 13.42 if bay%2==0 else 12.54
			_strut(anchor,Vector3(x,y0,z),Vector3(x+1.864,y1,z),0.105,web)
	for side in [-1.0,1.0]:
		var x: float = side*10.5
		for span in [Vector2(-14.3,-7.9),Vector2(-7.9,1.0),Vector2(1.0,10.5)]:
			_strut(anchor,Vector3(x,7.6,span.x),Vector3(x,10.5,span.y),0.135,web)
			_strut(anchor,Vector3(x,10.5,span.x),Vector3(x,7.6,span.y),0.135,web)
			for tier in [7.57,10.53]:
				SpaceVisuals.box(anchor,"WallGirt",Vector3(0.14,0.17,span.y-span.x),Vector3(x,tier,(span.x+span.y)*0.5),steel)
	# Ribbed transfer door at the end of the track, beneath the clerestory.
	var north := -15.79
	SpaceVisuals.box(anchor,"TransferShutter",Vector3(7.1,6.5,0.12),Vector3(0,3.25,north),Color("596667"))
	var gate_mark := SpaceVisuals.label(anchor,"01",Vector3(-2.04,4.65,north+0.133),Color("d3d2bc"),72)
	gate_mark.pixel_size = 0.018
	gate_mark.outline_size = 0
	for row in 21:
		SpaceVisuals.box(anchor,"ShutterFold",Vector3(6.94,0.045,0.065),Vector3(0,0.19+row*0.30,north+0.08),Color("707978"))
	for side in [-1.0,1.0]:
		SpaceVisuals.box(anchor,"DoorPost",Vector3(0.35,6.82,0.34),Vector3(side*3.64,3.41,north),steel)
		for row in 5:
			SpaceVisuals.box(anchor,"JambMark",Vector3(0.34,0.16,0.02),Vector3(side*3.64,0.24+row*0.42,north+0.177),Color("bc9147"))
	SpaceVisuals.box(anchor,"DoorHead",Vector3(7.62,0.42,0.40),Vector3(0,6.69,north),steel)
	for bay in 6:
		var x := (bay-2.5)*3.03
		SpaceVisuals.box(anchor,"WindowReveal",Vector3(2.9,1.2,0.19),Vector3(x,9.55,north),Color("344649"))
		SpaceVisuals.box(anchor,"FrostedGlazing",Vector3(2.70,0.99,0.025),Vector3(x,9.55,north+0.12),Color("aeb9ac"),false,true)
		SpaceVisuals.box(anchor,"WindowMullion",Vector3(0.055,1.07,0.06),Vector3(x,9.55,north+0.15),steel)

func _strut(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var member := SpaceVisuals.box(parent,"Brace",Vector3(width,width,a.distance_to(b)),(a+b)*0.5,color)
	member.quaternion = Quaternion(Vector3.BACK,(b-a).normalized())

func _dust_column(anchor: Node3D, at: Vector3) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 724 + int(at.z)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.033,0.033)
	var dust := ShaderMaterial.new()
	dust.shader = preload("res://materials/airborne_dust.gdshader")
	quad.material = dust
	var motes := MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.use_custom_data = true
	motes.mesh = quad
	motes.instance_count = 46
	motes.custom_aabb = AABB(Vector3(-3.5,-4.5,-3.5),Vector3(7,9,7))
	for i in motes.instance_count:
		var offset := Vector3(random.randf_range(-3,3),random.randf_range(-4,4),random.randf_range(-3,3))
		motes.set_instance_transform(i,Transform3D(Basis.IDENTITY,offset))
		motes.set_instance_custom_data(i,Color(random.randf(),random.randf(),random.randf(),1))
	var cloud := MultiMeshInstance3D.new()
	cloud.set_meta("decorative_fx",true)
	cloud.multimesh = motes
	cloud.position = at
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(cloud)

func _gallery_structure() -> void:
	var steel := Color("414c4d")
	for x in [-1.88,-22.14]:
		SpaceVisuals.box(self,"CatwalkEdgeChannel",Vector3(0.21,0.25,32),Vector3(x,3.78,0),steel)
	for z in [-14.3,-8,0,8,14.3]:
		# The eastern deck is cantilevered from the hall wall. The western
		# deck spans the service aisle and bears on columns at its inner edge.
		SpaceVisuals.box(self,"EastLedger",Vector3(1.90,0.18,0.16),Vector3(-1,3.72,z),steel)
		var brace := SpaceVisuals.box(self,"EastKneeBrace",Vector3(2.09,0.12,0.12),Vector3(-0.97,3.21,z),steel)
		brace.rotation.z = -0.48
		if z == 0: continue
		SpaceVisuals.box(self,"WestGalleryPost",Vector3(0.21,3.68,0.21),Vector3(-22.30,1.84,z),steel,true)
		SpaceVisuals.box(self,"WestGalleryCrossbeam",Vector3(4.80,0.20,0.18),Vector3(-24.6,3.67,z),steel)
		SpaceVisuals.box(self,"PostShoe",Vector3(0.42,0.10,0.42),Vector3(-22.30,0.05,z),steel)
	for edge in [-1.0,1.0]:
		SpaceVisuals.box(self,"BayWorkingLine",Vector3(0.07,0.008,17.8),Vector3(-11+edge*2.8,0.012,-6),Color("a98b50"))
		SpaceVisuals.box(self,"BayHeadMark",Vector3(1.0,0.008,0.09),Vector3(-11+edge*2.31,0.012,2.88),Color("a98b50"))
	_sign("HB 01   /   INTEGRATION",Vector3(-11,8.1,-15.82),0,Color("eedcc0"))

func _control_lobby() -> void:
	for y in [0.0,4.0]:
		# A continuous colour stripe joins bridge, lobby and flight deck.
		SpaceVisuals.box(self,"FlightDeckRoute",Vector3(5.6,0.009,0.08),Vector3(44.3,y+0.015,4.80),Color("648e91"))
		SpaceVisuals.box(self,"LobbyDatum",Vector3(13.9,0.20,0.04),Vector3(35,y+1.08,6.48),Color("456b70"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(36,y+2.86,4.1)
		lamp.light_color = Color("ffe1b2")
		lamp.light_energy = 1.45
		lamp.omni_range = 8
		add_child(lamp)
		SpaceVisuals.box(self,"GalleryWallLight",Vector3(2.6,0.14,0.12),Vector3(36,y+2.86,6.41),Color("ffdfa3"),false,true)
	_sign("FLIGHT DECK   UP",Vector3(43.86,2.84,4),-PI/2,Color("e3d0aa"))
	_sign("OBSERVATION   /   02",Vector3(36,6.2,6.38),PI,Color("e3d0aa"))
	_sign("02   /   OBSERVATION   ->",Vector3(31.1,2.26,-2.38),0,Color("b9dbce"))

func _control_room(anchor: Node3D) -> void:
	# Clear main aisle from the west connector to briefing, plus circulation behind each row.
	var screen := _prop(anchor,"environment/screen_wall",Vector3(0,0,-7.43),0,7.18)
	var channel := 0
	for glass in screen.find_children("*display_screen*","MeshInstance3D",true,false):
		var display := ShaderMaterial.new()
		display.shader = preload("res://materials/control_display.gdshader")
		display.set_shader_parameter("channel",float(channel))
		glass.material_override = display
		channel += 1
	for row in 2:
		for side in [-1.0,1.0]:
			var station := Vector3(side*(3.2+row*0.55),0,-2.05+row*3.5)
			var yaw: float = side*(0.18+row*0.025)
			_prop(anchor,"environment/launch_control_desk",station,yaw,3.15)
			var seat := station+Vector3(sin(yaw),0,cos(yaw))*1.04
			_prop(anchor,"environment/office_chair",seat,yaw+PI,0.69)
	var comms := _prop(anchor,"environment/communication_workstation",Vector3(8.55,0,-3.65),-PI/2,1.85)
	var tag := SpaceVisuals.label(comms,"COMMS",Vector3(0,1.82,0),Color("b2d2c7"),20)
	tag.pixel_size = 0.004
	for side in [-1,1]:
		var fixture := SpaceVisuals.box(anchor,"ControlPendant",Vector3(4.8,0.16,0.38),Vector3(side*3.2,6.48,-0.25),Color("34464a"))
		SpaceVisuals.box(fixture,"Diffuser",Vector3(4.55,0.035,0.28),Vector3.DOWN*0.09,Color("ffdcaa"),false,true)
		var key := SpotLight3D.new()
		key.position = fixture.position-Vector3.UP*0.14
		key.rotation.x = -PI/2
		key.light_color = Color("ffdaab")
		key.light_energy = 3.1
		key.spot_angle = 43
		key.spot_range = 11
		anchor.add_child(key)
	_sign("FLIGHT CONTROL",anchor.to_global(Vector3(0,5.67,-7.75)),0,Color("b5d0c9"))

func _prop(parent: Node3D, path: String, at: Vector3, yaw: float, width: float, solid: bool = true) -> Node3D:
	var node := SpaceVisuals.model(parent,path,at,yaw,width,solid)
	if node and path.get_file() in ["wall_vent_grille","orbital_wall_chart","mission_target_photo","technical_wall_diagram","animated_control_screen","tool_board","blueprint_panel","emergency_cabinet","security_camera","cable_connection_panel"]:
		_mount_wall_item(node,parent)
	if node and solid and at.y < 0.3:
		var bounds: AABB = node.get_meta("model_bounds")
		var shadow := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(bounds.size.x+0.18,bounds.size.z+0.18)
		shadow.mesh = plane
		shadow.rotation.x = -PI/2
		shadow.position.y = 0.014
		shadow.material_override = contact_shadow
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(shadow)
	if node and path=="environment/test_chamber":_stabilize_chamber_glass(node)
	return node

func _desk(parent: Node3D, at: Vector3, yaw: float, display: String) -> void:
	var desk := _prop(parent,"environment/engineering_desk",at,yaw,1.8)
	var top := SpaceVisuals.surface_height(desk,"desk_top")
	SpaceVisuals.model(desk,display,Vector3(-0.3,top,-0.05),0,0.55,false)
	_on_top(desk,"category_c_assembly/adjustable_desk_lamp",Vector2(0.55,-0.12),0.25)
	SpaceVisuals.model(desk,"props/engineering_clipboard",Vector3(0.4,top+0.002,0.15),-0.12,0.25,false)
	_prop(parent,"environment/office_chair",at+Vector3(sin(yaw),0,cos(yaw))*1.1,yaw+PI,0.65)

func _ceiling(parent: Node3D, path: String, at: Vector3, width: float) -> void:
	var item := SpaceVisuals.model(parent,path,at,0,width,false)
	# Recess the HEPA housing into the slab; only the grille and its rim project
	# below the ceiling's underside (0.09 m below the room height).
	item.position.y -= 0.115 if path=="architecture/hepa_filter" else SpaceVisuals.bounds_of(item).size.y

func _arrival_station(anchor: Node3D) -> void:
	var desk := _prop(anchor,"environment/engineering_desk",Vector3(-2.6,0,-1.7),0.16,2.1)
	var height := SpaceVisuals.surface_height(desk,"desk_top")
	SpaceVisuals.model(desk,"interactive/retro_computer_spacecraft",Vector3(-0.30,height,0),0,0.6,false)
	SpaceVisuals.model(desk,"props/engineering_clipboard",Vector3(0.55,height,0.18),0.1,0.3,false)
	_prop(anchor,"environment/office_chair",Vector3(-2.45,0,-0.60),PI+0.24,0.67)
	_prop(anchor,"environment/technical_container",Vector3(3.05,0,-1.9),-0.15,1.15)
	_prop(anchor,"environment/hand_trolley",Vector3(3.95,0,-2.35),-0.3,0.7)
	for z in [-2.7,0.3,2.7]:
		var fixture := SpaceVisuals.model(anchor,"architecture/corridor_light",Vector3(0,3.14,z),0,1.45,false)
		var lens := SpaceVisuals.box(fixture,"AmberDiffuser",Vector3(1.08,0.035,0.36),Vector3(0,-0.015,0),Color("ffe4b9"),false,true)
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-2.0,2.0]:
		var tray := SpaceVisuals.model(anchor,"architecture/cable_tray",Vector3(x,3.04,0),PI/2,7.3,false)
		var extent: AABB = tray.get_meta("model_bounds")
		tray.scale.y = 0.19/extent.size.y
		tray.scale.z = 0.28/extent.size.z
	var key := SpotLight3D.new()
	anchor.add_child(key)
	key.position = Vector3(-1.5,3.1,2.7)
	key.look_at(anchor.to_global(Vector3(0.35,0.8,1.7)))
	key.light_color = Color("ffcf9b")
	key.light_energy = 1.05
	key.spot_angle = 60
	key.spot_range = 8
	key.shadow_enabled = false
	var fill := OmniLight3D.new()
	fill.position = Vector3(2.5,2.4,-1.4)
	fill.light_color = Color("ffbc83")
	fill.light_energy = 0.85
	fill.omni_range = 6.5
	anchor.add_child(fill)
	var reflection := ReflectionProbe.new()
	reflection.position = Vector3(0,1.6,0)
	reflection.size = Vector3(10,3.4,8)
	reflection.box_projection = true
	reflection.interior = true
	reflection.intensity = 0.45
	anchor.add_child(reflection)

func _wayfinding() -> void:
	_sign("ASSEMBLY HALL   >\nMISSION CONTROL   >", Vector3(-34.6, 1.95, 12.16), 0, Color(0.97, 0.88, 0.73))
	_sign("02  /  PROJECT OFFICE  <\nKKA LABORATORIES  >", Vector3(-11, 6.2, 19.7), PI, Color(0.94, 0.69, 0.35))
	_sign("SPACECRAFT DESIGN\n^  LEVEL 02  /  KKA", Vector3(1.7, 2.3, 4.2), PI / 2, Color(0.57, 0.82, 0.83))
	_sign("PRE-LAUNCH CHECK  >\nTEST LABORATORY / 02", Vector3(7, 6.5, 7.7), PI, Color(0.57, 0.82, 0.83))
	_sign("MISSION CONTROL  >\nENCLOSED PASSAGE / CUZ", Vector3(22, 2.2, 2.0), 0, Color(0.57, 0.82, 0.83))
	# Floor stripes identify the traversable route through the generous blockout.
	for y in [0.015, 4.015]:
		SpaceVisuals.box(self, "WestRoute", Vector3(0.10, 0.006, 31.5), Vector3(-25.6, y, 0), Color(0.84, 0.58, 0.25), false, true)
		SpaceVisuals.box(self, "PassageRoute", Vector3(27, 0.006, 0.10), Vector3(28, y, 4.8), Color(0.32, 0.65, 0.67), false, true)
	SpaceVisuals.box(self, "GalleryRoute", Vector3(25, 0.006, 0.10), Vector3(-13, 4.015, 18.7), Color(0.84, 0.58, 0.25), false, true)
	SpaceVisuals.box(self, "EastGalleryRoute", Vector3(0.10, 0.006, 30), Vector3(-0.6, 4.015, 0), Color(0.32, 0.65, 0.67), false, true)

func _sign(_text: String, _at: Vector3, _yaw: float, _color: Color) -> void:
	pass

func _on_top(support: Node3D, path: String, offset: Vector2, width: float) -> Node3D:
	var top:=SpaceVisuals.surface_height(support,"top")
	var item:=SpaceVisuals.model(support,path,Vector3(offset.x,top+0.002,offset.y),0,width,false)
	item.set_meta("support_surface",top)
	return item

func _mount_wall_item(item: Node3D, anchor: Node3D) -> void:
	var room:=anchor.get_parent()
	var architecture:=room.get_node_or_null("Architecture")
	if not architecture:return
	var box: AABB=item.get_meta("model_bounds")
	# The new wall kits were authored paper-up (thin Y), not vertically.
	var flat:=box.size.y<box.size.z*0.5
	var best_score:=INF
	var desired:=item.position
	if str(item.get_meta("asset_path","")).ends_with("emergency_cabinet"):desired.y=0.55
	var best_position:=Vector3.ZERO
	var best_basis:=Basis.IDENTITY
	var best_body:Node3D
	for wall:Node3D in architecture.get_children():
		if wall.is_queued_for_deletion() or not str(wall.name).contains("Wall"):continue
		var collider:=wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not collider or not collider.shape is BoxShape3D:continue
		var dim:Vector3=collider.shape.size
		var along_x:=dim.x>dim.z
		var inward:=Vector3(0,0,-signf(wall.position.z)) if along_x else Vector3(-signf(wall.position.x),0,0)
		var yaw:=atan2(inward.x,inward.z)
		var basis:=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,PI/2 if flat else 0)
		var fitted: AABB=Transform3D(basis,Vector3.ZERO)*box
		var span:=dim.x if along_x else dim.z
		var width:=fitted.size.x if along_x else fitted.size.z
		if span<width+0.14 or dim.y<fitted.size.y+0.12:continue
		var center:=wall.position
		var horizontal:=desired.x if along_x else desired.z
		var origin:=center.x if along_x else center.z
		horizontal=clampf(horizontal,origin-(span-width)*0.5+0.06,origin+(span-width)*0.5-0.06)
		var point:=center+inward*((dim.z if along_x else dim.x)*0.5+(fitted.size.z if along_x else fitted.size.x)*0.5+0.006)
		if along_x:point.x=horizontal
		else:point.z=horizontal
		point.y=clampf(desired.y+fitted.size.y*0.5,center.y-(dim.y-fitted.size.y)*0.5+0.04,center.y+(dim.y-fitted.size.y)*0.5-0.04)
		var score:=point.distance_squared_to(desired+Vector3.UP*fitted.size.y*0.5)
		if score<best_score:
			best_score=score
			best_position=point-fitted.get_center()
			best_basis=basis
			best_body=wall
	if best_body:
		item.transform=Transform3D(best_basis,best_position)
		item.set_meta("wall_mounted",true)
		item.set_meta("support_wall",best_body.get_path())

func _stabilize_chamber_glass(holder:Node3D) -> void:
	var glass:=holder.find_child("glass_door",true,false) as MeshInstance3D
	if not glass:return
	var bounds:=glass.get_aabb()
	var quad:=QuadMesh.new()
	quad.size=Vector2(bounds.size.x,bounds.size.y)
	glass.position+=glass.basis*Vector3(bounds.get_center().x,bounds.get_center().y,bounds.end.z+0.003)
	glass.mesh=quad
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(0.22,0.36,0.40,0.22)
	material.roughness=0.28
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.cull_mode=BaseMaterial3D.CULL_BACK
	glass.material_override=material
	glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.set_meta("stable_glass",true)

func _hyperion_badge(parent:Node3D, at:Vector3) -> void:
	SpaceVisuals.box(parent,"HyperionWallSign",Vector3(4.1,1.025,.08),at,Color("263030"))
	var face:=MeshInstance3D.new()
	var quad:=QuadMesh.new()
	quad.size=Vector2(4.08,1.01)
	face.mesh=quad
	face.position=at+Vector3(0,0,.042)
	var material:=StandardMaterial3D.new()
	material.albedo_texture=preload("res://assets/ui/hyperion_badge.png")
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override=material
	face.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(face)
