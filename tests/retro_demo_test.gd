extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 var demo=load("res://scenes/demo/launch_demo.tscn").instantiate()
 add_child(demo)
 await get_tree().create_timer(4).timeout
 var ui=demo.get_children().filter(func(n):return n is CanvasLayer)[0]
 ui._begin_launch()
 assert(is_instance_valid(ui._flight))
 var f=ui._flight
 print("DEMO performance ",f.performance.errors)
 for i in 9:
  var down:=InputEventKey.new()
  down.physical_keycode=KEY_SPACE
  down.pressed=true
  f._input(down)
  down.pressed=false
  f._input(down)
  await get_tree().process_frame
 assert(f.report.success)
 assert(f.phase==9 and is_instance_valid(f.result) and f.result.visible)
 print("PASS Space advances every segment and displays demo results: ",f.report)
 await get_tree().create_timer(.8).timeout
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/retro_demo_result.png")
 get_tree().quit()
