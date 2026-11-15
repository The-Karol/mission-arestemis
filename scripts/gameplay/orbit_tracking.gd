extends Node3D
## A short powered-ascent arc, not a completed orbit. Camera and Earth stay fixed.
const RADIUS := 10.0
const ARC_START := .15
const ARC_SWEEP := .58
const SAMPLES := 96
var vehicle:Node3D
var marker:MeshInstance3D
var trail:MultiMeshInstance3D
var labels:Array[Label3D]=[]
var plane:=Basis.from_euler(Vector3(.38,0,.52))
var track:PackedVector3Array
var mission:Dictionary
var camera:Camera3D
var vehicle_label:Label3D

func _ready() -> void:
	var earth:=SpaceVisuals.model(self,"celestial/earth",Vector3(0,-RADIUS,0),-.4,2*RADIUS,false)
	earth.name="TrackingEarth"
	for mesh in earth.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Only the upcoming portion is shown. No closed orbit before insertion.
	for i in SAMPLES+1:track.append(ascent(float(i)/SAMPLES))
	var planned:=_segments(SAMPLES,Color("e5b876"),.04)
	for i in SAMPLES:
		var u:=float(i)/SAMPLES
		var v:=float(i+1)/SAMPLES
		var a:=continuation(u)
		var b:=continuation(v)
		if i%6<3:_segment(planned.multimesh,i,a,b)
		else:planned.multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),Vector3.ZERO))
	trail=_segments(SAMPLES,Color("60dce7"),.055)
	trail.multimesh.visible_instance_count=0
	vehicle=Node3D.new()
	add_child(vehicle)
	SpaceVisuals.model(vehicle,"rocket/stages/second_stage_body",Vector3.ZERO,0,.22,false)
	SpaceVisuals.model(vehicle,"rocket/fairings/fairing_closed",Vector3(0,.75,0),0,.27,false)
	marker=MeshInstance3D.new()
	var sphere:=SphereMesh.new()
	sphere.radius=.17
	sphere.height=.34
	marker.mesh=sphere
	marker.material_override=SpaceVisuals.material(Color("b4f9ff"),true)
	vehicle.add_child(marker)
	vehicle_label=SpaceVisuals.label(self,"VEHICLE",Vector3.ZERO,Color("b4f9ff"),26)
	vehicle_label.pixel_size=.022
	vehicle_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_label("EARTH",Vector3(0,-12,0),Color("a3b9c7"))
	_label("PLANNED INSERTION",continuation(.85)+Vector3.UP*1.2,Color("e5b772"))
	_label("LIFT-OFF",ascent(0)+Vector3(0,-1.1,0),Color("6dd2e4"))
	var target:=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=.3
	ring.outer_radius=.38
	ring.rings=24
	ring.ring_segments=8
	target.mesh=ring
	target.material_override=SpaceVisuals.material(Color("e9b96c"),true)
	add_child(target)
	target.position=ascent(1)
	_label("STAGING NEXT",ascent(1)+Vector3.UP*1.4,Color("e9b96c"))
	target.basis=plane

func ascent(progress:float) -> Vector3:
	var angle:=ARC_START+ARC_SWEEP*progress
	var altitude:=.08+2.1*smoothstep(0,1,progress)
	return plane*Vector3(cos(angle),0,sin(angle))*(RADIUS+altitude)

func continuation(progress:float) -> Vector3:
	var angle:=ARC_START+ARC_SWEEP+.65*progress
	return plane*Vector3(cos(angle),0,sin(angle))*(RADIUS+2.18+1.1*progress)

func _segments(count:int,color:Color,width:float) -> MultiMeshInstance3D:
	var instance:=MultiMeshInstance3D.new()
	var tube:=CylinderMesh.new()
	tube.top_radius=width
	tube.bottom_radius=width
	tube.height=1
	tube.radial_segments=6
	instance.multimesh=MultiMesh.new()
	instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	instance.multimesh.mesh=tube
	instance.multimesh.instance_count=count
	instance.material_override=SpaceVisuals.material(color,true)
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _segment(mesh:MultiMesh,index:int,a:Vector3,b:Vector3) -> void:
	var direction:=(b-a).normalized()
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()<.01:right=Vector3.RIGHT
	var basis:=Basis(right,direction,right.cross(direction)).scaled(Vector3(1,a.distance_to(b),1))
	mesh.set_instance_transform(index,Transform3D(basis,(a+b)*.5))

func _label(text:String,at:Vector3,color:Color) -> void:
	var label:=SpaceVisuals.label(self,text,at,color,24)
	label.pixel_size=.026
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test=false
	labels.append(label)

func update_track(progress:float) -> void:
	var end:=clampi(ceili(progress*SAMPLES),1,SAMPLES)
	for i in end:
		_segment(trail.multimesh,i,track[i],ascent(minf(float(i+1)/SAMPLES,progress)))
	trail.multimesh.visible_instance_count=end
	vehicle.position=ascent(progress)
	vehicle_label.position=vehicle.position+Vector3.UP*.8
	var forward:=(ascent(progress+.002)-ascent(progress)).normalized()
	var right:=forward.cross(Vector3.UP).normalized()
	vehicle.basis=Basis(right,forward,right.cross(forward))
	# A fixed inertial overview prevents camera travel from implying a revolution.
	camera.position=Vector3(34,23,36)
	camera.fov=40
	camera.look_at(Vector3(2,1,0))
