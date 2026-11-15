extends Node3D

@onready var left_door: Node3D = $Cabin/LeftDoor
@onready var right_door: Node3D = $Cabin/RightDoor
@onready var player_start: Marker3D = $PlayerStart

func _ready() -> void:
	var cabin := preload("res://assets/models/architecture/elevator_cabin.glb").instantiate() as Node3D
	$Cabin.add_child(cabin)
	var bounds := SpaceVisuals.bounds_of(cabin)
	cabin.scale = Vector3(3.45,2.92,3.45) / bounds.size
	cabin.rotation.y = PI
	cabin.position.y = -0.18
	var mirror := Node3D.new()
	mirror.set_script(preload("res://scripts/gameplay/lift_mirror.gd"))
	add_child(mirror)
	mirror.install(cabin.find_child("MirrorSurface",true,false))
	_close_cabin_front()
	var frame := SpaceVisuals.model($Cabin,"architecture/elevator_frame",Vector3(0,0,-1.68),PI,2.65,false)
	frame.scale.y = 0.90
	var doors := SpaceVisuals.model($Cabin,"architecture/elevator_door",Vector3(0,0,-1.69),0,2.42,false)
	for pair in [["DoorLeft",left_door],["DoorRight",right_door]]:
		var leaf := doors.find_child(pair[0],true,false) as Node3D
		leaf.reparent(pair[1],true)
	SpaceVisuals.box(left_door,"MeetingSeal",Vector3(0.047,2.49,0.032),Vector3(0.82,-0.12,-0.04),Color("333530"))
	for path in ["CabinFloor","LeftWallBody/LeftWall","RightWallBody/RightWall","BackWallBody/BackWall","LeftDoor/DoorMesh","RightDoor/DoorMesh"]:
		$Cabin.get_node(path).hide()
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.45,0)
	light.light_color = Color("ffd5a7")
	light.light_energy = 1.25
	light.omni_range = 4.2
	$Cabin.add_child(light)

func _close_cabin_front() -> void:
	# The supplied cabin has an open face wider than its separate door kit.
	# Returns sit inside the cabin around the sliding leaves so their pockets stay clear.
	var metal := Color("596163")
	for side in [-1.0,1.0]:
		SpaceVisuals.box($Cabin,"JambReturn",Vector3(0.61,2.86,0.18),Vector3(side*1.46,1.33,-1.54),metal,true)
		SpaceVisuals.box($Cabin,"JambReveal",Vector3(0.048,2.66,0.055),Vector3(side*1.16,1.29,-1.427),Color("303739"))
		SpaceVisuals.box($Cabin,"ReturnBelt",Vector3(0.59,0.11,0.018),Vector3(side*1.46,0.93,-1.441),Color("82392b"))
	SpaceVisuals.box($Cabin,"TransomBacking",Vector3(2.43,0.27,0.19),Vector3(0,2.65,-1.54),metal,true)
	SpaceVisuals.box($Cabin,"SteelSill",Vector3(2.45,0.09,0.36),Vector3(0,-0.045,-1.58),Color("697071"),true)
	SpaceVisuals.box($Cabin,"CabinCeilingBacking",Vector3(3.52,0.13,3.5),Vector3(0,2.79,0),metal,true)
	SpaceVisuals.box($Cabin,"CabinFloorBacking",Vector3(3.5,0.1,3.5),Vector3(0,-0.20,0),Color("364043"))

func play_intro(player: CharacterBody3D) -> void:
	player.set_controls_enabled(false)
	player.global_position = player_start.global_position
	player.reset_physics_interpolation()
	player.reparent(self, true)
	await get_tree().create_timer(0.7).timeout
	GameAudio.play_effect("lift",-9)
	var lift_tween := create_tween()
	lift_tween.tween_property(self, "position:y", 0.0, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await lift_tween.finished
	await get_tree().create_timer(0.35).timeout
	GameAudio.play_effect("door")
	var door_tween := create_tween().set_parallel(true)
	door_tween.tween_property(left_door, "position:x", -1.78, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	door_tween.tween_property(right_door, "position:x", 1.78, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await door_tween.finished
	player.reparent(get_tree().current_scene, true)
