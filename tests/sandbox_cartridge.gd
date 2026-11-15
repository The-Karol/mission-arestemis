extends Node
func _ready() -> void:call_deferred("run")
func run() -> void:
 GameState.new_session(true)
 var world=preload("res://scenes/world/world.tscn").instantiate()
 add_child(world)
 SaveStore.world=null
 var t=world.get_node("SpacecraftTerminal")
 await get_tree().create_timer(.5).timeout
 assert(t.reader.has_cartridge())
 var cart=t.reader.cartridge
 world._ensure_sandbox_cartridge()
 assert(get_tree().get_nodes_in_group("cartridges").size()==1)
 GameState.sandbox_design=preload("res://scripts/gameplay/design_data.gd").craft("Satellite",["A2.1"])
 assert(t.save_sandbox_cartridge().begins_with("Saved"))
 assert(cart.spacecraft_design.module_ids==["A2.1"])
 assert(t.reader.remove_cartridge(world.player))
 await get_tree().create_timer(.4).timeout
 assert(world.player.carried_item==cart)
 var rocket=world.get_node("RocketTerminal")
 assert(rocket.reader.insert_cartridge(world.player))
 await get_tree().create_timer(.5).timeout
 assert(rocket.reader.cartridge==cart)
 GameState.sandbox_parts=[{"id":"engine_l","stage":0}]
 assert(rocket.save_sandbox_cartridge().begins_with("Saved"))
 assert(cart.rocket_design.parts[0].id=="engine_l")
 cart.free()
 world._ensure_sandbox_cartridge()
 assert(t.reader.has_cartridge())
 assert(t.reader.cartridge.spacecraft_design.module_ids==["A2.1"])
 assert(t.reader.cartridge.rocket_design.parts[0].id=="engine_l")
 print("PASS Sandbox cartridge: initial dock, save, carry, second station, legacy recovery, no duplicates")
 get_tree().quit()
