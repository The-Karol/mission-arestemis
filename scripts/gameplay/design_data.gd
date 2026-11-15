extends RefCounted

# GAME bus masses and packed diameters include chassis, harness and fixed mechanisms.
const BUSES := {
	"Rover":[460.0,2.35,"rover_base"],
	"Space Telescope":[980.0,2.8,"space_telescope_base"],
	"Interplanetary Probe":[410.0,1.85,"interplanetary_probe_base"],
	"Automated Cargo Spacecraft":[2650.0,2.7,"cargo_spacecraft_base"],
	"Satellite":[320.0,1.55,"satellite_base"]
}
static var modules: Array
static var by_id := {}

static func catalog() -> Array:
	if by_id.is_empty():
		modules = JSON.parse_string(FileAccess.get_file_as_string("res://data/spacecraft_components.json"))
		for p in modules: by_id[p.id] = p
	return modules

static func texture(key: String) -> Texture2D:
	return load("res://assets/ui/plates/"+key+".png") as Texture2D

static func illustration(parent: Node, key: String, height: float, color: Color) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture(key)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size.y = height
	image.modulate = color
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

static func craft(kind: String, ids: Array) -> Dictionary:
	catalog()
	var bus: Array = BUSES[kind]
	var d := {"type":kind,"module_ids":[],"components":[],"mass_kg":bus[0],"diameter_m":bus[1],"load_w":24.0,"generation_w":0.0,"battery_kwh":0.0,"storage_tb":0.0,"cargo_kg":0.0,"maneuver_kg":0.0,"pcdu_w":0.0,"capabilities":[],"cost":0}
	for id in ids:
		var p: Dictionary = by_id.get(id,{})
		if p.is_empty() or p.family not in ["Common",kind] and not (p.category=="Storage" and p.id in ["E9","E10"]): continue
		d.module_ids.append(id)
		d.components.append(p.name)
		for tag in p.get("capabilities",[]):
			if tag not in d.capabilities: d.capabilities.append(tag)
		for k in ["mass_kg","load_w","generation_w","battery_kwh","storage_tb","cargo_kg","maneuver_kg","cost"]:
			d[k] += p.get(k,0)
		d.pcdu_w += p.get("pcdu_w",0.0)
	d.mass_kg += d.cargo_kg+d.maneuver_kg
	return d

static func missing_systems(d: Dictionary, mission: Dictionary) -> Array[String]:
	var missing: Array[String]=[]
	for requirement in mission.get("required",[]):
		if requirement not in d.capabilities: missing.append(str(requirement).replace("_"," ").to_lower())
	if d.generation_w<d.load_w: missing.append("power deficit")
	if d.pcdu_w<d.load_w: missing.append("power distribution")
	var minimums:=preload("res://scripts/gameplay/design_help.gd").minimums(mission)
	if d.battery_kwh<minimums.battery: missing.append("battery reserve below %.1f kWh" % minimums.battery)
	if d.storage_tb<minimums.storage: missing.append("storage below %.2f TB" % minimums.storage)
	missing.append_array(preload("res://scripts/gameplay/craft_assembly_rules.gd").validate(d.type,d.module_ids))
	if mission.get("code","")=="M07" and d.cargo_kg*0.99<800: missing.append("800 kg deliverable fuel")
	return missing

static func payload_design(terminal: Node) -> Dictionary:
	var m := GameState.mission()
	var kind := GameState.sandbox_spacecraft if GameState.sandbox else str(m.get("spacecraft_type","Satellite"))
	var saved: Dictionary = GameState.sandbox_design if GameState.sandbox else {}
	if not GameState.sandbox and terminal.reader.has_cartridge():
		saved = terminal.reader.cartridge.spacecraft_design
	if terminal.terminal_type=="spacecraft" and GameState.editor_drafts.has("spacecraft"):
		saved=GameState.editor_drafts.spacecraft
		kind=saved.type
	return craft(kind,saved.get("module_ids",[]))

static func part_help(p: Dictionary) -> String:
	return preload("res://scripts/gameplay/design_help.gd").details(p)

static func mission_plate(parent: Node, m: Dictionary, height: float, tint: Color) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var drawing := illustration(row,BUSES[m.spacecraft_type][2],height,tint)
	drawing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := SpaceUI.column(row,3)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SpaceUI.label(side,"%s   /   FLIGHT PROFILE" % m.code,14,tint)
	SpaceUI.label(side,m.recommended_orbit,18,tint,true)
	var pick: String = m.recommended[0]
	catalog()
	var instrument := illustration(side,by_id[pick].model,height*0.42,tint)
	instrument.tooltip_text = by_id[pick].name
	SpaceUI.label(side,by_id[pick].name,13,tint,true)
