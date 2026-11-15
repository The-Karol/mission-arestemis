extends RefCounted
const KEY := "arestemis_workshop_v1"
const PATH := "user://workshop_v1.json"
const Design = preload("res://scripts/gameplay/design_data.gd")

static func all() -> Array:
	var text:=""
	if OS.has_feature("web"):
		text=str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('"+KEY+"')||'';}catch(e){return '';}})()",true))
	elif FileAccess.file_exists(PATH):text=FileAccess.get_file_as_string(PATH)
	if text.is_empty():return []
	var parser:=JSON.new()
	if parser.parse(text)!=OK:return []
	var value:Variant=parser.data
	return value.filter(func(entry):return validate(entry).is_empty()) if value is Array else []

static func write(entries:Array) -> bool:
	var text:=JSON.stringify(entries)
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(()=>{try{localStorage.setItem('"+KEY+"',"+JSON.stringify(text)+");return true;}catch(e){return false;}})()",true))
	var file:=FileAccess.open(PATH,FileAccess.WRITE)
	if file==null:return false
	file.store_string(text)
	return true

static func pack(title:String,parts:Array,craft:Dictionary,mission:Dictionary) -> Dictionary:
	var slots:Array=[]
	for p in parts:slots.append({"id":str(p.id),"stage":int(p.get("stage",0))})
	return {"format":"mission-arestemis-rocket","version":1,"name":title.strip_edges().left(64),"mission":str(mission.get("id","")),"parts":slots,"spacecraft":{"type":str(craft.type),"module_ids":craft.get("module_ids",[]).duplicate()}}

static func validate(value:Variant) -> String:
	if not value is Dictionary:return "This file is not a rocket blueprint."
	if value.get("format","")!="mission-arestemis-rocket" or value.get("version",0)!=1:return "Unsupported blueprint format or version."
	if not value.get("name") is String or value.name.length()>64 or value.name.strip_edges().is_empty():return "Enter a name of 1 to 64 characters."
	for character in value.name:
		if character.unicode_at(0)<32 or not SpaceUI.FONT.has_char(character.unicode_at(0)):return "The rocket name contains a character this font cannot display."
	if not value.get("parts") is Array or value.parts.is_empty() or value.parts.size()>32:return "Invalid rocket component count."
	var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	var assembled:Array=[]
	for slot in value.parts:
		if not slot is Dictionary or not slot.get("id") is String or not (slot.get("stage") is float or slot.get("stage") is int) or (slot.get("stage")!=0 and slot.get("stage")!=1):return "Invalid rocket component."
		var found:=cat.filter(func(p):return p.id==slot.id)
		if found.is_empty():return "Unknown rocket component: "+slot.id
		var p:Dictionary=found[0].duplicate(true)
		p.stage=int(slot.stage)
		assembled.append(p)
	if not preload("res://scripts/gameplay/rocket_assembly_rules.gd").validate(assembled).is_empty():return "The blueprint exceeds the assembly limits."
	var craft:Variant=value.get("spacecraft")
	if not craft is Dictionary or not craft.get("type") is String or not Design.BUSES.has(craft.type):return "Unknown spacecraft type."
	if not craft.get("module_ids") is Array or craft.module_ids.size()>128:return "Invalid spacecraft components."
	Design.catalog()
	for id in craft.module_ids:
		if not id is String or not Design.by_id.has(id):return "Unknown spacecraft component."
	if Design.craft(craft.type,craft.module_ids).module_ids.size()!=craft.module_ids.size():return "A component does not fit this spacecraft type."
	var issues:=preload("res://scripts/gameplay/craft_assembly_rules.gd").validate(craft.type,craft.module_ids)
	if not issues.is_empty():return "Spacecraft components exceed the mounting limits."
	return ""

static func save(entry:Dictionary) -> String:
	var issue:=validate(entry)
	if not issue.is_empty():return issue
	var entries:=all()
	if entries.size()>=100:return "Workshop full (100 rockets). Remove an old blueprint first."
	# Keep only the public blueprint schema. Never import paths, scripts or statistics.
	var clean:=pack(entry.name,parts(entry),Design.craft(entry.spacecraft.type,entry.spacecraft.module_ids),{"id":str(entry.get("mission",""))})
	entries.append(clean)
	return "" if write(entries) else "Could not save. Browser storage may be full or unavailable."

static func parts(entry:Dictionary) -> Array:
	var cat:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/rocket_components.json"))
	var result:Array=[]
	for slot in entry.parts:
		var p:Dictionary=cat.filter(func(p):return p.id==slot.id)[0].duplicate(true)
		p.stage=int(slot.stage)
		result.append(p)
	return result
