extends Node
const VERSION:=1
var world:Node3D
var pending:Dictionary={}
var prefix:="arestemis_session"
var offer_shown:=false
var elapsed:=0.0
var _page_exit:JavaScriptObject

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_page_exit=JavaScriptBridge.create_callback(func(_args):save_now())
		JavaScriptBridge.get_interface("window").addEventListener("pagehide",_page_exit)

func _path(slot:String) -> String:return "user://"+prefix+"_"+slot+".json"
func _read(slot:String) -> Dictionary:
	var text:=""
	if OS.has_feature("web"):
		text=str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem("+JSON.stringify(prefix+"_"+slot)+")||'';}catch(e){return '';}})()",true))
	elif FileAccess.file_exists(_path(slot)):
		text=FileAccess.get_file_as_string(_path(slot))
	var data:Variant=JSON.parse_string(text) if not text.is_empty() else null
	if not data is Dictionary and not OS.has_feature("web") and FileAccess.file_exists(_path(slot)+".bak"):
		data=JSON.parse_string(FileAccess.get_file_as_string(_path(slot)+".bak"))
	if not data is Dictionary or data.get("version",0)!=VERSION or not data.has("state"):return {}
	return data

func latest() -> Dictionary:
	var campaign:=_read("campaign")
	var sandbox:=_read("sandbox")
	return campaign if campaign.get("timestamp",0)>=sandbox.get("timestamp",0) else sandbox
func has_save() -> bool:return not latest().is_empty()

func clear_slot(sandbox:bool=false) -> void:
	var slot:="sandbox" if sandbox else "campaign"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.removeItem("+JSON.stringify(prefix+"_"+slot)+")",true)
	else:
		for path in [_path(slot),_path(slot)+".bak"]:
			if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func bind_world(value:Node3D) -> void:
	world=value
	elapsed=0
func _process(delta:float) -> void:
	elapsed+=delta
	if elapsed<3:return
	elapsed=0
	if OS.get_cmdline_user_args().has("--test") or OS.get_cmdline_user_args().has("--bake-nav") or OS.has_feature("qa"):return
	save_now()
func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:save_now()

func capture(value:Node3D) -> Dictionary:
	var state:Dictionary={}
	for key in ["flight_results","sandbox","selected_mission","mission_started","mission_stage","objective","objective_hint","files_available","starter_found","intro_briefed","_serial","sandbox_design","sandbox_parts","sandbox_spacecraft"]:
		state[key]=GameState.get(key)
	state.target=vec(GameState.objective_target)
	state.starter_location=vec(GameState.starter_location)
	state.offers=GameState.offered_missions.map(func(m):return m.id)
	var player=value.player
	var saved_position:Vector3=player.global_position
	if str(player.get_parent().name)=="ElevatorIntro":saved_position=Vector3(-32,.1,18)
	var g=value.engineer
	var carts:Array=[]
	for cart in get_tree().get_nodes_in_group("cartridges"):
		if not value.is_ancestor_of(cart):continue
		var info:Dictionary=cart.snapshot()
		info.position=vec(cart.global_position)
		info.state=cart.state
		info.starter=cart.has_meta("starter_cartridge")
		info.reader=str(cart.holder.get_parent().name) if cart.state=="reader" and is_instance_valid(cart.holder) else ""
		carts.append(info)
	var ui=value.gameplay_ui
	var draft:Dictionary=GameState.editor_drafts.duplicate(true)
	var active_terminal:=""
	if is_instance_valid(ui._terminal) and is_instance_valid(ui.modal):
		active_terminal=ui._terminal.terminal_type
		if active_terminal=="rocket":draft.rocket=ui._parts.duplicate(true)
		if active_terminal=="spacecraft":
			for child in ui.modal.find_children("*","VBoxContainer",true,false):
				if child.has_method("_delete_selected"):draft.spacecraft={"type":child.kind,"module_ids":child.ids.duplicate()}
	return {"version":VERSION,"timestamp":Time.get_unix_time_from_system(),"state":state,"cartridges":carts,
	"player":{"position":vec(saved_position),"yaw":player.head.rotation.y,"pitch":player._pitch},
	"engineer":{"position":vec(g.global_position),"yaw":g.visual.rotation.y,"active":g.active,"state":g.state,"introduced":g._introduced,"arrived":g._arrival_dialogue},
	"draft":draft,"active_terminal":active_terminal,
	"guidance":SettingsStore.guidance,"seen_guides":Array(SettingsStore.seen_guides)}

func save_now() -> bool:
	if not is_instance_valid(world) or not world.ready_to_play or not pending.is_empty():return false
	var data:=capture(world)
	var slot:="sandbox" if GameState.sandbox else "campaign"
	var text:=JSON.stringify(data)
	if OS.has_feature("web"):
		var result=JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(prefix+"_"+slot)+","+JSON.stringify(text)+");return true;}catch(e){return false;}})()",true)
		return result==true
	var path:=_path(slot)
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(path+".bak")
	if FileAccess.file_exists(path):DirAccess.rename_absolute(path,path+".bak")
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func prepare_resume(data:Dictionary={}) -> void:
	pending=latest() if data.is_empty() else data.duplicate(true)
	if pending.is_empty():return
	var state:Dictionary=pending.state
	GameState.new_session(state.get("sandbox",false))
	for key in state:
		if key not in ["target","starter_location","offers"]:GameState.set(key,str(state[key]).replace("Orion","Hyperion").replace("ORION","HYPERION") if state[key] is String else state[key])
	GameState.objective_target=vector(state.target)
	GameState.starter_location=vector(state.starter_location)
	GameState.offered_missions=[]
	for id in state.offers:
		for mission in GameState.missions:
			if mission.id==id:GameState.offered_missions.append(mission)
	GameState.editor_drafts=pending.get("draft",{}).duplicate(true)
	SettingsStore.guidance=int(pending.get("guidance",1))
	SettingsStore.seen_guides=PackedStringArray(pending.get("seen_guides",[]))

func apply_world(value:Node3D) -> void:
	if pending.is_empty():return
	var data:=pending
	var player=value.player
	player.global_position=vector(data.player.position)
	player.head.rotation.y=float(data.player.yaw)
	player._pitch=float(data.player.pitch)
	player.camera.rotation.x=player._pitch
	player.update_eye_offset()
	player.reset_physics_interpolation()
	var guide=value.engineer
	guide.global_position=vector(data.engineer.position)
	guide.visual.rotation.y=float(data.engineer.yaw)
	guide.active=bool(data.engineer.active)
	guide.visible=guide.active
	guide.state=str(data.engineer.state)
	guide._introduced=GameState.intro_briefed
	guide._arrival_dialogue=bool(data.engineer.arrived) and GameState.files_available
	if not GameState.sandbox and not guide.active and not GameState.intro_briefed:guide.begin()
	guide.agent.target_position=guide.destination
	guide.reset_physics_interpolation()
	for existing in get_tree().get_nodes_in_group("cartridges"):
		if value.is_ancestor_of(existing):existing.free()
	player.carried_item=null
	for info in data.cartridges:
		var cart=preload("res://scenes/items/data_cartridge.tscn").instantiate()
		cart.cartridge_id=info.cartridge_id
		cart.mission_id=info.mission_id
		cart.spacecraft_design=info.spacecraft_design
		cart.rocket_design=info.rocket_design
		cart.verification_status=info.verification_status
		cart.data_type=DataCartridge.DataType.keys().find(info.data_type)
		if info.get("starter",false):cart.set_meta("starter_cartridge",true)
		value.add_child(cart)
		cart.global_position=vector(info.position)
		if info.state=="carried":player.take_item(cart)
		elif info.state=="reader":
			var terminal=value.get_node_or_null(str(info.reader))
			if terminal:
				terminal.reader.cartridge=cart
				terminal.reader._dock(false)
	pending={}
	bind_world(value)
	player.set_controls_enabled(true)
	value.gameplay_ui._update_objective()
	if not str(data.get("active_terminal","")).is_empty():
		value.call_deferred("_restore_terminal",str(data.active_terminal))
func vec(value:Vector3) -> Array:return [value.x,value.y,value.z]
func vector(value:Array) -> Vector3:return Vector3(float(value[0]),float(value[1]),float(value[2]))
