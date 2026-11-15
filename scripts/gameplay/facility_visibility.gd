extends Node

# Only static render nodes are masked. Physics, automatic doors and quest
# triggers stay active. Bounds keys also keep new furnishings visible until baked.
const MAP := "res://data/facility_visibility.json"
const CELL := Vector3(3,2,3)
var groups := {}
var ordered: Array = []
var cells := {}
var last_cell := Vector3i(9999,9999,9999)
var previous := PackedByteArray()

func configure(world: Node3D) -> void:
	for path in ["Floor01","Floor02","StaticVisualBatches"]:
		_collect(world.get_node(path),path=="StaticVisualBatches")
	for crew in world.get_node("FacilityDressing").get_children():
		if crew is SpaceInteractable and crew.highlight_root:
			var actor: Node3D=crew.highlight_root
			actor.set_meta("station_animation",true)
			_register(actor,AABB(crew.global_position-Vector3(1,0,1),Vector3(2,2.4,2)))
	if OS.get_cmdline_user_args().has("--bake-nav"):
		_write_source(world)
		set_process(false)
		return
	if not FileAccess.file_exists(MAP):return
	var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MAP))
	cells=info.cells
	for key in info.keys_ordered: ordered.append(groups.get(key,[]))

func _collect(node: Node, batches: bool) -> void:
	if node.is_queued_for_deletion(): return
	var box: AABB
	if node.has_meta("door_bounds"):
		box=node.global_transform*node.get_meta("door_bounds")
	elif node.has_meta("asset_path") or node.name=="IntegrationLine":
		box=node.global_transform*SpaceVisuals.bounds_of(node)
	elif batches and node is MeshInstance3D:
		box=node.global_transform*node.get_aabb()
	else:
		for child in node.get_children(): _collect(child,batches)
		return
	_register(node,box)

func _register(node:Node3D, box:AABB) -> void:
	var lo:=Vector3i((box.grow(0.45).position/2.0).floor())
	var hi:=Vector3i((box.grow(0.45).end/2.0).ceil())
	var key:="%d,%d,%d,%d,%d,%d"%[lo.x,lo.y,lo.z,hi.x,hi.y,hi.z]
	if not groups.has(key):groups[key]=[]
	groups[key].append(node)

func _write_source(world: Node3D) -> void:
	var walls: Array=[]
	for floor_name in ["Floor01","Floor02"]:
		for room in world.get_node(floor_name).get_children():
			var arch:=room.get_node_or_null("Architecture")
			if not arch:continue
			for body in arch.get_children():
				if body.is_queued_for_deletion():continue
				var collider:=body.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if not collider or not collider.shape is BoxShape3D:continue
				var dim: Vector3=collider.shape.size
				var box: AABB=collider.global_transform*AABB(-dim*0.5,dim)
				walls.append([box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z])
	var file:=FileAccess.open("res://build/visibility_geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"targets":groups.keys(),"walls":walls}))

func _process(_delta:float) -> void:
	if cells.is_empty():return
	var cam:=get_viewport().get_camera_3d()
	if not cam:return
	var eye:=cam.global_position
	var cell:=Vector3i((eye/CELL).floor())
	# The mirror uses a second viewpoint near the arrival lift.
	if eye.distance_squared_to(Vector3(-32,1.6,22))<50:cell=Vector3i(9998,0,0)
	if cell==last_cell:return
	last_cell=cell
	var packed:String=cells.get("%d,%d,%d"%[cell.x,cell.y,cell.z],"")
	var mask:=Marshalls.base64_to_raw(packed) if not packed.is_empty() else PackedByteArray()
	for block in ceili(ordered.size()/8.0):
		var old:=int(previous[block]) if block<previous.size() else 0
		var now:=int(mask[block]) if block<mask.size() else 0
		var changes:=old^now
		if not changes:continue
		for bit in 8:
			var i:=block*8+bit
			if i>=ordered.size() or not (changes&(1<<bit)):continue
			for visual:Node3D in ordered[i]:
				visual.visible=not (now&(1<<bit))
				if visual.has_meta("station_animation"):
					visual.process_mode=Node.PROCESS_MODE_INHERIT if visual.visible else Node.PROCESS_MODE_DISABLED
	previous=mask
