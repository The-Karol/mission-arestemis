extends Node3D

const WALL_SCENE := preload("res://scenes/blockout/wall.tscn")
const FLOOR_SCENE := preload("res://scenes/blockout/floor_module.tscn")
const LABEL_SCENE := preload("res://scenes/blockout/room_label.tscn")

@export var room_title := "Room"
@export var room_size := Vector2(8.0, 8.0)
@export var wall_height := 3.4
@export var wall_thickness := 0.24
@export var wall_material: Material
@export var floor_material: Material
@export var open_sides: PackedStringArray = []
@export var wall_openings: Dictionary = {}
@export var wall_disabled_sides: PackedStringArray = []
@export var ceiling_enabled := true
@export var floor_enabled := true
@export var zone_color := Color(0.66, 0.72, 0.7)

func _ready() -> void:
	_build_room()

func _build_room() -> void:
	var architecture := get_node_or_null("Architecture")
	if architecture == null:
		architecture = Node3D.new()
		architecture.name = "Architecture"
		add_child(architecture)
	_ensure_anchor("DoorsAnchor")
	_ensure_anchor("PropsAnchor")
	var sign_anchor := _ensure_anchor("SignAnchor")
	sign_anchor.position = Vector3(0, minf(wall_height - 0.35, 2.6), -room_size.y * 0.5 + 0.35)
	var title_upper := room_title.to_upper()
	if title_upper.contains("OFFICE") or title_upper.contains("ENGINEERING") or title_upper.contains("PLANNING") or title_upper.contains("DATA ANALYSIS") or title_upper.contains("OPERATIONS"):
		_ensure_anchor("DeskAnchor")
		_ensure_anchor("PCAnchor")
	if title_upper.contains("OFFICE") or title_upper.contains("BRIEFING") or title_upper.contains("OPERATIONS"):
		_ensure_anchor("NPCAnchor")
	if title_upper.contains("SERVER"):
		_ensure_anchor("ServerRackAnchor")
	if title_upper.contains("LAB") or title_upper.contains("TEST") or title_upper.contains("CLEAN ROOM"):
		_ensure_anchor("LabEquipmentAnchor")
	if title_upper.contains("SPACECRAFT") or title_upper.contains("VEHICLE"):
		_ensure_anchor("SpacecraftAnchor")
	if title_upper.contains("ASSEMBLY HALL"):
		_ensure_anchor("RocketAssemblyAnchor")
		_ensure_anchor("RocketAnchor")
		_ensure_anchor("CraneAnchor")
		_ensure_anchor("TerminalAnchor")
	if title_upper.contains("LAUNCH CONTROL"):
		_ensure_anchor("LaunchConsoleAnchor")
	if floor_enabled:
		var floor := FLOOR_SCENE.instantiate()
		floor.name = "Floor"
		architecture.add_child(floor)
		floor.configure(Vector3(room_size.x, 0.22, room_size.y), preload("res://materials/facility_floor.tres"))
		floor.position.y = -0.11
	var half_x := room_size.x * 0.5
	var half_z := room_size.y * 0.5
	if not wall_disabled_sides.has("north"):
		_add_wall_run(architecture, "North", Vector3(0, wall_height * 0.5, -half_z), room_size.x, "north")
	if not wall_disabled_sides.has("south"):
		_add_wall_run(architecture, "South", Vector3(0, wall_height * 0.5, half_z), room_size.x, "south")
	if not wall_disabled_sides.has("west"):
		_add_wall_run(architecture, "West", Vector3(-half_x, wall_height * 0.5, 0), room_size.y, "west")
	if not wall_disabled_sides.has("east"):
		_add_wall_run(architecture, "East", Vector3(half_x, wall_height * 0.5, 0), room_size.y, "east")
	if ceiling_enabled:
		var ceiling := FLOOR_SCENE.instantiate()
		ceiling.name = "Ceiling"
		architecture.add_child(ceiling)
		ceiling.configure(Vector3(room_size.x, 0.18, room_size.y), preload("res://materials/facility_ceiling.tres"))
		ceiling.position.y = wall_height
	var label = LABEL_SCENE.instantiate()
	label.name = "RoomLabel"
	add_child(label)
	label.position = Vector3(0, minf(wall_height - 0.4, 2.7), -half_z + 0.55)
	label.set_title(room_title, zone_color.lightened(0.28))

func _add_wall_run(parent: Node3D, side_name: String, center: Vector3, run_length: float, side_key: String) -> void:
	var axis_x := side_key == "north" or side_key == "south"
	var usable_length := maxf(0.1, run_length - wall_thickness)
	var wall_start := -usable_length * 0.5
	var wall_end := usable_length * 0.5
	var opening_width := minf(1.8, run_length * 0.32)
	var opening_centers: Array[float] = []
	if open_sides.has(side_key):
		opening_centers.append(0.0)
	for offset in wall_openings.get(side_key, []):
		opening_centers.append(float(offset))
	opening_centers.sort()
	var cursor := wall_start
	var opening_index := 0
	for opening_center in opening_centers:
		var opening_start := maxf(wall_start, opening_center - opening_width * 0.5)
		var opening_end := minf(wall_end, opening_center + opening_width * 0.5)
		if opening_start > cursor + 0.02:
			_add_wall_segment(parent, side_name, center, axis_x, cursor, opening_start, opening_index)
		opening_index += 1
		cursor = maxf(cursor, opening_end)
		var anchor := get_node_or_null("DoorsAnchor")
		if anchor != null:
			var door_mark := Marker3D.new()
			door_mark.name = "%sDoorAnchor%d" % [side_name, opening_index]
			anchor.add_child(door_mark)
			door_mark.position = center + (Vector3(opening_center, 0, 0) if axis_x else Vector3(0, 0, opening_center))
	if wall_end > cursor + 0.02:
		_add_wall_segment(parent, side_name, center, axis_x, cursor, wall_end, opening_index)

func _add_wall_segment(parent: Node3D, side_name: String, center: Vector3, axis_x: bool, start: float, finish: float, segment_index: int) -> void:
	var wall = WALL_SCENE.instantiate()
	wall.name = "%sWall%d" % [side_name, segment_index]
	parent.add_child(wall)
	var segment_length := finish - start
	var dimensions := Vector3(segment_length, wall_height, wall_thickness) if axis_x else Vector3(wall_thickness, wall_height, segment_length)
	wall.configure(dimensions, preload("res://materials/facility_wall.tres"))
	var offset := (start + finish) * 0.5
	wall.position = center + (Vector3(offset, 0, 0) if axis_x else Vector3(0, 0, offset))

func _ensure_anchor(anchor_name: String) -> Node3D:
	if get_node_or_null(anchor_name) == null:
		var anchor := Node3D.new()
		anchor.name = anchor_name
		add_child(anchor)
	return get_node(anchor_name)

