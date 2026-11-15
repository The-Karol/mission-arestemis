extends SkeletonModifier3D

var role := "engineer"
var stride := 0.0
var phase := 0.0
var speaking := false
var clock := 0.0
var board: Node3D
var bones := {}
var face: MeshInstance3D
var mouth := -1
var smile := -1

func _ready() -> void:
	var sk := get_skeleton()
	for i in sk.get_bone_count():
		bones[sk.get_bone_name(i).replace("_",".")] = i
	if role != "engineer": return
	for mesh in sk.get_parent().find_children("*","MeshInstance3D",true,false):
		var index: int = mesh.find_blend_shape_by_name("MouthClosed")
		if index >= 0:
			face = mesh
			mouth = index
			smile = mesh.find_blend_shape_by_name("OriginalToothSmile")
			break
	# Drive the prop from the final modified wrist pose, not a stale attachment.
	board = SpaceVisuals.model(sk,"props/engineering_clipboard",Vector3.ZERO,0,0.235/sk.global_basis.get_scale().x,false)
	sk.skeleton_updated.connect(_align_clipboard)

func _align_clipboard() -> void:
	if not is_instance_valid(board):return
	var sk:=get_skeleton()
	var hand_index:int=bones.get("Hand.L",-1)
	var forearm_index:int=bones.get("Forearm.L",-1)
	if hand_index<0 or forearm_index<0:return
	var hand:Transform3D=sk.global_transform*sk.get_bone_global_pose(hand_index)
	var elbow:Vector3=(sk.global_transform*sk.get_bone_global_pose(forearm_index)).origin
	var palm:=hand.origin+(hand.origin-elbow).normalized()*0.035
	var frame:=sk.global_basis.orthonormalized()
	var tilt:=deg_to_rad(-68+_reading()*43)
	var prop_basis:=frame*Basis(Vector3.RIGHT,tilt)*Basis(Vector3.UP,PI-0.06)*Basis.from_scale(sk.global_basis.get_scale())
	var bounds:AABB=board.get_meta("model_bounds")
	# Thumb closes over the near outside edge; the board extends across the palm.
	var grip:=Vector3(bounds.position.x+0.025/sk.global_basis.get_scale().x,bounds.end.y,bounds.position.z+bounds.size.z*0.22)
	board.global_transform=Transform3D(prop_basis,palm-prop_basis*grip)
	board.set_meta("grip_local",grip)
	board.set_meta("palm_world",palm)

func _reading() -> float:
	var time := fmod(clock+1.4,8.8)
	return smoothstep(0.1,0.85,time)*(1.0-smoothstep(2.1,3.0,time))*(1.0-stride)*(0.12 if speaking else 1.0)

func _process(delta: float) -> void:
	clock += delta
	if face:
		var opening := (0.5+0.5*sin(clock*14.0))*0.62 if speaking else 0.06+0.08*sin(clock*0.72)
		face.set_blend_shape_value(mouth,clampf(1.0-opening,0,1))
		if smile >= 0: face.set_blend_shape_value(smile,0.0)

func _aim(name_a: String, child: String, desired: Vector3, amount: float) -> void:
	var sk := get_skeleton()
	var i: int = bones.get(name_a,-1)
	var j: int = bones.get(child,-1)
	if i < 0 or j < 0: return
	var at := sk.get_bone_global_pose(i)
	var current := (sk.get_bone_global_pose(j).origin-at.origin).normalized()
	var axis := current.cross(desired)
	if axis.length_squared() < 0.000001: return
	var rotation := Quaternion(axis.normalized(),current.angle_to(desired)*amount)
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis.orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(i,(parent.inverse()*rotation*parent*sk.get_bone_pose_rotation(i)).normalized())

func _process_modification() -> void:
	var sk := get_skeleton()
	var sway := sin(phase)
	var breath := sin(clock*1.7)
	var read := _reading()
	if role == "engineer":
		_aim("UpperArm.L","Forearm.L",Vector3(0.12,-0.90,0.37),0.94)
		_aim("Forearm.L","Hand.L",Vector3(-0.42,0.39+read*0.28,0.78),0.97)
		_aim("UpperArm.R","Forearm.R",Vector3(-0.20,-1,sway*stride*0.62),0.79)
		_aim("Forearm.R","Hand.R",Vector3(0.06,-0.96,0.25+sway*stride*0.52),0.75)
	elif role == "pilot":
		for side in ["L","R"]:
			var sign_x := 1.0 if side == "L" else -1.0
			_aim("UpperArm."+side,"Forearm."+side,Vector3(sign_x*0.19,-0.95,0.26+sway*sign_x*stride*0.74),0.82)
			_aim("Forearm."+side,"Hand."+side,Vector3(-sign_x*0.14,-0.77,0.72+sway*sign_x*stride*0.64),0.89)
		return
	else:
		var reach := 0.56 if role == "technician" else 0.23
		_aim("UpperArm.L","Forearm.L",Vector3(0.23,-0.93,reach*0.55),1)
		_aim("UpperArm.R","Forearm.R",Vector3(-0.25,-0.96,0.28),1)
		_aim("Forearm.L","Hand.L",Vector3(-0.16,-0.82,reach+breath*0.05),1)
		_aim("Forearm.R","Hand.R",Vector3(0.12,-0.96,0.17+breath*0.06),1)
	var head_id: int = bones.get("Head",-1)
	if head_id >= 0:
		var tilt := 0.31*read+breath*0.011
		if role != "engineer": tilt = 0.10+0.08*sin(clock*0.64)
		sk.set_bone_pose_rotation(head_id,sk.get_bone_pose_rotation(head_id)*Quaternion(Vector3.RIGHT,tilt)*Quaternion(Vector3.UP,0.11*read+0.035*sin(clock*0.7)))

func frame_up() -> Vector3:
	return get_skeleton().global_basis.orthonormalized().y
