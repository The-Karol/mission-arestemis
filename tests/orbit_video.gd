extends Node
var flight:Control
var frame:=0
var automatic_check:=false
func _ready() -> void:
 automatic_check="--automatic-check" in OS.get_cmdline_user_args()
 flight=preload("res://scripts/gameplay/launch_sequence.gd").new()
 flight.mission=GameState.missions.filter(func(m):return m.id=="earth_imaging")[0]
 flight.craft=preload("res://scripts/gameplay/design_data.gd").craft("Satellite",flight.mission.recommended)
 flight.parts=[]
 flight.performance={"errors":[],"dv":11000.0,"target":9900.0}
 add_child(flight)
 flight.set_process(false)
 flight.deterministic_clock=true
 if not automatic_check:
  flight.elapsed=flight.countdown_time+22
  flight._update(.6)
func _process(delta:float) -> void:
 if not is_instance_valid(flight):return
 if automatic_check:
  # Exercise automatic processing; no direct seeking and no keyboard events.
  flight._process(.5)
  if is_instance_valid(flight.result):
   assert(flight.result.visible and flight.phase==9)
   print("PASS Automatic debrief without Space at ",flight.elapsed," seconds")
   get_tree().quit()
  if frame>400:
   push_error("Automatic result timed out")
   get_tree().quit(1)
 else:
  flight._process(1.0/30)
  if frame in [60,240,420]:
   capture.call_deferred(frame)
  if frame>=477:get_tree().quit()
 frame+=1
func capture(index:int) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/orbit_%d.png"%index)
