extends Node
const Store=preload("res://scripts/workshop_store.gd")
func _ready() -> void:call_deferred("run")
func run() -> void:
 assert(not InputMap.has_action("facility_map"))
 print("PASS M map disabled")
 var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
 var p:Dictionary=cat[0].duplicate(true)
 p.stage=0
 var craft=Store.Design.craft("Satellite",[])
 var entry:=Store.pack("Test vehicle",[p],craft,{})
 print("ISSUE ",Store.validate(JSON.parse_string(JSON.stringify(entry))))
 assert(Store.validate(JSON.parse_string(JSON.stringify(entry))).is_empty())
 assert(Store.parts(entry)[0].id==p.id)
 var bad=entry.duplicate(true)
 bad.parts[0].id="res://malicious.gd"
 assert(not Store.validate(bad).is_empty())
 assert(not Store.validate({}).is_empty())
 print("PASS Blueprint roundtrip and invalid imports")
 var workshop=preload("res://scenes/ui/workshop_menu.tscn").instantiate()
 add_child(workshop)
 await get_tree().process_frame
 workshop.queue_free()
 GameState.new_session(true)
 var world=preload("res://scenes/world/world.tscn").instantiate()
 get_tree().root.add_child(world)
 get_tree().current_scene=world
 SaveStore.world=null
 assert(world.player.global_position.distance_to(Vector3(7.3,4.1,7.8))<.3)
 print("PASS Sandbox starts beside scientist")
 var ui=world.gameplay_ui
 var terminal=world.get_node("SpacecraftTerminal")
 ui._build_terminal_content(terminal)
 await get_tree().process_frame
 var buttons=ui.modal.find_children("*","Button",true,false)
 var choices=buttons.filter(func(b):return b.text in Store.Design.BUSES)
 assert(choices.size()==5)
 await shot("craft_choices")
 choices.filter(func(b):return b.text=="Satellite")[0].pressed.emit()
 await get_tree().process_frame
 assert(ui.modal.find_children("*","Button",true,false).any(func(b):return b.text=="SAVE CONCEPT"))
 print("PASS Illustrated spacecraft chooser opens editor")
 await ui.close_modal()
 world.player.set_controls_enabled(false)
 world.player.astronaut.hide()
 ui.hud.hide()
 var camera:=Camera3D.new()
 world.add_child(camera)
 camera.current=true
 camera.fov=80
 for floor_name in ["Floor01","Floor02"]:
  for room in world.get_node(floor_name).get_children():
   if room.get("room_title")==null:continue
   var at:Vector3=room.global_position+Vector3(room.room_size.x*.28,1.6,room.room_size.y*.28)
   world.player.global_position=at-Vector3.UP*1.6
   camera.global_position=at
   camera.look_at(room.global_position+Vector3(0,1.4,-room.room_size.y*.25))
   await shot(floor_name+"_"+room.room_title.to_lower().replace(" ","_"))
 print("PASS All room views captured")
 get_tree().quit()
func shot(label:String) -> void:
 await get_tree().create_timer(.16).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/polish_"+label+".png")
