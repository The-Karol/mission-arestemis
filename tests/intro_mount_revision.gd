extends Node
var failed:=false
func check(value:bool,text:String) -> void:
	print("PASS " if value else "FAIL ",text)
	failed=failed or not value
func capture(label:String) -> void:
	await get_tree().create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/intro_fix_"+label+".png")
func _ready() -> void:call_deferred("run")
func run() -> void:
	var old_guidance:int=SettingsStore.guidance
	SceneManager.menu_intro_seen=true
	for choice in [0,1]:
		SettingsStore.guidance=choice
		var menu=preload("res://scenes/ui/main_menu.tscn").instantiate()
		add_child(menu)
		menu._play()
		check(menu.has_node("GuideChoice"),"New campaign asks about guidance with saved preference "+str(choice))
		menu.queue_free()
		await get_tree().process_frame
	SettingsStore.guidance=old_guidance
	GameState.new_session()
	var world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	var guide=world.engineer
	world.player.global_position=Vector3(-31.7,.1,14.5)
	world.player.head.rotation.y=PI
	world.player.reset_physics_interpolation()
	guide.begin()
	check(GameState.objective=="Meet the Engineer","Introduction comes before the cartridge search")
	guide.talk()
	await get_tree().create_timer(.6).timeout
	var modal=world.gameplay_ui.modal
	check(modal.lines.size()>=4 and str(modal.lines[0]).contains("engineer") and str(modal.lines[2]).contains("cartridge"),"Engineer introduces herself, explains mission and assigns cartridge search")
	await capture("introduction")
	modal.finished.emit()
	await get_tree().create_timer(1.3).timeout
	check(GameState.intro_briefed and guide.state=="waiting_cartridge" and GameState.objective.contains("cartridge"),"Search starts after introductory dialogue")
	var cart=get_tree().get_nodes_in_group("cartridges")[0]
	world.player.global_position=cart.global_position+Vector3(0,0,1)
	world.player.take_item(cart)
	await get_tree().physics_frame
	check(guide.state=="waiting_cartridge","Engineer waits while player retrieves cartridge")
	world.player.global_position=guide.global_position+Vector3(0,0,-3)
	world.player.reset_physics_interpolation()
	await get_tree().create_timer(.25).timeout
	check(is_instance_valid(world.gameplay_ui.modal),"Engineer acknowledges the return before escorting player")
	world.gameplay_ui.modal.finished.emit()
	await get_tree().create_timer(1.3).timeout
	check(guide.state=="guiding","Escort starts after return dialogue")
	guide.active=false
	guide.animation.play("Idle")
	var cam:=Camera3D.new()
	world.add_child(cam)
	cam.position=guide.global_position+Vector3(-.8,1.25,-2.0)
	cam.look_at(guide.global_position+Vector3(0,.95,0))
	cam.make_current()
	world.gameplay_ui.hud.hide()
	guide.visible=true
	await get_tree().create_timer(.3).timeout
	await capture("clipboard_idle")
	var board=guide.pose.board
	check(board.global_position.distance_to(board.get_meta("palm_world"))<.4,"Clipboard stays close to hand")
	var sk=guide.pose.get_skeleton()
	var head:Vector3=(sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Head"))).origin
	check(board.global_basis.y.normalized().dot(head-board.global_position)>0,"Clipboard paper faces the engineer")
	var contact:Vector3=board.global_transform*board.get_meta("grip_local")
	check(contact.distance_to(board.get_meta("palm_world"))<.002,"Clipboard edge touches palm")
	guide.animation.play("Walk")
	guide.pose.stride=1.0
	await get_tree().create_timer(.4).timeout
	await capture("clipboard_walk")
	contact=board.global_transform*board.get_meta("grip_local")
	check(contact.distance_to(board.get_meta("palm_world"))<.002,"Clipboard grip stays attached during walk animation")
	var count:=0
	var vents:=0
	for item in world.find_children("*","Node3D",true,false):
		if not item.has_meta("wall_mounted"):continue
		count+=1
		var wall=world.get_node(item.get_meta("support_wall"))
		var dim:Vector3=wall.get_node("CollisionShape3D").shape.size
		var box:AABB=item.transform*item.get_meta("model_bounds")
		var along_x:bool=dim.x>dim.z
		var gap:float=absf(box.get_center().z-wall.position.z)-(box.size.z+dim.z)*.5 if along_x else absf(box.get_center().x-wall.position.x)-(box.size.x+dim.x)*.5
		check(absf(gap-.006)<.001,"Wall contact: "+str(item.name))
		if "Vent" in str(item.name):
			vents+=1
			check(box.size.y>minf(box.size.x,box.size.z)*2,"Vent is upright, not lying in the air")
			cam.global_position=item.global_position+Vector3(-1,0,-1)
	check(count>12 and vents>=3,"Wall decoration remounted throughout facility")
	# Frame a workshop vent and its actual supporting wall.
	for room in world.get_node("Floor01").get_children():
		if room.get("room_title")!="WORKSHOP":continue
		cam.global_position=room.global_position+Vector3(2.2,1.7,-1.6)
		cam.look_at(room.global_position+Vector3(4.85,2.45,-2.5))
	await capture("vent")
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
