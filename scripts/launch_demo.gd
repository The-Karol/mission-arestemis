extends Node3D
# Isolated demonstration; never registers a campaign world with SaveStore.
func _ready() -> void:call_deferred("start")
func start() -> void:
 GameState.new_session()
 GameState.selected_mission="earth_imaging"
 GameState.intro_briefed=true
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("17242e")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_energy=.75
 add_child(env)
 SpaceVisuals.box(self,"Floor",Vector3(16,.2,16),Vector3(0,-.15,0),Color("484f50"),true)
 SpaceVisuals.box(self,"Back wall",Vector3(16,5,.3),Vector3(0,2.4,-3),Color("424d53"))
 for x in [-4,4]:
  SpaceVisuals.box(self,"Wall stripe",Vector3(.2,5,.4),Vector3(x,2.4,-2.8),Color("b58d56"))
 var light:=OmniLight3D.new()
 light.position=Vector3(1,4,2)
 light.light_color=Color("ffdbac")
 light.light_energy=3
 light.omni_range=14
 add_child(light)
 var terminal:=preload("res://scenes/computers/computer_terminal.tscn").instantiate()
 terminal.terminal_type="launch"
 add_child(terminal)
 var cart:=preload("res://scenes/items/data_cartridge.tscn").instantiate()
 add_child(cart)
 var design=preload("res://scripts/gameplay/design_data.gd")
 var mission:=GameState.mission()
 var craft:=design.craft("Satellite",mission.recommended)
 var minimums=preload("res://scripts/gameplay/design_help.gd").minimums(mission)
 craft.capabilities=mission.required.duplicate()
 craft.storage_tb=maxf(craft.storage_tb,minimums.storage)
 craft.battery_kwh=maxf(craft.battery_kwh,minimums.battery)
 craft.generation_w=maxf(craft.generation_w,craft.load_w*1.25)
 craft.pcdu_w=maxf(craft.pcdu_w,craft.load_w*1.2)
 cart.write_spacecraft(GameState.selected_mission,craft)
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
 var parts:Array=[]
 for id in ["engine_l","hydro_m","hydro_m","be3u","hydro_m","interstage_heavy","sep_heavy","booster_m","booster_m","avionics","payload","fairing_m"]:
  var matches=catalog.filter(func(p):return p.id==id)
  if matches.is_empty():continue
  var part:Dictionary=matches[0].duplicate(true)
  part.stage=1 if id=="be3u" or (id=="hydro_m" and parts.size()>3) else 0
  parts.append(part)
 cart.write_rocket({"parts":parts,"payload_type":"Satellite"})
 cart.verification_status="DATA_VERIFIED"
 terminal.reader.cartridge=cart
 cart.hide()
 var player:=preload("res://scenes/player/player.tscn").instantiate()
 add_child(player)
 player.position=Vector3(0,.02,2.8)
 var ui:=preload("res://scenes/ui/gameplay_ui.tscn").instantiate()
 add_child(ui)
 ui.configure(player)
 GameState.set_objective("Launch demonstration","Prepared example  /  no campaign save is changed.",Vector3.ZERO)
 await get_tree().create_timer(1.2).timeout
 ui.open_terminal(terminal)

