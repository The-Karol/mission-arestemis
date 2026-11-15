extends Node3D

const FIRST = preload("res://assets/models/rocket/stages/first_stage_body.glb")
const SECOND = preload("res://assets/models/rocket/stages/second_stage_body.glb")
const INTERSTAGE = preload("res://assets/models/rocket/stages/interstage.glb")
const FAIRING = preload("res://assets/models/rocket/fairings/fairing_closed.glb")
const ENGINE = preload("res://assets/models/rocket/engines/merlin_1d.glb")
const BOOSTER = preload("res://assets/models/rocket/stages/booster_medium.glb")

var pivot: Node3D
var clock := 0.0
var camera: Camera3D

func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "AssembledRocket"
	pivot.position = Vector3(5.3, -0.6, 0)
	pivot.rotation = Vector3(0.10, -0.28, 0.94)
	add_child(pivot)
	var assembly := Node3D.new()
	assembly.position.y = -5.4
	pivot.add_child(assembly)
	var stage := FIRST.instantiate() as Node3D
	assembly.add_child(stage)
	var interstage := _attach(INTERSTAGE, assembly, stage.find_child("SOCKET_Top", true, false))
	var upper := _attach(SECOND, assembly, interstage.find_child("SOCKET_Top", true, false))
	_attach(FAIRING, assembly, upper.find_child("SOCKET_Top", true, false))
	var band := MeshInstance3D.new()
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 1.205
	sleeve.bottom_radius = 1.205
	sleeve.height = 0.20
	sleeve.cap_top = false
	sleeve.cap_bottom = false
	band.mesh = sleeve
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.65,0.12,0.07)
	red.roughness = 0.55
	band.material_override = red
	band.position.y = 9.9
	assembly.add_child(band)
	for offset in [Vector3(-0.6, 0, 0.1), Vector3(0.6, 0, 0.1), Vector3(0, 0, -0.55)]:
		var engine := ENGINE.instantiate() as Node3D
		assembly.add_child(engine)
		engine.scale *= 0.65
		var mount := engine.find_child("SOCKET_EngineMount", true, false) as Node3D
		engine.position = offset - assembly.to_local(mount.global_position)
		_plume(assembly, offset + Vector3(0, -1.4, 0))
	for side in ["SOCKET_BoosterLeft", "SOCKET_BoosterRight"]:
		var booster := BOOSTER.instantiate() as Node3D
		assembly.add_child(booster)
		var socket := stage.find_child(side, true, false) as Node3D
		var mount := booster.find_child("SOCKET_Attach", true, false) as Node3D
		booster.global_transform = socket.global_transform * (assembly.global_transform.affine_inverse() * mount.global_transform).affine_inverse()
	for mesh in assembly.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera = Camera3D.new()
	camera.position = Vector3(0,0,26)
	camera.fov = 40
	add_child(camera)
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.48,0.56,0.75)
	environment.environment.ambient_light_energy = 0.45
	add_child(environment)
	for entry in [[Vector3(-0.4,-0.7,0),Color(1,0.86,0.68),1.8], [Vector3(0.6,2.5,0.4),Color(0.47,0.65,1),1.0], [Vector3(-0.5,-2,0),Color(1,0.35,0.13),0.7]]:
		var light := DirectionalLight3D.new()
		light.rotation = entry[0]
		light.light_color = entry[1]
		light.light_energy = entry[2]
		camera.add_child(light)

func _attach(scene: PackedScene, assembly: Node3D, socket: Node3D) -> Node3D:
	var instance := scene.instantiate() as Node3D
	assembly.add_child(instance)
	instance.global_transform = socket.global_transform
	return instance

func _plume(assembly: Node3D, at: Vector3) -> void:
	for core in [false,true]:
		var surface := CylinderMesh.new()
		surface.height = 1
		surface.top_radius = 1
		surface.bottom_radius = 1
		surface.radial_segments = 24
		surface.rings = 40
		surface.cap_top = false
		surface.cap_bottom = false
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface
		mesh.position = at
		mesh.custom_aabb = AABB(Vector3(-1.5,-10.5,-1.5),Vector3(3,10.6,3))
		var gas := ShaderMaterial.new()
		gas.shader = preload("res://materials/engine_plume.gdshader")
		gas.set_shader_parameter("core",1.0 if core else 0.0)
		gas.set_shader_parameter("phase",at.x*3.0)
		mesh.material_override = gas
		assembly.add_child(mesh)

func _process(delta: float) -> void:
	clock += delta
	# Continuous flight: distant approach, close pass, chase, then hero framing.
	# The vehicle keeps its heading; the camera performs the final orbit.
	var rocket_at := Vector3(-6.5,-1.0,-100.0+minf(clock,12.0)*32.0)
	var flight_basis := Basis.from_euler(Vector3(PI/2,0,0))
	var roll := TAU*smoothstep(3.3,7.9,clock)
	pivot.transform = Transform3D(flight_basis*Basis(Vector3.UP,roll),rocket_at)
	if clock < 2.8:
		camera.position = Vector3.ZERO
		camera.look_at(rocket_at)
		camera.fov = lerpf(48.0,55.0,smoothstep(1.8,2.8,clock))
	elif clock < 4.5:
		var chase := smoothstep(2.8,4.5,clock)
		camera.position = Vector3.ZERO.lerp(rocket_at+Vector3(8,2,-24),chase)
		camera.look_at(rocket_at)
		camera.fov = lerpf(55.0,44.0,chase)
	else:
		var settle := smoothstep(4.5,8.5,clock)
		var chase_pose := Transform3D(Basis.IDENTITY,rocket_at+Vector3(8,2,-24)).looking_at(rocket_at)
		var hero_rotation := Basis.from_euler(Vector3(0.10,-0.28,0.94))
		var hero_basis := flight_basis * hero_rotation.inverse()
		var bob := (sin((clock-8.5)*0.84)*0.41+sin((clock-8.5)*1.68)*0.045)*settle
		# Orbit about the vehicle centre. Interpolating two camera positions cuts a chord
		# through the orbit and throws the vehicle towards the top of the frame.
		var attitude := chase_pose.basis.slerp(hero_basis,settle).orthonormalized()
		var distance := lerpf(chase_pose.origin.distance_to(rocket_at),29.5,settle)
		var framing := Vector3(4.65*settle,(-0.22+bob)*settle,-distance)
		camera.transform = Transform3D(attitude,rocket_at-attitude*framing)
		camera.fov = lerpf(44.0,40.0,settle)

func skip_intro() -> void:
	clock = maxf(clock,8.5)
	_process(0.0)
