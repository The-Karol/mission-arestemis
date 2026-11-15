extends RefCounted

# The workshop has two serial stages and four physical strap-on attachment points.
const LIMITS := {"ENGINES":1,"FUEL TANKS":3,"BOOSTERS":4,"INTERSTAGES":1,"SEPARATION":1,"FAIRINGS":1,"AVIONICS":1,"PAYLOAD":1}
static func slot(part: Dictionary) -> String:
	var category: String=part.get("category","")
	return category+":"+str(clampi(int(part.get("stage",0)),0,1)) if category in ["ENGINES","FUEL TANKS","AVIONICS"] else category

static func addition_error(parts: Array, part: Dictionary) -> String:
	var key:=slot(part)
	var count:=0
	for installed in parts:
		if slot(installed)==key:count+=1
	var limit:int=LIMITS.get(part.get("category",""),1)
	if count>=limit:
		return "Mounts full: %s  /  %d / %d. Remove a fitted part first." % [part.category.to_lower(),count,limit]
	return ""

static func validate(parts: Array) -> Array[String]:
	var checked: Array=[]
	var errors: Array[String]=[]
	for part in parts:
		var issue:=addition_error(checked,part)
		if not issue.is_empty() and not errors.has(issue):errors.append(issue)
		checked.append(part)
	return errors
