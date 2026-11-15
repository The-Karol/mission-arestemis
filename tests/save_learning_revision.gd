extends Node
const Design=preload("res://scripts/gameplay/design_data.gd")
const Help=preload("res://scripts/gameplay/design_help.gd")
const Rules=preload("res://scripts/gameplay/craft_assembly_rules.gd")
var failed:=false
func check(value:bool,text:String) -> void:
	print("PASS " if value else "FAIL ",text)
	failed=failed or not value
func shot(name:String) -> void:
	await get_tree().create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/learning_"+name+".png")
func _ready() -> void:call_deferred("run")
func run() -> void:
	var old_prefix:=SaveStore.prefix
	SaveStore.prefix="arestemis_qa_session"
	SaveStore.clear_slot()
	SaveStore.clear_slot(true)
	SaveStore.world=null
	SaveStore.pending={}
	GameState.new_session()
	GameState.starter_found=true
	GameState.intro_briefed=true
	GameState.files_available=true
	GameState.selected_mission=GameState.missions[0].id
	GameState.mission_stage=GameState.Stage.SPACECRAFT_DESIGN
	var world=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	world.player.global_position=Vector3(8,4.1,6.3)
	world.player.head.rotation.y=.7
	world.player._pitch=-.2
	world.player.reset_physics_interpolation()
	var cart=get_tree().get_nodes_in_group("cartridges")[0]
	cart.write_spacecraft(GameState.selected_mission,Design.craft("Rover",["A1.1","A1.5","E9"]))
	var term=world.get_node("SpacecraftTerminal")
	term.reader.cartridge=cart
	term.reader._dock(false)
	await get_tree().create_timer(.4).timeout
	world.gameplay_ui._build_terminal_content(term)
	await get_tree().process_frame
	var editor=world.gameplay_ui.modal.find_children("*","VBoxContainer",true,false).filter(func(n):return n.has_method("_delete_selected"))[0]
	editor.ids.append("A1.8")
	editor._update_design()
	var limits:=Rules.addition_error("Rover",["A1.1","A1.1"],Design.by_id["A1.1"])
	check(not limits.is_empty(),"A third identical solar array is rejected")
	check(not Rules.addition_error("Rover",["A1.5","A1.5"],Design.by_id["A1.5"]).is_empty(),"Battery duplication is limited")
	check(editor.requirements.get_child_count()>=10,"Mission requirements show individual capabilities and numeric minima")
	await shot("craft")
	var scan:=RegEx.new()
	scan.compile("[А-Яа-яЁё]")
	var english:=true
	for p in Design.catalog():
		if scan.search(Design.part_help(p))!=null:english=false
	var rocket:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	for p in rocket:
		if scan.search(Design.part_help(p))!=null:english=false
	check(english,"All component explanations are English")
	check(Help.details(rocket.filter(func(p):return p.id=="sep_standard")[0])!=Help.details(rocket.filter(func(p):return p.id=="sep_redundant")[0]),"Separation variants explain distinct tradeoffs")
	check(Help.clean("Δv >= 1")=="dV >= 1","Unsupported delta uses readable ASCII")
	await get_tree().create_timer(.4).timeout
	var lift:=Node3D.new()
	lift.name="ElevatorIntro"
	world.add_child(lift)
	world.player.reparent(lift,true)
	var during_arrival:Dictionary=SaveStore.capture(world)
	check(SaveStore.vector(during_arrival.player.position).distance_to(Vector3(-32,.1,18))<.001,"Saving during lift arrival uses the safe landing on resume")
	world.player.reparent(world,true)
	lift.queue_free()
	SaveStore.bind_world(world)
	check(SaveStore.save_now(),"Campaign checkpoint written")
	var before:Dictionary=SaveStore.latest()
	check(before.draft.spacecraft.module_ids.has("A1.8"),"Unsaved editor module is included")
	check(before.cartridges[0].state=="reader","Cartridge reader ownership is recorded")
	# Do not auto-open the terminal during this state-restoration assertion.
	var saved:Dictionary=before.duplicate(true)

	SaveStore.world=null
	world.queue_free()
	await get_tree().process_frame
	SaveStore.prepare_resume(saved)
	var restored=preload("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(restored)
	get_tree().current_scene=restored
	SaveStore.apply_world(restored)
	check(restored.player.global_position.distance_to(Vector3(8,4.1,6.3))<.001,"Resume restores player location")
	check(absf(restored.player.head.rotation.y-.7)<.001,"Resume restores viewing direction")
	check(GameState.selected_mission==GameState.missions[0].id,"Resume preserves selected mission")
	check(restored.get_node("SpacecraftTerminal").reader.has_cartridge(),"Resume restores the inserted cartridge")
	check(GameState.editor_drafts.spacecraft.module_ids.has("A1.8"),"Resume preserves unfinished spacecraft work")
	await get_tree().create_timer(2.6).timeout
	var ui=restored.gameplay_ui
	check(is_instance_valid(ui._terminal) and ui._terminal.terminal_type=="spacecraft","Resume reopens the workstation that was being edited")
	ui.open_dossier()
	await shot("dossier")
	check(is_instance_valid(ui.dossier_overlay),"Chosen mission can be read above an open editor")
	ui.dossier_overlay.exit_requested.emit()
	await get_tree().process_frame
	await ui.close_modal()
	var launcher=restored.get_node("RocketTerminal")
	launcher.reader.cartridge=restored.get_node("SpacecraftTerminal").reader.cartridge
	ui._build_terminal_content(launcher)
	await shot("rocket")
	check(ui._stats.get_child_count()==5,"Rocket performance figures have separate hover targets")
	check(ui._stats.get_child(2).tooltip_text.contains("weight"),"TWR explains the relation of thrust and weight")
	check(ui.category_buttons.ENGINES.tooltip_text.contains("Stage 1"),"Rocket categories explain their purpose")
	await ui.close_modal()
	var loading=preload("res://scenes/ui/transition_fade.tscn").instantiate()
	add_child(loading)
	loading.fade_rect.modulate.a=1
	loading.show_loading()
	loading.update_loading("Preparing the facility visuals...",74)
	await shot("loading")
	check(loading.progress.value==74 and loading.status.text.contains("visuals"),"Loading screen displays actual preparation stage")
	loading.queue_free()
	SaveStore.world=null
	restored.queue_free()
	await get_tree().process_frame
	SaveStore.clear_slot()
	SaveStore.clear_slot(true)
	SaveStore.prefix=old_prefix
	get_tree().quit(1 if failed else 0)
