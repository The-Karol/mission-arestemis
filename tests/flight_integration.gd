extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 GameState.new_session()
 GameState.selected_mission="earth_imaging"
 var world=preload("res://scenes/world/world.tscn").instantiate()
 get_tree().root.add_child(world)
 get_tree().current_scene=world
 var ui=world.gameplay_ui
 var cart=get_tree().get_nodes_in_group("cartridges")[0]
 cart.write_spacecraft(GameState.selected_mission,preload("res://scripts/gameplay/design_data.gd").craft("Satellite",[]))
 cart.write_rocket({"parts":[],"payload_type":"Satellite"})
 cart.verification_status="DATA_VERIFIED"
 var terminal=world.get_node("LaunchTerminal")
 terminal.reader.cartridge=cart
 ui._build_terminal_content(terminal)
 var buttons=ui.modal.find_children("*","Button",true,false).filter(func(b):return b.text=="BEGIN LAUNCH SEQUENCE")
 assert(buttons.size()==1)
 buttons[0].pressed.emit()
 assert(is_instance_valid(ui._flight) and world.player.mode=="launch")
 print("PASS Launch console starts cinematic from cartridge")
 var f=ui._flight
 f.elapsed=200
 f._update(.6)
 assert(not f.report.is_empty())
 f.finished.emit()
 await get_tree().create_timer(1.2).timeout
 assert(not is_instance_valid(ui._flight))
 assert(world.player.controls_enabled)
 print("PASS Debrief returns to first-person control")
 get_tree().quit()
