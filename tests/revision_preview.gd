extends Node

func _ready() -> void:
	call_deferred("run")

func capture(name_text: String) -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/revision_%s.png" % name_text)
	print("PREVIEW ", name_text)

func run() -> void:
	var menu := preload("res://scenes/ui/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	await capture("menu")
	if OS.get_cmdline_user_args().has("--menu-only"):
		get_tree().quit()
		return
	menu.queue_free()
	await get_tree().process_frame
	var world := preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	var player: CharacterBody3D = world.player
	player.set_controls_enabled(false)
	world.gameplay_ui.hud.hide()
	player.get_node("HUD").hide()
	for view in [["hall",Vector3(-19,4.05,19),Vector3(-10,3,-4)], ["project",Vector3(-32,4.05,4.2),Vector3(-32,5.1,-1)], ["lab",Vector3(2,4.05,6.7),Vector3(10,5.1,4.6)]]:
		player.global_position = view[1]
		player.camera.look_at(view[2])
		await capture(view[0])
	get_tree().quit()
