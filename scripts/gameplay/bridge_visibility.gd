extends Node

# The two buildings communicate only through these two straight, enclosed
# passages. A view of the far building must intersect both ends of one passage.
const WEST_END := 14.0
const EAST_END := 28.0
const Z_LIMITS := Vector2(1.2,6.8)
const LEVELS := [Vector2(-0.25,3.5),Vector2(3.7,7.5)]
var west_rooms: Array[Node3D] = []
var east_rooms: Array[Node3D] = []
var previous_eye := Vector3.INF
var west_visible := true
var east_visible := true

func configure(floors: Array) -> void:
	for floor_node: Node3D in floors:
		for room in floor_node.get_children():
			var furnishings := room.get_node_or_null("PropsAnchor") as Node3D
			if not furnishings: continue
			if room.position.x < WEST_END: west_rooms.append(furnishings)
			elif room.position.x > EAST_END: east_rooms.append(furnishings)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera: return
	var eye := camera.global_position
	if eye.distance_squared_to(previous_eye) < 0.01: return
	previous_eye = eye
	var show_west := eye.x <= EAST_END + 0.5 or _can_see_through(eye,EAST_END,WEST_END)
	var show_east := eye.x >= WEST_END - 0.5 or _can_see_through(eye,WEST_END,EAST_END)
	if show_west != west_visible:
		west_visible = show_west
		for room in west_rooms: room.visible = show_west
	if show_east != east_visible:
		east_visible = show_east
		for room in east_rooms: room.visible = show_east

func _can_see_through(eye: Vector3, near_end: float, far_end: float) -> bool:
	var ratio := (far_end-eye.x)/(near_end-eye.x)
	if not _overlaps_aperture(eye.z,ratio,Z_LIMITS): return false
	for opening: Vector2 in LEVELS:
		if _overlaps_aperture(eye.y,ratio,opening): return true
	return false

func _overlaps_aperture(eye: float, ratio: float, interval: Vector2) -> bool:
	var low := eye + (interval.x-eye)*ratio
	var high := eye + (interval.y-eye)*ratio
	return low <= interval.y and high >= interval.x
