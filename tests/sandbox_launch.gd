extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 GameState.new_session(true)
 for kind in preload("res://scripts/gameplay/design_data.gd").BUSES:
  GameState.sandbox_spacecraft=kind
  assert(GameState.mission().spacecraft_type==kind)
 GameState.sandbox_spacecraft="Satellite"
 var world=preload("res://scenes/world/world.tscn").instantiate()
 add_child(world)
 SaveStore.world=null
 var m:=GameState.mission()
 var cart=world.get_node("SpacecraftTerminal").reader.cartridge
 await get_tree().create_timer(.5).timeout
 var ids:Array=m.recommended.duplicate()
 GameState.sandbox_design=preload("res://scripts/gameplay/design_data.gd").craft("Satellite",ids)
 cart.write_spacecraft("",GameState.sandbox_design)
 var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
 var parts:Array=[]
 for id in ["engine_l","hydro_m","hydro_m","be3u","hydro_m","interstage_heavy","sep_heavy","booster_m","booster_m","avionics","payload","fairing_m"]:
  var p:Dictionary=cat.filter(func(p):return p.id==id)[0].duplicate(true)
  p.stage=1 if id=="be3u" or (id=="hydro_m" and parts.size()>3) else 0
  parts.append(p)
 cart.write_rocket({"parts":parts,"payload_type":"Satellite"})
 var verification=world.get_node("VerificationTerminal")
 verification.reader.cartridge=cart
 var report:String=verification.run_verification()
 print(report)
 if cart.verification_status!="DATA_VERIFIED":get_tree().quit(1);return
 var launch=world.get_node("LaunchTerminal")
 launch.reader.cartridge=cart
 assert(launch.access_error().is_empty())
 var ui=world.gameplay_ui
 ui._build_terminal_content(launch)
 var buttons=ui.modal.find_children("*","Button",true,false).filter(func(b):return b.text=="BEGIN LAUNCH SEQUENCE")
 assert(buttons.size()==1)
 buttons[0].pressed.emit()
 assert(is_instance_valid(ui._flight))
 ui._flight.elapsed=200
 ui._flight._update(.6)
 assert(ui._flight.report.success)
 cart.verification_status="NOT_CHECKED"
 assert(not launch.access_error().is_empty())
 print("PASS Sandbox profiles, real verification, launch button, cinematic success, unverified launch blocked")
 get_tree().quit()
