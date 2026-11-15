class_name ComputerTerminal
extends SpaceInteractable

@export_enum("spacecraft", "rocket", "verification", "launch") var terminal_type := "spacecraft"
var reader: CartridgeReader
var title := ""
var display_viewport: SubViewport
var display: MeshInstance3D
var screen_box := AABB()
var standby_material: ShaderMaterial
var screen_model: Node3D

func _ready() -> void:
	super._ready()
	title = {"spacecraft":"SPACECRAFT DESIGN", "rocket":"ROCKET ASSEMBLY", "verification":"PRE-LAUNCH VERIFICATION", "launch":"MISSION CONTROL"}[terminal_type]
	var desk := SpaceVisuals.model(self, "environment/engineering_desk", Vector3.ZERO, 0.0, 1.9)
	var top := SpaceVisuals.surface_height(desk,"desk_top")
	screen_model = SpaceVisuals.model(self, "interactive/retro_computer_" + terminal_type, Vector3(-0.3, top, -0.06), 0.0, 0.8, false)
	highlight_root = screen_model
	_create_display()
	SpaceVisuals.interaction_shape(self, Vector3(0.85, 0.75, 0.55), Vector3(-0.3, 1.18, 0))
	reader = preload("res://scenes/computers/cartridge_reader.tscn").instantiate() as CartridgeReader
	reader.name = "CartridgeReader"
	reader.position = Vector3(0.62, top, 0.1)
	add_child(reader)
	var label := SpaceVisuals.label(self, title, Vector3(0,top-0.12,0.47), Color(0.62, 0.88, 0.78), 18)
	label.pixel_size = 0.0018
	add_to_group("terminals")

func _create_display() -> void:
	var original := screen_model.find_child("screen",true,false) as MeshInstance3D
	if not original: return
	screen_box = global_transform.affine_inverse()*original.global_transform*original.get_aabb()
	standby_material = ShaderMaterial.new()
	standby_material.shader = preload("res://materials/terminal_boot.gdshader")
	original.material_override = standby_material
	display_viewport = SubViewport.new()
	display_viewport.size = Vector2i(1280,720)
	display_viewport.disable_3d = true
	display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(display_viewport)
	display = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(screen_box.size.x,screen_box.size.x*720.0/1280.0)
	display.mesh = quad
	display.position = screen_box.get_center()
	display.position.z = screen_box.end.z + 0.002
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = display_viewport.get_texture()
	display.material_override = mat
	add_child(display)
	display.hide()

func boot() -> void:
	standby_material.set_shader_parameter("powered",0.0)
	create_tween().tween_method(func(value: float): standby_material.set_shader_parameter("powered",value),0.0,1.0,0.6)

func show_interface(control: Control) -> void:
	display_viewport.size = Vector2i(get_viewport().get_visible_rect().size)
	var quad := display.mesh as QuadMesh
	quad.size.y = quad.size.x * float(display_viewport.size.y)/float(display_viewport.size.x)
	control.reparent(display_viewport)
	control.position = Vector2.ZERO
	control.size = display_viewport.size
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	display.show()

func camera_pose() -> Transform3D:
	var height: float = (display.mesh as QuadMesh).size.y
	var distance := height/(2.0*tan(deg_to_rad(35.0)*0.5))
	return Transform3D(global_basis,display.global_position+global_basis.z*distance)

func end_interface() -> void:
	display.hide()
	display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func get_interaction_text(_player: Node) -> String:
	return "Use Computer  /  " + title.capitalize()

func interact(player: Node) -> void:
	player.ui.open_terminal(self)

func access_error() -> String:
	if GameState.selected_mission.is_empty() and not GameState.sandbox:
		return "No active mission. Visit the Project Office on Level 02."
	if reader.busy:
		return "Reader busy. Please wait."
	if terminal_type == "spacecraft":
		if not reader.has_cartridge():
			return "Insert your data cartridge into the reader before designing a spacecraft."
		if not GameState.sandbox and reader.has_cartridge() and reader.cartridge.mission_id != "" and reader.cartridge.mission_id != GameState.selected_mission:
			return "Cartridge belongs to another mission."
		return ""
	if not reader.has_cartridge():
		return "Required design cartridge not inserted. Exit the terminal and insert it into the physical reader."
	var cart := reader.cartridge
	if not GameState.sandbox and cart.mission_id != GameState.selected_mission:
		return "Cartridge belongs to another mission."
	if cart.spacecraft_design.is_empty():
		return "No spacecraft design data. Use Spacecraft Design first."
	if terminal_type in ["verification", "launch"] and cart.rocket_design.is_empty():
		return "No rocket design data. Use Rocket Assembly first."
	if terminal_type == "launch" and cart.verification_status != "DATA_VERIFIED":
		return "Design data has not been verified. Visit Pre-launch Verification."
	return ""

func save_spacecraft(design: Dictionary = {}) -> String:
	var error := access_error()
	if not error.is_empty():
		return error
	var cart := reader.cartridge
	if not is_instance_valid(cart):
		return "Cartridge slot occupied or reader busy."
	var mission := GameState.mission()
	if design.is_empty(): design=preload("res://scripts/gameplay/design_data.gd").craft(mission.spacecraft_type,[])
	var assembly_errors:=preload("res://scripts/gameplay/craft_assembly_rules.gd").validate(design.type,design.module_ids)
	if not assembly_errors.is_empty():return assembly_errors[0]
	design["revision"]=Time.get_ticks_msec()
	cart.write_spacecraft(mission.id,design)
	GameAudio.play_effect("saved")
	GameState.set_stage(GameState.Stage.ROCKET_DESIGN)
	return "SPACECRAFT DESIGN SAVED  /  %s\nExit terminal. [E] Remove Cartridge from the reader, then take it to Rocket Assembly." % cart.cartridge_id

func save_rocket(parts: Array, allow_empty:bool=false) -> String:
	var error := access_error()
	if not error.is_empty():
		return error
	var fitting_errors:=preload("res://scripts/gameplay/rocket_assembly_rules.gd").validate(parts)
	if not fitting_errors.is_empty():return fitting_errors[0]
	if parts.is_empty() and allow_empty:
		reader.cartridge.write_rocket({"parts":[],"payload_type":reader.cartridge.spacecraft_design.type})
		GameState.set_stage(GameState.Stage.ROCKET_DESIGN)
		return "EMPTY ROCKET SAVED. Add an engine and tank to begin rebuilding."
	var categories: Array = []
	for part in parts:
		categories.append(part.category)
	for required in ["ENGINES", "FUEL TANKS", "FAIRINGS", "AVIONICS", "PAYLOAD"]:
		if not categories.has(required):
			GameAudio.play_effect("error")
			return "Add %s before saving the vehicle concept." % required.to_lower()
	var performance := preload("res://scripts/gameplay/vehicle_performance.gd").evaluate(parts,preload("res://scripts/gameplay/design_data.gd").payload_design(self),GameState.mission())
	reader.cartridge.write_rocket({"performance":performance, "parts": parts.duplicate(true), "payload_type": reader.cartridge.spacecraft_design.type, "revision": Time.get_ticks_msec()})
	GameAudio.play_effect("saved")
	GameState.set_stage(GameState.Stage.PRELAUNCH_CHECK)
	return "ROCKET DESIGN SAVED\nRemove the cartridge and carry it to Pre-launch Verification  /  KKA / Level 02."

func run_verification() -> String:
	var error := access_error()
	if not error.is_empty():
		if GameState.selected_mission.is_empty() and not GameState.sandbox:return "FAIL  /  "+error
		if error.contains("spacecraft"):GameState.set_stage(GameState.Stage.SPACECRAFT_DESIGN)
		elif error.contains("rocket"):GameState.set_stage(GameState.Stage.ROCKET_DESIGN)
		else:GameState.set_objective("Insert the design cartridge","Use the physical reader at Pre-launch Verification.",global_position)
		return "FAIL  /  "+error
	var cart := reader.cartridge
	var mission := GameState.mission()
	var design := preload("res://scripts/gameplay/design_data.gd")
	var craft: Dictionary = design.payload_design(self)
	var parts: Array = cart.rocket_design.get("parts", [])
	var performance: Dictionary = preload("res://scripts/gameplay/vehicle_performance.gd").evaluate(parts,craft,mission)
	cart.rocket_design["performance"]=performance.duplicate(true)
	var issues: Array[String] = []
	if cart.spacecraft_design.get("type","") != mission.spacecraft_type:
		issues.append("Spacecraft type does not match the mission. Return to Spacecraft Design and select "+str(mission.spacecraft_type)+".")
	if cart.rocket_design.get("payload_type","") != cart.spacecraft_design.get("type",""):
		issues.append("Launcher payload is out of date. Save the rocket again with the current spacecraft cartridge.")
	for required in ["ENGINES","FUEL TANKS","FAIRINGS","AVIONICS","PAYLOAD"]:
		if not parts.any(func(part):return part.get("category","")==required):
			issues.append("Missing "+required.to_lower()+". Fit this component in Rocket Assembly.")
	for fault in performance.errors:
		var advice: String = {
			"Lift-off TWR must exceed 1":"Increase core thrust, add boosters or reduce lift-off mass.",
			"Insufficient mission dV":"Improve the stage mass ratio or add a suitable upper stage.",
			"Payload adapter undersized":"Choose an adapter rated for the spacecraft AND delivery-system mass.",
			"Fairing too narrow":"Choose a fairing at least as wide as the spacecraft.",
			"Interstage capacity exceeded":"Use an interstage with sufficient diameter and upper-stage load rating.",
			"Fit interstage and separation ring":"Fit both the structural interstage and a separation mechanism.",
			"Vacuum engine on core":"Use a sea-level engine on the core; reserve vacuum engines for the upper stage."
		}.get(fault,"Match the engine and tank propellant on this stage; fit both an engine and a tank.")
		issues.append(str(fault)+". "+advice)
	var craft_faults: Array=design.missing_systems(craft,mission)
	for missing in craft_faults:
		issues.append(preload("res://scripts/gameplay/design_help.gd").repair(str(missing),craft,mission))
	var lines := PackedStringArray([
		"MISSION   "+str(mission.get("title","")),
		"ORBIT     "+str(mission.get("recommended_orbit","See mission brief")),
		"PAYLOAD   %.0f kg spacecraft + %.0f kg delivery system" % [craft.mass_kg,mission.get("delivery_kg",0)],
		"VEHICLE   %.2f t lift-off mass | %.0f kN thrust" % [performance.mass/1000.0,performance.thrust],
		"ASCENT    TWR %.2f (required > 1) | dV %.2f / %.2f km/s" % [performance.twr,performance.dv/1000.0,performance.target/1000.0],
		"POWER     %.0f W supply / %.0f W load | %.1f kWh battery" % [craft.generation_w,craft.load_w,craft.battery_kwh],
		"ENVELOPE  diameter %.2f m spacecraft | %.0f kg total payload" % [craft.diameter_m,performance.payload],
		""
	])
	if not issues.is_empty():
		cart.verification_status = "REQUIRES_REVISION"
		cart.data_type = DataCartridge.DataType.ROCKET_DESIGN
		if not craft_faults.is_empty() or cart.spacecraft_design.get("type","")!=mission.spacecraft_type:
			GameState.set_stage(GameState.Stage.SPACECRAFT_DESIGN)
			GameState.set_objective("Correct the spacecraft design","KKA  /  Level 02  /  Spacecraft Design. "+str(issues.back()),Vector3(10,4,5.5))
		else:
			GameState.set_stage(GameState.Stage.ROCKET_DESIGN)
			GameState.set_objective("Correct the launch vehicle","MIK  /  Level 01  /  Rocket Assembly. "+str(issues[0]),Vector3(-17,0,-5.5))
		GameAudio.play_effect("failure")
		lines.append("FAIL  /  %d issues require revision:" % issues.size())
		for i in issues.size(): lines.append("ERROR %02d  /  %s" % [i+1,issues[i]])
		lines.append("NEXT  /  Correct the listed systems, save the cartridge and run diagnostics again.")
	else:
		cart.verification_status = "DATA_VERIFIED"
		cart.data_type = DataCartridge.DataType.VERIFIED_DESIGN
		GameAudio.play_effect("verified")
		GameState.set_stage(GameState.Stage.READY_FOR_LAUNCH)
		lines.append("PASS  /  Payload, electrical systems, launcher and mission performance verified.")
		lines.append("NEXT  /  Remove the cartridge and take it to Mission Control.")
	return "\n".join(lines)

func save_sandbox_cartridge() -> String:
	if not reader.has_cartridge():return "Insert the Sandbox cartridge into this computer's reader, then save again."
	if reader.busy:return "Reader busy. Please wait, then save again."
	var cart:=reader.cartridge
	if not GameState.sandbox_design.is_empty():cart.write_spacecraft("",GameState.sandbox_design)
	cart.write_rocket({"parts":GameState.sandbox_parts.duplicate(true),"payload_type":GameState.sandbox_spacecraft})
	GameAudio.play_effect("saved")
	GameState.set_stage(GameState.Stage.PRELAUNCH_CHECK if terminal_type=="rocket" else GameState.Stage.ROCKET_DESIGN)
	SaveStore.save_now()
	return "Saved to cartridge. Exit and take it to the next workstation."
