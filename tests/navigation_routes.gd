extends Node

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var world := load("res://scenes/world/world.tscn").instantiate() as Node3D
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var guide: CharacterBody3D = world.engineer
	var actor: CharacterBody3D = world.player
	for frame in range(180):
		await get_tree().physics_frame
	var nav_map: RID = guide.agent.get_navigation_map()
	for point in [Vector3(43,4,4),Vector3(43,4,9),Vector3(54,4,9),Vector3(65.1,4,9),Vector3(65.1,4,0),Vector3(65.1,4,-9),Vector3(54,4,-9)]:
		print("CUZ_POINT ", point, " nearest=", NavigationServer3D.map_get_closest_point(nav_map, point))
	guide.active = true
	guide._introduced = true
	guide._arrival_dialogue = true
	guide.global_position = Vector3(-31, 4.05, 2)
	actor.set_controls_enabled(true)
	var failures := 0
	var routes := [
		["Upper Project Office to KKA lab", Vector3(9, 4, 7)],
		["KKA stairs down to preparation", Vector3(7, 0, 1.5)],
		["KKA stairs up to laboratory", Vector3(7, 4, 1.5)],
		["Upper passage to CUZ operations", Vector3(69, 4, 0)],
		["CUZ stairs down to launch control", Vector3(57, 0, 4)],
		["CUZ stairs up to data analysis", Vector3(37, 4, -5)],
		["Return to MIK Project Office", Vector3(-31, 4, 2)]
	]
	for route in routes:
		guide.destination = route[1]
		guide.state = "guiding"
		guide.agent.target_position = route[1]
		for frame in range(12000):
			actor.global_position = guide.global_position + Vector3(0.8, 0.05, 0.8)
			actor.velocity = Vector3.ZERO
			await get_tree().physics_frame
			if guide.state == "at_office":
				break
		var success: bool = guide.global_position.distance_to(route[1]) < 0.9
		print("ROUTE ", "PASS " if success else "FAIL ", route[0], " end=", guide.global_position)
		if not success:
			failures += 1
			print("PATH ", guide.agent.get_current_navigation_path())
			# Isolate the next route after reporting this failure.
			guide.global_position = route[1] + Vector3.UP * 0.1
	print("NAVIGATION_ROUTES_RESULT ", routes.size() - failures, "/", routes.size())
	get_tree().quit(1 if failures else 0)
