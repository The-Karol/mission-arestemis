extends MeshInstance3D

var player: CharacterBody3D
var timer := 0.0
var last_origin := Vector3.INF
var last_target := Vector3.INF
var projecting := false

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://materials/objective_trail.gdshader")
	material_override = mat

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	visible = player.controls_enabled and GameState.objective_target != Vector3.ZERO
	if not visible or projecting: return
	timer += delta
	if timer < 0.65: return
	timer = 0.0
	var target := GameState.objective_target
	if player.global_position.distance_to(last_origin) < 0.8 and target == last_target: return
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0: return
	last_origin = player.global_position
	last_target = target
	var path := NavigationServer3D.map_get_path(map,player.global_position,target,true)
	# Project short segments onto the actual supporting floor/ramp. The baked
	# navigation mesh has a height offset and must not make the ribbon float.
	var ground_path := PackedVector3Array()
	projecting = true
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	for i in range(1,path.size()):
		var steps := maxi(1,ceili(path[i-1].distance_to(path[i])/0.7))
		for step in range(steps):
			var point := path[i-1].lerp(path[i],float(step)/steps)
			if ground_path.size() > 0 and ground_path.size() % 12 == 0:
				await get_tree().physics_frame
				if GameState.objective_target != target or not visible:
					projecting = false
					last_origin = Vector3.INF
					return
			ray.from = point + Vector3.UP * 0.4
			ray.to = point + Vector3.DOWN * 0.7
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			ground_path.append(hit.position if not hit.is_empty() else point)
	projecting = false
	if path.size() > 0: ground_path.append(path[-1])
	path = ground_path
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distance := 0.0
	for i in range(1,path.size()):
		var a := path[i-1] + Vector3.UP * 0.045
		var b := path[i] + Vector3.UP * 0.045
		var length := a.distance_to(b)
		var side := (b-a).cross(Vector3.UP).normalized()*0.075
		if length < 0.01: continue
		var vertices := [a-side,a+side,b+side,a-side,b+side,b-side]
		var uv := [Vector2(0,distance),Vector2(1,distance),Vector2(1,distance+length),Vector2(0,distance),Vector2(1,distance+length),Vector2(0,distance+length)]
		for v in range(6):
			surface.set_uv(uv[v])
			surface.add_vertex(vertices[v])
		distance += length
	mesh = surface.commit() if distance > 0.0 else null
