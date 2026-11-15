extends RefCounted

const G := 9.80665
# Two serial liquid stages. Solid motors co-burn with the core until burnout.
static func stage() -> Dictionary:
	return {"dry":0.0,"fuel":0.0,"thrust":0.0,"flow":0.0,"engines":[],"tanks":[],"diameter":0.0}

static func evaluate(parts: Array, craft: Dictionary, mission: Dictionary) -> Dictionary:
	var stages := [stage(),stage()]
	var boosters: Array = []
	var errors: Array[String] = preload("res://scripts/gameplay/rocket_assembly_rules.gd").validate(parts)
	var adapter := 0.0
	var fairing := 0.0
	var upper_limit := 0.0
	var joint_width := 0.0
	var cost := 0
	var separation := false
	var has_upper := parts.any(func(part): return int(part.get("stage",0))==1 and part.category in ["ENGINES","FUEL TANKS"])
	for p in parts:
		var index := clampi(int(p.get("stage",0)),0,1)
		if p.category in ["FAIRINGS","PAYLOAD"]: index=int(has_upper)
		if p.category in ["INTERSTAGES","SEPARATION"]: index=0
		var s: Dictionary = stages[index]
		cost += p.cost
		if p.category=="BOOSTERS":
			boosters.append(p)
			continue
		s.dry += p.get("dry_kg",p.mass*1000)
		match p.category:
			"ENGINES":
				s.engines.append(p.get("fuel",""))
				s.thrust += p.get("thrust_kn",0)*1000
				s.flow += p.get("thrust_kn",0)*1000/(G*maxf(p.get("isp",1),1))
				if p.get("vacuum",false) and int(p.get("stage",0))==0: _issue(errors,"Vacuum engine on core")
			"FUEL TANKS":
				s.tanks.append(p.get("fuel",""))
				s.fuel += p.get("propellant_kg",0)
				s.diameter = maxf(s.diameter,p.get("diameter_m",0))
			"PAYLOAD": adapter=maxf(adapter,p.get("payload_limit_kg",0))
			"FAIRINGS": fairing=maxf(fairing,p.get("diameter_m",0))
			"INTERSTAGES":
				upper_limit=maxf(upper_limit,p.get("upper_limit_kg",0))
				joint_width=maxf(joint_width,p.get("diameter_m",0))
			"SEPARATION": separation=true
	var load_kg: float = craft.mass_kg+mission.get("delivery_kg",0)
	for i in 2:
		var s: Dictionary = stages[i]
		if i==1 and s.dry==0: continue
		var label := "Stage 1" if i==0 else "Stage 2"
		if s.thrust==0 or s.fuel==0: _issue(errors,label+" needs an engine and a tank")
		for fuel in s.tanks+s.engines:
			if not s.tanks.has(fuel) or not s.engines.has(fuel):
				_issue(errors,label+" propellant mismatch")
		if s.tanks.size()>0 and s.tanks.any(func(f): return f!=s.tanks[0]):
			_issue(errors,label+" needs one propellant family")
	var top: Dictionary = stages[1]
	if top.dry>0 and (not separation or upper_limit<=0): _issue(errors,"Fit interstage and separation ring")
	if top.dry>0 and (top.dry+top.fuel+load_kg>upper_limit or top.diameter>joint_width): _issue(errors,"Interstage capacity exceeded")
	if adapter<load_kg: _issue(errors,"Payload adapter undersized")
	if fairing<craft.diameter_m: _issue(errors,"Fairing too narrow")
	var result := _burn(stages,boosters,load_kg)
	var target: float = mission.get("dv_target",9500)
	if result.twr<=1: _issue(errors,"Lift-off TWR must exceed 1")
	if result.dv<target: _issue(errors,"Insufficient mission dV")
	var lo := 0.0
	var hi := adapter
	for i in 17:
		var test := (lo+hi)*0.5
		var b := _burn(stages,boosters,test)
		if b.twr>1 and b.dv>=target: lo=test
		else: hi=test
	result.capacity = minf(lo,maxf(0.0,upper_limit-top.dry-top.fuel)) if top.dry>0 else lo
	for error in errors:
		if error.contains("propellant") or error.contains("needs") or error.begins_with("Fit ") or error.begins_with("Vacuum") or error=="Fairing too narrow" or top.diameter>joint_width and top.dry>0:
			result.capacity=0.0
	result.payload=load_kg
	result.errors=errors
	result.cost=cost
	result.target=target
	return result

static func _issue(errors: Array[String], issue: String) -> void:
	if not errors.has(issue): errors.append(issue)

static func _burn(stages: Array, boosters: Array, payload: float) -> Dictionary:
	var mass := payload
	for s in stages: mass+=s.dry+s.fuel
	var times: Array[float] = []
	var core: Dictionary = stages[0]
	var fuel: float = core.fuel
	var thrust := float(core.thrust) if fuel>0 else 0.0
	for b in boosters:
		mass+=b.mass*1000
		thrust+=b.thrust_kn*1000
		var time := float(b.burn_s)
		if not times.has(time): times.append(time)
	if core.flow>0 and fuel>0: times.append(fuel/core.flow)
	times.sort()
	var launch_mass := mass
	var dv := 0.0
	var now := 0.0
	for end in times:
		var dt := end-now
		if dt<=0: continue
		var firing: bool = fuel>0.001 and core.flow>0
		var force := float(core.thrust) if firing else 0.0
		var flow := float(core.flow) if firing else 0.0
		for b in boosters:
			if b.burn_s>now:
				force+=b.thrust_kn*1000
				flow+=b.propellant_kg/b.burn_s
		var final_mass := maxf(0.001,mass-flow*dt)
		if flow>0: dv+=force/flow*log(mass/final_mass)
		mass=final_mass
		if firing: fuel=maxf(0,fuel-core.flow*dt)
		for b in boosters:
			if is_equal_approx(b.burn_s,end): mass-=b.dry_kg
		now=end
	var upper: Dictionary=stages[1]
	if upper.thrust>0 and upper.fuel>0:
		var top_mass: float=payload+upper.dry+upper.fuel
		dv+=upper.thrust/upper.flow*log(top_mass/(top_mass-upper.fuel))
	return {"mass":launch_mass,"thrust":thrust/1000,"twr":thrust/maxf(1,launch_mass*G),"dv":dv}
