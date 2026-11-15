extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 var m:Dictionary=GameState.missions[1]
 var flight=preload("res://scripts/gameplay/launch_sequence.gd").new()
 flight.mission=m
 flight.craft=preload("res://scripts/gameplay/design_data.gd").craft("Rover",m.recommended)
 var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
 for id in ["engine_l","hydro_m","be3u","hydro_s","interstage_heavy","sep_heavy","avionics","payload","fairing_m"]:
  for p in cat:
   if p.id==id:
    p.stage=1 if id in ["be3u","hydro_s"] else 0
    flight.parts.append(p)
 flight.performance=preload("res://scripts/gameplay/vehicle_performance.gd").evaluate(flight.parts,flight.craft,m)
 add_child(flight)
 flight.set_process(false)
 for t in [2,7,18,36,54,62,81,102,124,151,175]:
  flight.elapsed=t
  flight._update(.6)
  await get_tree().create_timer(.2).timeout
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/flight_%d.png"%t)
  print("SHOT ",t," phase ",flight.phase)
 assert(load("res://scripts/gameplay/gameplay_ui.gd").can_instantiate())
 flight.queue_free()
 await get_tree().process_frame
 for entry in GameState.missions:
  var f=preload("res://scripts/gameplay/launch_sequence.gd").new()
  f.mission=entry
  f.craft=preload("res://scripts/gameplay/design_data.gd").craft(entry.spacecraft_type,entry.recommended)
  f.parts=[]
  f.performance={"errors":[],"dv":float(entry.dv_target),"target":float(entry.dv_target)}
  add_child(f)
  f.set_process(false)
  for t in [0,35,48,60,80,100,124,150,185]:
   f.elapsed=t
   f._update(.6)
  assert(f.phase==9 and not f.report.is_empty())
  assert(f.countdown_time+154<300)
  assert(GameState.flight_results.has(str(entry.id)))
  assert(is_instance_valid(f.result) and f.result.visible)
  assert(f.broadcast.size.x/f.broadcast.size.y>1.32)
  assert(f.core.find_child("VisibleEngine",true,false)!=null or f.parts.is_empty())
  print("PASS endpoint, duration, result: ",entry.id)
  f.queue_free()
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
 print("FLIGHT REVIEW COMPLETE")
 get_tree().quit()
