extends Node3D

const LEAF_WIDTH := 1.00
const HEIGHT := 2.49
var left := AnimatableBody3D.new()
var right := AnimatableBody3D.new()
var occupants := 0
var progress := 0.0

func _ready() -> void:
	set_meta("door_bounds",AABB(Vector3(-2.05,0,-0.3),Vector3(4.10,2.62,0.6)))
	var frame := SpaceVisuals.model(self,"architecture/door_frame",Vector3.ZERO,0,2.12,false)
	frame.scale.y = 2.59 / (frame.get_meta("model_bounds") as AABB).size.y
	var kit := SpaceVisuals.model(self,"architecture/double_door",Vector3.ZERO,0,0,false)
	_fit_leaf(kit,left,"DoorLeft",-1)
	_fit_leaf(kit,right,"DoorRight",1)
	kit.queue_free()
	var dark := Color("434b4c")
	for side in [-1,1]:
		SpaceVisuals.box(self,"PocketLiner",Vector3(0.16,2.55,0.28),Vector3(side*0.978,1.275,0),dark)
	SpaceVisuals.box(self,"HeaderLiner",Vector3(2.09,0.18,0.28),Vector3(0,2.51,0),dark)
	var sensor:=Area3D.new()
	sensor.collision_layer=0
	sensor.collision_mask=2
	sensor.monitorable=false
	add_child(sensor)
	SpaceVisuals.interaction_shape(sensor,Vector3(3.3,2.55,5.6),Vector3.UP*1.28)
	sensor.body_entered.connect(func(actor):
		occupants+=1
		if progress==0 and actor.is_in_group("player"): GameAudio.play_effect("door",-18)
		set_physics_process(true))
	sensor.body_exited.connect(func(_actor):
		occupants=maxi(occupants-1,0)
		set_physics_process(true))
	set_physics_process(false)

func _fit_leaf(kit: Node3D, carrier: AnimatableBody3D, node_name: String, side: int) -> void:
	var leaf:=kit.find_child(node_name,true,false) as Node3D
	carrier.sync_to_physics=false
	carrier.collision_layer=8
	carrier.collision_mask=0
	add_child(carrier)
	leaf.reparent(carrier,true)
	var bounds:=SpaceVisuals.bounds_of(carrier)
	leaf.scale*=Vector3(LEAF_WIDTH/bounds.size.x,HEIGHT/bounds.size.y,1)
	bounds=SpaceVisuals.bounds_of(carrier)
	leaf.position+=Vector3(side*0.48-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)
	# The solid door skin overlaps both the centre seal and the frame rebate.
	var skin:=MeshInstance3D.new()
	var plate:=BoxMesh.new()
	plate.size=Vector3(LEAF_WIDTH+0.02,HEIGHT,0.058)
	plate.material=SpaceVisuals.material(Color("4c5554"))
	skin.mesh=plate
	skin.position=Vector3(side*0.48,HEIGHT*0.5,0)
	carrier.add_child(skin)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(LEAF_WIDTH+0.02,HEIGHT,0.09)
	collision.shape=shape
	collision.position=skin.position
	carrier.add_child(collision)

func _physics_process(delta: float) -> void:
	var goal:=1.0 if occupants>0 else 0.0
	progress=move_toward(progress,goal,delta*2.4)
	var travel:=smoothstep(0,1,progress)*1.03
	left.position.x=-travel
	right.position.x=travel
	if progress==goal:set_physics_process(false)
