extends Node
const Store=preload("res://scripts/workshop_store.gd")
func _ready() -> void:call_deferred("run")
func run() -> void:
 assert(OS.get_user_data_dir().contains("polish_userdata"),"Run this test with an isolated APPDATA directory")
 GameState.new_session()
 GameState.selected_mission="earth_imaging"
 var m:=GameState.mission()
 var f=preload("res://scripts/gameplay/launch_sequence.gd").new()
 f.mission=m
 f.craft=Store.Design.craft("Satellite",m.recommended)
 var limits=preload("res://scripts/gameplay/design_help.gd").minimums(m)
 f.craft.capabilities=m.required.duplicate()
 f.craft.storage_tb=maxf(f.craft.storage_tb,limits.storage)
 f.craft.battery_kwh=maxf(f.craft.battery_kwh,limits.battery)
 f.craft.generation_w=maxf(f.craft.generation_w,f.craft.load_w*1.25)
 f.craft.pcdu_w=maxf(f.craft.pcdu_w,f.craft.load_w*1.2)
 var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
 for id in ["engine_l","hydro_m","be3u","hydro_s","interstage_heavy","sep_heavy","avionics","payload","fairing_m"]:
  var p:Dictionary=cat.filter(func(p):return p.id==id)[0].duplicate(true)
  p.stage=1 if id in ["be3u","hydro_s"] else 0
  f.parts.append(p)
 f.performance={"errors":[],"dv":float(m.dv_target)*1.1,"target":float(m.dv_target)}
 add_child(f)
 f.set_process(false)
 assert(GameAudio.music_player.playing)
 f.elapsed=200
 f._update(.6)
 assert(f.report.success)
 var save=f.result.find_children("*","Button",true,false).filter(func(b):return b.text=="SAVE TO WORKSHOP")[0]
 assert(Store.write([]))
 save.pressed.emit()
 assert(Store.all().size()==1)
 await shot("workshop_result")
 var exported:=JSON.stringify(Store.all()[0])
 f.queue_free()
 await get_tree().process_frame
 var menu=preload("res://scenes/ui/workshop_menu.tscn").instantiate()
 add_child(menu)
 menu._read(exported)
 assert(Store.all().size()==2)
 menu._read("{\"format\":\"bad\"}")
 assert(Store.all().size()==2)
 assert(menu.status.text!="Blueprint imported.")
 await shot("workshop_list")
 menu.queue_free()
 await get_tree().process_frame
 print("PASS Launch music, automatic result, successful save and file roundtrip; invalid import rejected")
 GameState.new_session(true)
 var world=preload("res://scenes/world/world.tscn").instantiate()
 add_child(world)
 SaveStore.world=null
 await world._sandbox_welcome()
 assert(world.player.mode=="dialogue")
 assert(world.gameplay_ui.modal.lines[0].contains("Sandbox"))
 await shot("sandbox_welcome")
 print("PASS Scientist Sandbox welcome")
 get_tree().quit()
func shot(label:String) -> void:
 await get_tree().create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/polish_"+label+".png")
