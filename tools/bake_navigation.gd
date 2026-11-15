extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := load("res://scenes/world/world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	mesh.agent_radius = 0.45
	mesh.agent_height = 1.9
	mesh.agent_max_climb = 0.30
	mesh.agent_max_slope = 40
	mesh.region_min_size = 1
	mesh.region_merge_size = 2
	mesh.filter_baking_aabb = AABB(Vector3(-39, -0.5, -24), Vector3(117, 10, 46))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, world)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var error := ResourceSaver.save(mesh, "res://data/facility_navigation.tres")
	print("NAVIGATION_BAKE polygons=", mesh.get_polygon_count(), " save=", error)
	quit(error)
