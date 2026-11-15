extends Node3D

const FIRST := preload("res://assets/models/rocket/stages/first_stage_body.glb")
const ENGINE := preload("res://assets/models/rocket/engines/merlin_1d.glb")
const INTERSTAGE := preload("res://assets/models/rocket/stages/interstage.glb")
const SECOND := preload("res://assets/models/rocket/stages/second_stage_body.glb")
const FAIRING := preload("res://assets/models/rocket/fairings/fairing_closed.glb")
const COLLIDERS := preload("res://data/assembly_colliders.tres")
const AXIS_HEIGHT := 2.20
const COUPLING_GAP := 0.66
const STEEL := Color("4c585c")
const OCHRE := Color("cb9149")
const MACHINED := Color("a1aca6")
const RUBBER := Color("323c3e")
var cylinders := {}

func _ready() -> void:
	var aft := _section("PropulsionSection")
	var stage := _part(aft,FIRST)
	var engine := _part(aft,ENGINE)
	var socket := engine.find_child("SOCKET_EngineMount",true,false) as Node3D
	var mount := stage.find_child("SOCKET_EngineMount",true,false) as Node3D
	engine.global_position += mount.global_position - socket.global_position
	var next_z := _place(aft,0.0,Vector2(0.72,4.25),Vector2(1.20,1.20),"01  /  PROPULSION")

	var upper := _section("UpperStageSection")
	var adapter := _part(upper,INTERSTAGE)
	var tank := _part(upper,SECOND)
	tank.global_transform = adapter.find_child("SOCKET_Top",true,false).global_transform
	next_z = _place(upper,next_z,Vector2(1.34,3.93),Vector2(1.20,1.20),"02  /  UPPER STAGE")

	var nose := _section("PayloadSection")
	_part(nose,FAIRING)
	# The forward roller pair closes around the tapered part of the fairing.
	_place(nose,next_z,Vector2(0.38,1.63),Vector2(1.20,1.0565),"03  /  PAYLOAD")

func _section(title: String) -> Node3D:
	var section := Node3D.new()
	section.name = title
	add_child(section)
	return section

func _part(parent: Node3D, scene: PackedScene) -> Node3D:
	var part := scene.instantiate() as Node3D
	parent.add_child(part)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = COLLIDERS.get_meta(scene.resource_path.get_file().get_basename())
	body.add_child(collision)
	part.add_child(body)
	return part

func _place(section: Node3D, start_z: float, bearing_stations: Vector2, radii: Vector2, title: String) -> float:
	var bounds := SpaceVisuals.bounds_of(section)
	var axis_origin := start_z - bounds.position.y
	section.rotation.x = PI/2
	section.position = Vector3(0,AXIS_HEIGHT,axis_origin)
	section.set_meta("axial_span",Vector2(start_z,start_z+bounds.size.y))
	_make_carriage(section.name,axis_origin+bearing_stations.x,axis_origin+bearing_stations.y,radii,title)
	return start_z + bounds.size.y + COUPLING_GAP

func _make_carriage(section_name: String, back: float, front: float, radii: Vector2, title: String) -> void:
	var frame := Node3D.new()
	frame.name = section_name + "Carriage"
	add_child(frame)
	frame.position.z = (back+front)*0.5
	var span := front-back
	for side in [-1.0,1.0]:
		SpaceVisuals.box(frame,"ChassisSill",Vector3(0.26,0.20,span+0.52),Vector3(side*0.95,0.41,0),STEEL,true)
		for z in [-span*0.5,span*0.5]:
			var wheel := _cylinder(frame,"RailWheel",0.185,0.18,Vector3(side*0.95,0.245,z),RUBBER)
			wheel.rotation.z = PI/2
			var hub := _cylinder(frame,"WheelHub",0.088,0.20,Vector3(side*0.95,0.245,z),MACHINED)
			hub.rotation.z = PI/2
	for i in 2:
		var z := -span*0.5 if i == 0 else span*0.5
		var radius := radii[i]
		SpaceVisuals.box(frame,"Bolster",Vector3(2.12,0.23,0.41),Vector3(0,0.44,z),OCHRE,true)
		var angle := 0.70
		var roller_radius := 0.155
		var roller_x := sin(angle)*(radius+roller_radius)
		var roller_y := AXIS_HEIGHT-cos(angle)*(radius+roller_radius)
		var crosshead_y := roller_y-0.28
		var ram_bottom := 0.75
		_cylinder(frame,"HydraulicJack",0.24,0.28,Vector3(0,0.63,z),OCHRE)
		_cylinder(frame,"PistonRod",0.14,crosshead_y-ram_bottom,Vector3(0,(crosshead_y+ram_bottom)*0.5,z),MACHINED)
		SpaceVisuals.box(frame,"Crosshead",Vector3(roller_x*2+0.32,0.18,0.37),Vector3(0,crosshead_y,z),STEEL,true)
		for side in [-1.0,1.0]:
			for ear in [-0.22,0.22]:
				SpaceVisuals.box(frame,"BearingCheek",Vector3(0.15,0.32,0.075),Vector3(side*roller_x,roller_y-0.12,z+ear),OCHRE)
			var roller := _cylinder(frame,"LoadRoller",roller_radius,0.37,Vector3(side*roller_x,roller_y,z),RUBBER)
			roller.rotation.x = PI/2
	for side in [-1.0,1.0]:
		var tag := SpaceVisuals.label(frame,title,Vector3(side*1.087,0.42,0),Color("fff0c6"),24)
		tag.rotation.y = side*PI/2
		tag.pixel_size = 0.0031
		tag.outline_size = 0

func _cylinder(parent: Node3D, title: String, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var key := Vector2(radius,height)
	if not cylinders.has(key):
		var shape := CylinderMesh.new()
		shape.radial_segments = 20
		shape.rings = 0
		shape.height = height
		shape.top_radius = radius
		shape.bottom_radius = radius
		cylinders[key] = shape
	var item := MeshInstance3D.new()
	item.name = title
	item.mesh = cylinders[key]
	item.position = at
	item.material_override = SpaceVisuals.material(color)
	parent.add_child(item)
	return item
