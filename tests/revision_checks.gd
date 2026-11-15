extends Node

var failures := 0
func check(value: bool, label_text: String) -> void:
	print("PASS " if value else "FAIL ", label_text)
	if not value: failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var menu := preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	check(menu.find_children("*Exit*","",true,false).is_empty(),"Menu has no Exit control")
	check(menu.get_node("RocketView/RocketViewport").get_child_count() == 1,"Menu uses an actual 3D rocket viewport")
	menu.queue_free()
	await get_tree().process_frame
	var world := preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var actor: CharacterBody3D = world.player
	actor.set_controls_enabled(true)
	actor._look_guard_frames = 0
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(2000,2000)
	event.screen_relative = Vector2(10,5)
	actor._queue_mouse_motion(event)
	actor._apply_pending_mouse_look()
	check(is_equal_approx(actor.head.rotation.y,-10*SettingsStore.mouse_sensitivity) and is_equal_approx(actor._pitch,-5*SettingsStore.mouse_sensitivity),"Camera uses unscaled raw motion")
	var before := Vector2(actor.head.rotation.y,actor._pitch)
	event.screen_relative = Vector2(15000,-10000)
	actor._queue_mouse_motion(event)
	actor._apply_pending_mouse_look()
	check(before.is_equal_approx(Vector2(actor.head.rotation.y,actor._pitch)),"Pointer warp cannot spin camera")
	actor._apply_pending_mouse_look()
	check(before.is_equal_approx(Vector2(actor.head.rotation.y,actor._pitch)),"Camera stops immediately with no retained motion")
	actor._reset_mouse_motion()
	event.screen_relative = Vector2(100,100)
	actor._queue_mouse_motion(event)
	actor._apply_pending_mouse_look()
	check(before.is_equal_approx(Vector2(actor.head.rotation.y,actor._pitch)),"Pointer capture transition ignores synthetic motion")
	actor.set_controls_enabled(false)
	for frame in range(120): await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var blocked := true
	for pair in [
		[Vector3(-24.5,5.6,-15),Vector3(-24.5,5.6,-25)],
		[Vector3(-35,1.6,0),Vector3(-42,1.6,0)],
		[Vector3(7,5.6,12),Vector3(7,5.6,22)],
		[Vector3(22,5.6,4),Vector3(22,5.6,12)],
		[Vector3(75,5.6,0),Vector3(82,5.6,0)],
		[Vector3(54,5.6,20),Vector3(54,5.6,28)],
		[Vector3(-11,12,-5),Vector3(-11,17,-5)],
		[Vector3(10,6,5),Vector3(10,10,5)],
		[Vector3(54,6,0),Vector3(54,10,0)]]:
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(pair[0],pair[1],1))
		if hit.is_empty():
			blocked = false
			print("OPEN BOUNDARY ",pair)
	check(blocked,"Exterior escape directions and roofs have physical collision")
	# This revision covers camera, menu and exterior collision. The existing
	# mission/escort scenario suite is deliberately not repeated here.
	print("REVISION_CHECKS failures=",failures)
	get_tree().quit(failures)
