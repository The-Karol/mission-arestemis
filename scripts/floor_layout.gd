extends Node3D

const ROOM_SCENE := preload("res://scenes/blockout/room_blockout.tscn")
const STAIRS_SCENE := preload("res://scenes/blockout/stairs_placeholder.tscn")
const FLOOR_SCENE := preload("res://scenes/blockout/floor_module.tscn")
const WALL_SCENE := preload("res://scenes/blockout/wall.tscn")
const MIK_MATERIAL: Material = preload("res://materials/zone_mik.tres")
const KKA_MATERIAL: Material = preload("res://materials/zone_kka.tres")
const CUZ_MATERIAL: Material = preload("res://materials/zone_cuz.tres")
const SERVICE_MATERIAL: Material = preload("res://materials/zone_service.tres")

@export_range(1, 2) var floor_number := 1

func _ready() -> void:
	if floor_number == 1:
		_build_floor_one()
	else:
		_build_floor_two()
	_remove_overlapping_wall_segments()

func _build_floor_one() -> void:
	var mik_rooms := [
		["SECURITY CHECKPOINT",-32.0,-16.0,10.0,8.0,3.4,"mik",["east"]],
		["STORAGE",-32.0,-8.0,10.0,8.0,3.4,"mik",["east"]],
		["WORKSHOP",-32.0,0.0,10.0,8.0,3.4,"mik",["east"]],
		["OFFICES",-32.0,8.0,10.0,8.0,3.4,"mik",["east"]],
		["TECHNICAL CORRIDOR",-32.0,16.0,10.0,8.0,3.4,"service",["east","south"]],
		["MAIN ROCKET ASSEMBLY HALL",-11.0,0.0,22.0,32.0,13.5,"mik",["west"]],
	]
	for data in mik_rooms:
		if data[0]=="MAIN ROCKET ASSEMBLY HALL":
			_add_room(data,0.0,false,true,{"east":[-12.0,-4.0,4.0,12.0]})
		else:
			_add_room(data,0.0)
	# The service strip is an open passage: adjacent room walls provide its boundaries.
	for index in range(5):
		var z := -16.0 + float(index) * 8.0
		_add_room(["MIK PASSAGE", -24.5, z, 5.0, 8.0, 3.4, "service", []], 0.0, true, true, {}, PackedStringArray(["north", "south", "west", "east"]))
	_add_stairs("MIK_Stairs", Vector3(-11.0, 0.0, 5.0), 0.0, 3.0)

	# KKA directly adjoins the assembly hall; aligned doors open into each bay.
	var kka_rooms := [
		["CLEAN ROOM SUITE", 7.0, -12.0, 14.0, 8.0, 3.4, "kka", ["west", "south"]],
		["VEHICLE PREPARATION", 7.0, -4.0, 14.0, 8.0, 3.4, "kka", ["west", "north", "south"]],
		["SPACECRAFT TEST BAY", 7.0, 4.0, 14.0, 8.0, 3.7, "kka", ["west", "north", "south", "east"]],
		["KKA SUPPORT ROOMS", 7.0, 12.0, 14.0, 8.0, 3.4, "kka", ["west", "north"]],
	]
	for data in kka_rooms:
		var extra_openings := {}
		if data[0] == "SPACECRAFT TEST BAY":
			extra_openings = {"north": [-3.5, 3.5]}
		elif data[0] == "KKA SUPPORT ROOMS":
			extra_openings = {"south": [-3.5]}
		_add_room(data, 0.0, true, true, extra_openings, PackedStringArray(["west"]))

	# A straight, enclosed KKA-to-CUZ passage enters the west side of launch control.
	var cuz_rooms := [
		["COMMUNICATIONS AND SERVERS", 49.0, -14.0, 10.0, 12.0, 3.4, "cuz", ["south", "east"]],
		["MISSION PLANNING", 59.0, -14.0, 10.0, 12.0, 3.4, "cuz", ["south", "west"]],
		["MAIN LAUNCH CONTROL", 54.0, 0.0, 20.0, 16.0, 7.0, "cuz", ["east"]],
		["BRIEFING ROOM", 69.0, 0.0, 10.0, 12.0, 3.4, "cuz", ["west"]],
		["OFFICES", 49.0, 12.0, 10.0, 8.0, 3.4, "cuz", ["north","east"]],
		["OPERATIONS ROOM", 59.0, 12.0, 10.0, 8.0, 3.4, "cuz", ["north","west"]],
	]
	for data in cuz_rooms:
		if data[0] == "MAIN LAUNCH CONTROL":
			_add_room(data, 0.0, false, true, {"west": [4.0], "north": [-5.0, 5.0], "south":[-5.0,5.0]})
		else:
			var disabled_sides := PackedStringArray()
			var extras := {}
			match String(data[0]):
				"COMMUNICATIONS AND SERVERS", "MISSION PLANNING":
					disabled_sides.append("south")
					extras = {"east": [-3.5]} if data[0] == "COMMUNICATIONS AND SERVERS" else {"west": [-3.5]}
				"BRIEFING ROOM":
					disabled_sides.append("west")
					extras = {"north": [0.0], "south": [0.0]}
				"OFFICES", "OPERATIONS ROOM":
					disabled_sides.append("north")
			_add_room(data, 0.0, true, true, extras, disabled_sides)
	_add_platform(self, Vector3(35,0,2), Vector3(14,0.24,9), CUZ_MATERIAL, "ControlLobbyFloor")
	_add_stairs("CUZ_Stairs", Vector3(30.0, 0.0, -0.35), PI * 0.5, 2.3, 10.5)
	_add_cuz_gallery(54.0, 0.0, 0.0)
	_add_platform(self, Vector3(43, 0, 2), Vector3(2, 0.24, 9), SERVICE_MATERIAL, "GroundConnectorEntryFloor")
	_partition(self,"GroundLobbyNorthReturn",Vector3(43,1.8,-2.5),Vector3(2.2,3.6,0.24))
	_partition(self,"GroundLobbySouthReturn",Vector3(43,1.8,6.5),Vector3(2.2,3.6,0.24))
	_add_support_facility(0.0)

func _build_floor_two() -> void:
	var floor_y := 4.0
	var mik_rooms := [
		["ENGINEERING",-32.0,-12.0,10.0,12.0,3.2,"mik",["east"]],
		["PROJECT OFFICE",-32.0,0.0,10.0,12.0,3.2,"mik",["east"]],
		["TECHNICAL SUPPORT",-32.0,12.0,10.0,12.0,3.2,"mik",["east"]],
		["MIK PASSAGE",-24.5,0.0,5.0,32.0,3.2,"service",[]],
	]
	for data in mik_rooms:
		if data[0]=="MIK PASSAGE":
			_add_room(data,floor_y,true,false,{},PackedStringArray(["north","south","west","east"]))
		else:
			_add_room(data,floor_y)
	# Continue the passage only outside the gallery's west edge, avoiding duplicate floors.
	_add_platform(self, Vector3(-24.5, floor_y, 0.06), Vector3(5.0, 0.24, 32.12), SERVICE_MATERIAL, "MIKPassageOuterFloor")
	_add_mik_south_gallery()

	var kka_rooms := [
		["CLEAN ROOM SUITE", 7.0, -12.0, 14.0, 8.0, 3.2, "kka", ["west", "south"]],
		["VEHICLE PREPARATION", 7.0, -4.0, 14.0, 8.0, 3.2, "kka", ["west", "north", "south"]],
		["SPACECRAFT DEVELOPMENT LAB", 7.0, 4.0, 14.0, 8.0, 3.2, "kka", ["west", "north", "south", "east"]],
		["TEST LABORATORY", 7.0, 12.0, 14.0, 8.0, 3.2, "kka", ["west", "north"]],
	]
	for data in kka_rooms:
		_add_room(data,floor_y,true,true,{},PackedStringArray(["west"]))

	var cuz_rooms := [
		["DATA ANALYSIS", 49.0, -16.0, 10.0, 12.0, 3.2, "cuz", ["south", "east"]],
		["COMMUNICATIONS", 59.0, -16.0, 10.0, 12.0, 3.2, "cuz", ["south", "west", "east"]],
		["OFFICES", 69.0, -16.0, 10.0, 12.0, 3.2, "cuz", ["south", "west"]],
		["OPERATIONS ROOM", 71.0, 0.0, 10.0, 12.0, 3.2, "cuz", ["west"]],
		["OPERATIONS OFFICES", 49.0, 16.0, 10.0, 12.0, 3.2, "cuz", ["north", "east"]],
		["OFFICES", 59.0, 16.0, 10.0, 12.0, 3.2, "cuz", ["north", "west"]],
	]
	for data in cuz_rooms:
		_add_room(data, floor_y)
	_add_cuz_gallery(54.0, 0.0, floor_y)
	_add_support_facility(floor_y)

func _add_room(data: Array, y: float, ceiling_enabled: bool = true, floor_enabled: bool = true, wall_openings: Dictionary = {}, wall_disabled_sides: PackedStringArray = PackedStringArray()) -> Node3D:
	var room = ROOM_SCENE.instantiate()
	room.name = "Room_%d" % get_child_count()
	room.room_title = String(data[0])
	room.room_size = Vector2(float(data[3]), float(data[4]))
	room.wall_height = float(data[5])
	room.open_sides = PackedStringArray(data[7])
	room.wall_openings = wall_openings.duplicate(true)
	room.wall_disabled_sides = wall_disabled_sides.duplicate()
	room.ceiling_enabled = ceiling_enabled
	room.floor_enabled = floor_enabled
	room.wall_material = _material_for(String(data[6]))
	room.floor_material = _material_for(String(data[6]))
	room.zone_color = _color_for(String(data[6]))
	room.position = Vector3(float(data[1]), y, float(data[2]))
	add_child(room)
	if String(data[0]) in ["MAIN ROCKET ASSEMBLY HALL","MAIN LAUNCH CONTROL"]:
		# Upper galleries must actually overlook the hall. The original tall
		# ground-floor wall extrusions otherwise seal off the entire view.
		for wall in room.get_node("Architecture").get_children():
			if (data[0] == "MAIN LAUNCH CONTROL" and str(wall.name).contains("Wall")) or str(wall.name).begins_with("SouthWall") or str(wall.name).begins_with("WestWall"):
				var collider := wall.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if collider and collider.shape is BoxShape3D:
					var dimensions: Vector3 = collider.shape.size
					dimensions.y = 3.4
					wall.configure(dimensions, room.wall_material)
					wall.position.y = 1.7
	return room

func _material_for(zone: String) -> Material:
	match zone:
		"mik": return MIK_MATERIAL
		"kka": return KKA_MATERIAL
		"cuz": return CUZ_MATERIAL
		_: return SERVICE_MATERIAL

func _color_for(zone: String) -> Color:
	match zone:
		"mik": return Color(0.74, 0.68, 0.51)
		"kka": return Color(0.64, 0.55, 0.75)
		"cuz": return Color(0.50, 0.70, 0.77)
		_: return Color(0.62, 0.70, 0.65)

func _add_stairs(stair_name: String, location: Vector3, yaw: float = 0.0, stair_width: float = 3.0, run: float = 12.0) -> void:
	var stairs = STAIRS_SCENE.instantiate()
	stairs.name = stair_name
	stairs.enclosed = stair_name == "MIK_Stairs"
	stairs.stair_width = stair_width
	stairs.rise = 4.0
	stairs.run = run
	stairs.position = location
	stairs.rotation.y = yaw
	add_child(stairs)

func _add_mik_south_gallery() -> void:
	var gallery := Node3D.new()
	gallery.name = "MIK_SouthAssemblyGallery"
	add_child(gallery)
	# Leave the stair's headroom open until the slope reaches Level 02.
	_add_platform(gallery, Vector3(-19.8, 4.0, 18.06), Vector3(14.4, 0.24, 3.88), MIK_MATERIAL, "SouthWalkWest")
	_add_platform(gallery, Vector3(-4.7, 4.0, 18.06), Vector3(9.4, 0.24, 3.88), MIK_MATERIAL, "SouthWalkEast")
	_add_platform(gallery, Vector3(-11.0, 4.0, 18.5), Vector3(3.2, 0.24, 3.0), MIK_MATERIAL, "StairTopLanding")
	_add_platform(gallery, Vector3(-1.0, 4.0, 0.0), Vector3(2.0, 0.24, 32.24), MIK_MATERIAL, "EastWalk")
	_add_rail(gallery, Vector3(-1.89, 4.55, 0.0), Vector3(0.12, 1.1, 32.0), MIK_MATERIAL, "EastGalleryRail")
	_add_rail(gallery, Vector3(-22.11, 4.55, 0.0), Vector3(0.12, 1.1, 32.0), MIK_MATERIAL, "WestGalleryRail")
	_add_rail(gallery, Vector3(-13.5, 4.55, 19.83), Vector3(27.0, 1.1, 0.12), MIK_MATERIAL, "OuterSouthRail")
	# The guardrail gap lines up with the MIK stair landing.
	_add_rail(gallery, Vector3(-17.4, 4.55, 16.35), Vector3(9.2, 1.1, 0.12), MIK_MATERIAL, "SouthRailLeft")
	_add_rail(gallery, Vector3(-5.7, 4.55, 16.35), Vector3(7.0, 1.1, 0.12), MIK_MATERIAL, "SouthRailRight")

	# The rooms end two metres before the gallery. Close both service returns
	# all the way to the ceiling and separate the lift overhead from Level 02.
	_partition(gallery, "LiftSideReturn", Vector3(-27.05,5.75,19), Vector3(0.24,3.5,2.25))
	_partition(gallery, "PassageNorthEnd", Vector3(-24.5,5.75,-16), Vector3(5.05,3.5,0.24))
	_partition(gallery, "LiftOverheadFront", Vector3(-32,5.74,19.98), Vector3(4.05,3.52,0.24))
	_add_platform(gallery, Vector3(-32,3.96,22.04), Vector3(3.8,0.18,4.1), SERVICE_MATERIAL, "LiftOverheadSlab")
	_partition(gallery, "GallerySouthBulkhead", Vector3(-13.5,5.76,20.08), Vector3(27,3.52,0.22))

func _partition(parent: Node3D, title: String, at: Vector3, size: Vector3) -> void:
	var panel := SpaceVisuals.box(parent,title,size,at,Color.WHITE,true)
	panel.material_override = preload("res://materials/facility_wall.tres")

func _add_cuz_gallery(center_x: float, center_z: float, y: float = 4.0) -> void:
	var gallery := Node3D.new()
	gallery.name = "CUZ_SecondLightGallery" if y > 0.0 else "CUZ_GroundGalleryTrim"
	add_child(gallery)
	if y <= 0.0:
		return
	# Four perimeter walks leave the launch-control hall open to the second light.
	_add_platform(gallery, Vector3(center_x + 0.06, y, center_z - 9.06), Vector3(23.88, 0.24, 1.88), CUZ_MATERIAL, "ControlHallNorthWalk")
	_add_platform(gallery, Vector3(center_x + 0.06, y, center_z + 9.06), Vector3(23.88, 0.24, 1.88), CUZ_MATERIAL, "ControlHallSouthWalk")
	_add_platform(gallery, Vector3(center_x + 11.06, y, center_z), Vector3(1.88, 0.24, 16.24), CUZ_MATERIAL, "ControlHallEastWalk")
	_add_platform(gallery, Vector3(43, y, 0), Vector3(2,0.24,16.24), CUZ_MATERIAL, "WestObservationWalk")
	_add_platform(gallery, Vector3(35,y,4), Vector3(14,0.24,5), CUZ_MATERIAL, "ControlConcourse")
	_add_platform(gallery, Vector3(41.25,y,-0.5), Vector3(1.5,0.24,4), CUZ_MATERIAL, "ControlStairLanding")
	_add_platform(gallery, Vector3(45.4,y,4), Vector3(2.8,0.24,4.6), CUZ_MATERIAL, "ViewingBalcony")
	_add_rail(gallery,Vector3(34.25,y+0.55,1.59),Vector3(12.5,1.1,0.12),CUZ_MATERIAL,"LobbyVoidRail")
	_add_rail(gallery,Vector3(46.7,y+0.55,4),Vector3(0.12,1.1,4.5),CUZ_MATERIAL,"BalconyFront")
	for z in [1.79,6.21]:
		_add_rail(gallery,Vector3(45.35,y+0.55,z),Vector3(2.75,1.1,0.12),CUZ_MATERIAL,"BalconyReturn")
	for span in [Vector2(-8,1.8),Vector2(6.2,8)]:
		_add_rail(gallery,Vector3(43.89,y+0.55,(span.x+span.y)*0.5),Vector3(0.12,1.1,span.y-span.x),CUZ_MATERIAL,"WestInnerRail")
	for z in [-8.33,8.33]:
		_add_rail(gallery,Vector3(center_x,y+0.55,z),Vector3(20,1.1,0.12),CUZ_MATERIAL,"CrossGalleryRail")
	_add_rail(gallery,Vector3(64.33,y+0.55,center_z),Vector3(0.12,1.1,16),CUZ_MATERIAL,"EastInnerRail")
	_partition(gallery,"WestGalleryNorthReturn",Vector3(42,5.75,-6.25),Vector3(0.22,3.5,7.5))
	_partition(gallery,"WestGallerySouthReturn",Vector3(42,5.75,8.25),Vector3(0.22,3.5,3.5))

	for z in [-8.0,8.0]:
		_partition(gallery,"EastGalleryReturn",Vector3(66,5.75,z),Vector3(0.22,3.5,4.0))
	for z in [-10.0,10.0]:
		_partition(gallery,"WestEndReturn",Vector3(43,5.75,z),Vector3(2.2,3.5,0.22))
	_partition(gallery,"SouthEastReturn",Vector3(65,5.75,10),Vector3(2.2,3.5,0.22))

func _add_support_facility(y: float) -> void:
	# ZNS and outdoor gameplay are excluded by the current design brief.
	pass

func _add_platform(parent: Node3D, location: Vector3, dimensions: Vector3, material: Material, node_name: String) -> void:
	var platform = FLOOR_SCENE.instantiate()
	platform.name = node_name
	parent.add_child(platform)
	var finish: Material = preload("res://materials/gallery_deck.tres") if material == MIK_MATERIAL else preload("res://materials/facility_floor.tres")
	platform.configure(dimensions, finish)
	platform.position = Vector3(location.x, location.y - dimensions.y * 0.5, location.z)

func _add_rail(parent: Node3D, location: Vector3, dimensions: Vector3, material: Material, node_name: String) -> void:
	var rail = WALL_SCENE.instantiate()
	rail.name = node_name
	parent.add_child(rail)
	rail.configure(dimensions, material)
	rail.position = location
	rail.get_node("MeshInstance3D").hide()
	var along_x := dimensions.x > dimensions.z
	var run_length := dimensions.x if along_x else dimensions.z
	var dark := Color(0.20, 0.27, 0.28)
	var gold := Color(0.82, 0.58, 0.24)
	SpaceVisuals.box(rail, "TopBar", Vector3(run_length, 0.065, 0.07) if along_x else Vector3(0.07, 0.065, run_length), Vector3(0, 0.5, 0), gold)
	SpaceVisuals.box(rail, "MidBar", Vector3(run_length, 0.045, 0.045) if along_x else Vector3(0.045, 0.045, run_length), Vector3(0, 0, 0), dark)
	SpaceVisuals.box(rail, "ToeBoard", Vector3(run_length,0.12,0.045) if along_x else Vector3(0.045,0.12,run_length),Vector3.DOWN*0.48,dark)
	var posts := maxi(1, ceili(run_length / 2.0))
	for index in range(posts + 1):
		var offset := (run_length - 0.12) * (float(index) / posts - 0.5)
		var foot := Vector3(offset, -0.53, 0) if along_x else Vector3(0, -0.53, offset)
		SpaceVisuals.box(rail,"BasePlate",Vector3(0.16,0.04,0.16),foot,dark)
		SpaceVisuals.box(rail, "Post", Vector3(0.07, 1.1, 0.07), Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset), dark)

func _remove_overlapping_wall_segments() -> void:
	var candidates_by_line: Dictionary = {}
	for candidate in find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if body == null:
			continue
		if not (body.name.contains("Wall") or body.name.contains("Rail")):
			continue
		var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision == null or not (collision.shape is BoxShape3D):
			continue
		var dimensions := (collision.shape as BoxShape3D).size
		if dimensions.y < 1.0 or minf(dimensions.x, dimensions.z) > 0.35:
			continue
		var along_x := dimensions.x > dimensions.z
		var position := body.global_position
		var run_length := dimensions.x if along_x else dimensions.z
		var line_position := position.z if along_x else position.x
		var run_center := position.x if along_x else position.z
		var key := "%s:%d:%d:%d" % ["X" if along_x else "Z", roundi(line_position * 1000.0), roundi(run_center * 1000.0), roundi(run_length * 1000.0)]
		var candidates: Array = candidates_by_line.get(key, [])
		var new_bottom := position.y - dimensions.y * 0.5
		var new_top := position.y + dimensions.y * 0.5
		var keep_body := true
		for existing_candidate in candidates.duplicate():
			var existing := existing_candidate as StaticBody3D
			var existing_collision := existing.get_node("CollisionShape3D") as CollisionShape3D
			var existing_dimensions := (existing_collision.shape as BoxShape3D).size
			var existing_center_y := existing.global_position.y
			var existing_bottom := existing_center_y - existing_dimensions.y * 0.5
			var existing_top := existing_center_y + existing_dimensions.y * 0.5
			if minf(new_top, existing_top) - maxf(new_bottom, existing_bottom) <= 0.02:
				continue
			if dimensions.y > existing_dimensions.y:
				existing.queue_free()
				candidates.erase(existing)
			else:
				body.queue_free()
				keep_body = false
				break
		if keep_body:
			candidates.append(body)
		candidates_by_line[key] = candidates
