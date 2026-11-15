extends Node3D

var enclosed := false
@export var stair_width := 3.0
@export var rise := 4.0
@export var run := 12.0

func _ready() -> void:
	_build_stairs()

func _build_stairs() -> void:
	var ramp_body := StaticBody3D.new()
	ramp_body.name = "WalkableRamp"
	add_child(ramp_body)
	var ramp_shape := CollisionShape3D.new()
	ramp_shape.name = "RampCollision"
	var wedge := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for side in [-1.0, 1.0]:
		var x: float = side * stair_width * 0.5
		points.append(Vector3(x, -0.2, -0.6))
		points.append(Vector3(x, -0.5, -0.6))
		points.append(Vector3(x, rise, run))
		points.append(Vector3(x, -0.5 if enclosed else rise-0.3, run))
	wedge.points = points
	ramp_shape.shape = wedge
	ramp_body.add_child(ramp_shape)
	if enclosed:
		# Render the very same solid stair carriage used by collision and nav baking.
		var faces := SurfaceTool.new()
		faces.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0,1.0]:
			var x: float = side*stair_width*0.5
			var a := Vector3(x,-0.2,0)
			var b := Vector3(x,-0.2,run)
			var c := Vector3(x,rise-0.10,run)
			for v in ([a,b,c] if side<0 else [a,c,b]):
				faces.add_vertex(v)
		faces.generate_normals()
		var cheek := MeshInstance3D.new()
		cheek.mesh = faces.commit()
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color("455051")
		steel.cull_mode = BaseMaterial3D.CULL_DISABLED
		cheek.material_override = steel
		add_child(cheek)
		SpaceVisuals.box(self,"RearClosure",Vector3(stair_width,rise-0.12,0.10),Vector3(0,(rise-0.12)*0.5,run-0.06),Color("465052"))
	var step_count := maxi(8, ceili(rise / 0.185))
	var step_depth := run / float(step_count)
	for index in range(step_count):
		var fraction := (float(index) + 0.5) / float(step_count)
		var step := MeshInstance3D.new()
		step.name = "VisualStep_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(stair_width, 0.16, step_depth * 0.92)
		step.mesh = mesh
		step.material_override = preload("res://materials/gallery_deck.tres")
		step.position = Vector3(0, fraction * rise - 0.08, fraction * run)
		add_child(step)
		if index % 5 == 0 or index == step_count-1:
			SpaceVisuals.box(step,"TreadNosing",Vector3(stair_width-0.12,0.016,0.043),Vector3(0,0.084,-step_depth*0.43),Color("b5985b"))
	for side in [-1.0, 1.0]:
		for post_index in range(0, step_count, 2):
			var tread := (post_index+0.5)/float(step_count)
			var x: float = side*(stair_width*0.5-0.06)
			SpaceVisuals.box(self,"Stanchion",Vector3(0.065,0.87,0.065),Vector3(x,tread*rise+0.425,tread*run),Color("495456"))
		var rail := Node3D.new()
		rail.position = Vector3(side * (stair_width * 0.5 - 0.06), rise * 0.5 + 0.85, run * 0.5)
		rail.rotation.x = -atan2(rise, run)
		add_child(rail)
		SpaceVisuals.box(rail, "Handrail", Vector3(0.07, 0.07, sqrt(run * run + rise * rise)), Vector3.ZERO, Color(0.82, 0.60, 0.25))
		var rail_length := sqrt(run*run+rise*rise)
		SpaceVisuals.box(rail,"KneeRail",Vector3(0.052,0.052,rail_length),Vector3(0,-0.40,0),Color("596362"))
		SpaceVisuals.box(rail,"Stringer",Vector3(0.13,0.18,rail_length-0.70),Vector3(0,-0.85,-0.35),Color("414c4e"))
		var guard := StaticBody3D.new()
		rail.add_child(guard)
		var collision := CollisionShape3D.new()
		var guard_shape := BoxShape3D.new()
		guard_shape.size = Vector3(0.10,0.9,rail_length-0.5)
		collision.position.y = -0.45
		collision.shape = guard_shape
		guard.add_child(collision)
	# Named anchors let the visual stair mesh be replaced without changing navigation code.
	var lower := Marker3D.new()
	lower.name = "LowerLandingAnchor"
	add_child(lower)
	var upper := Marker3D.new()
	upper.name = "UpperLandingAnchor"
	upper.position = Vector3(0, rise, run)
	add_child(upper)

