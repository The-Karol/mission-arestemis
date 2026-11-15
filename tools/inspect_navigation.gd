extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := load("res://scenes/world/world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	for frame in range(5):
		await physics_frame
	var map := world.get_world_3d().navigation_map
	var positions := [Vector3(-32, 0, 16), Vector3(-11, 0, 4), Vector3(-11, 1, 8), Vector3(-11, 3, 14), Vector3(-11, 4, 18), Vector3(-24, 4, 18), Vector3(-24, 4, 0), Vector3(-31.5, 4, 1.8)]
	for index in range(positions.size()):
		var at: Vector3 = positions[index]
		var closest := NavigationServer3D.map_get_closest_point(map, at)
		print("POINT ", index, " ", at, " closest=", closest)
		if index > 0:
			var path := NavigationServer3D.map_get_path(map, positions[index - 1], at, true)
			print("PATH ", index, " points=", path.size(), " end=", path[-1] if path.size() else Vector3.ZERO)
	quit()
