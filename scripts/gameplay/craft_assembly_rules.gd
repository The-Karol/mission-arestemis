extends RefCounted
static var by_id:Dictionary={}
static func catalog() -> void:
	if not by_id.is_empty():return
	for part in JSON.parse_string(FileAccess.get_file_as_string("res://data/spacecraft_components.json")):by_id[part.id]=part
static func addition_error(kind:String,ids:Array,p:Dictionary) -> String:
	if ids.size()>=24:return "Equipment bay full (24 modules). Remove a fitted module first."
	var count:=ids.count(p.id)
	var repeat_limit:=2 if p.get("battery_kwh",0)>0 or p.get("storage_tb",0)>0 or "solar" in str(p.model) else 1
	if count>=repeat_limit:return "%s: maximum %d fitted. Choose another module or remove one."%[p.name,repeat_limit]
	var category_count:=0
	var solar_count:=0
	catalog()
	for id in ids:
		var installed:Dictionary=by_id.get(id,{})
		if installed.get("category","")==p.category:category_count+=1
		if "solar" in str(installed.get("model","")):solar_count+=1
	if "solar" in str(p.model) and solar_count>=2:return "Both solar-array mounting points are occupied."
	var cap:int={"Power":5,"Science":6,"Storage":2,"Thermal":2,"Propulsion":2,"Communications":2,"Computing":2,"Navigation":3,"Cargo":3,"Docking":3}.get(p.category,3)
	if category_count>=cap:return "%s bay full (%d modules). Remove a fitted module first."%[p.category,cap]
	return ""
static func validate(kind:String,ids:Array) -> Array[String]:
	var errors:Array[String]=[]
	var accepted:Array=[]
	catalog()
	for id in ids:
		if not by_id.has(id):
			errors.append("Unknown spacecraft module: "+str(id))
			continue
		var issue:=addition_error(kind,accepted,by_id[id])
		if not issue.is_empty():errors.append(issue)
		accepted.append(id)
	return errors
