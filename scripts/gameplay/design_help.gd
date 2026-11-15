extends RefCounted
const CATEGORIES := {
"ENGINES":"Produces thrust. Stage 1 needs a sea-level engine; vacuum engines suit Stage 2.",
"FUEL TANKS":"Stores propellant. Match its fuel to the engine on the SAME stage.",
"BOOSTERS":"Side-mounted motors that add lift-off thrust. Four attachment points are available.",
"INTERSTAGES":"Connects stages and supports the upper stage's mass and diameter.",
"SEPARATION":"Disconnects the spent stage. Choose a light, redundant or heavy-duty mechanism.",
"FAIRINGS":"Protects the payload in the atmosphere. Its diameter must fit the spacecraft.",
"AVIONICS":"Flight computers and sensors guide the rocket and report its condition.",
"PAYLOAD":"Adapter that supports the spacecraft AND its delivery system.",
"Power":"Generates electricity, stores it in batteries and routes it through a PCDU.",
"Computing":"Controls the spacecraft. Choose computing capacity and reliability for the mission.",
"Navigation":"Measures position and pointing, or controls spacecraft orientation.",
"Communications":"Sends commands and measurements. Deep-space missions need a suitable radio link.",
"Science":"Mission instruments. Match their measurement capabilities to the checklist.",
"Storage":"Stores measurements or cargo. Higher capacity usually adds mass.",
"Propulsion":"Provides in-space maneuvers. Compare propellant, thrust and reserves.",
"Thermal":"Keeps equipment within its operating temperature using heaters or radiators.",
"Cargo":"Carries supplies or deliverable propellant. Cargo mass counts against rocket capacity.",
"Docking":"Sensors and mechanisms needed to approach and connect to a target."
}
const METRICS := {
"Mass":"Total lift-off mass: structure, propellant and the spacecraft with its delivery system.",
"Thrust":"Force produced by firing engines and boosters, in kilonewtons. More thrust lifts more mass.",
"TWR":"Thrust-to-weight ratio = thrust / weight. It must be greater than 1 at lift-off.",
"dV":"Delta-v is the available change in velocity. The first number must reach the mission target.",
"Payload":"Spacecraft plus delivery-system mass / the rocket's calculated payload capacity.",
"Orbit":"Target flight path from the mission brief. Altitude alone is not enough: the launcher also needs sufficient speed."
}
const CAPABILITIES:Dictionary={"ELEMENTAL":"Rock chemistry","MINERAL":"Mineral analysis","IMAGING":"Camera images","DRILL":"Drill and samples","AUTONOMY":"Autonomous navigation","COMM":"Radio link","HYDROGEN":"Hydrogen detection","VOLATILES":"Water and volatiles","CORONAGRAPHY":"Planet imaging","SPECTRA":"Spectroscopy","FINE_GUIDANCE":"Fine guidance","POINTING":"Precise pointing","ATTITUDE":"Attitude control","STORAGE":"Science data storage","DEEP_RADIO":"Deep-space radio","ANTENNA":"Antenna","WIDE_FIELD":"Wide-field optics","NEAR_IR":"Infrared imaging","DOWNLINK":"Science downlink","COMPOSITION":"Surface composition","PROPULSION":"Maneuver engine","DUST":"Dust sampling","CARGO_ENGINE":"Cargo engine","DOCKING_SENSORS":"Docking sensors","DOCKING_COMPUTER":"Docking computer","ATMOSPHERIC_SPECTRA":"Atmosphere spectra","THERMAL":"Thermal control","ORBIT_FIX":"Orbit determination","CLOCK":"Atomic clock","NAV_BROADCAST":"Navigation signal","NAV_ARRAY":"Navigation antenna"}
static func capability(tag:String) -> String:return CAPABILITIES.get(tag,tag.replace("_"," ").capitalize())
static func category(key: String) -> String:return CATEGORIES.get(key,"Select a system and compare its ratings.")
static func clean(text: String) -> String:
	var result:=text
	var replacements:Dictionary={"Δv":"dV","ΔV":"dV","Δ":"Delta ","Ø":"diameter ","≥":">=","≤":"<=","²":"^2","³":"^3","→":"->","←":"<-","✓":"OK","○":"-","•":"-","±":"+/-","≈":"~","°":" deg","×":" x ","µ":"micro","—":"-","–":"-","’":"'","…":"..."}
	for key in replacements:result=result.replace(key,replacements[key])
	for i in 10:result=result.replace("₀₁₂₃₄₅₆₇₈₉".substr(i,1),str(i))
	return result
static func details(p: Dictionary) -> String:
	var special:Dictionary={
		"A2.1":"Low-power basic computer for simple control; limited processing and radiation tolerance.",
		"A2.2":"Radiation-hardened computer for long exposure; more robust than Basic, but heavier and more power-hungry.",
		"A2.3":"High processing capacity for autonomy and onboard images; highest electrical demand of the computers.",
		"A3.1":"Uses the Sun for coarse orientation; low power, lower precision than a star tracker.",
		"A3.2":"Tracks stars for fine pointing; much more precise than a Sun sensor.",
		"A3.3":"Small wheel for gentle attitude control; lower power and torque than Heavy.",
		"A3.4":"More torque and momentum for heavier craft; higher peak power than Small.",
		"A3.5":"Measures motion and rotation internally; complements external pointing sensors.",
		"A3.6":"GNSS position fixes near Earth; not a primary navigation source for deep space.",
		"B1.1":"Multispectral survey imager with about 30 m ground resolution; less data than the high-resolution camera.",
		"B1.2":"About 3-5 m ground resolution; sharper images require more power, storage and pointing stability.",
		"D1.1":"Low-power mapping and navigation context; lower detail and data rate than the long-range camera.",
		"D1.2":"High-detail observations at long range; demands more pointing accuracy and storage.",
		"F1.4":"Zoomed surface context from the rover mast; helps interpret nearby geological targets.",
		"F2.6":"Simple lunar surface context camera; low power, without the mast zoom package.",
		"F1.7":"Stores up to 20 sample tubes; adds sample capacity instead of making measurements.",
		"F3.2":"Constant radioisotope power, including darkness; lower electrical output than large solar arrays.",
		"E3":"Mid-infrared observations at longer wavelengths than Near-IR; requires active cooling.",
		"E6":"Blocks bright starlight to reveal faint planets; needs very precise pointing.",

		"sep_standard":"Light and economical; a single release mechanism. Best when low mass matters.",
		"sep_redundant":"Backup release mechanism: higher reliability than Standard, at the cost of extra mass.",
		"sep_heavy":"Heavy-duty pneumatic release for large stage interfaces; the heaviest separation option.",
		"avionics":"Standard flight computer: lighter and cheaper than the redundant package.",
		"avionics_redundant":"Backup flight-control electronics improve reliability at extra mass and cost."
	}
	var description:String=special.get(p.id,"")
	var facts:Array[String]=["Mass: %.1f kg" % float(p.get("mass_kg",p.get("dry_kg",0)))]
	for metric in [["thrust_kn","Thrust: %.1f kN"],["isp","Efficiency: %.0f s Isp"],["propellant_kg","Propellant: %.0f kg"],["fuel","Fuel: %s"],["diameter_m","Diameter: %.2f m"],["payload_limit_kg","Payload rating: %.0f kg"],["upper_limit_kg","Upper-stage rating: %.0f kg"],["generation_w","Generation: %.0f W"],["load_w","Power use: %.0f W"],["battery_kwh","Battery: %.2f kWh"],["storage_tb","Storage: %.2f TB"],["pcdu_w","Distribution rating: %.0f W"],["burn_s","Burn duration: %.0f s"]]:
		if p.has(metric[0]) and (p[metric[0]] is String or float(p[metric[0]])!=0):
			facts.append(metric[1]%p[metric[0]])
	var english:=RegEx.new()
	english.compile("[А-Яа-яЁё]")
	var feature_count:=0
	for key in p.get("specs",{}):
		var value:=str(p.specs[key]).get_slice(" —",0)
		if english.search(str(key)+value)==null and key in ["Reliability","Resolution","Data rate","Accuracy","Range","Field of view","Temperature","Capacity","Processing","Radiation tolerance","Cross-axis accuracy","Accuracy near Earth","Ground resolution","Data generation","Timing stability","Measures","Detects","Function","Best for","Wavelength","Pointing requirement","Requires","RF output"] and feature_count<2:
			facts.append(str(key)+": "+value)
			feature_count+=1
	if description.is_empty():
		description=category(p.category)
		if p.get("generation_w",0)>0:description="Generates %.0f W. Compare output and mass; generation must cover the full electrical load."%p.generation_w
		elif p.get("battery_kwh",0)>0:description="Stores %.1f kWh for shadow periods. More reserve adds mass; a battery does not generate electricity."%p.battery_kwh
		elif p.get("pcdu_w",0)>0:description="Routes up to %.0f W to the equipment. A larger PCDU handles a higher load but does not generate power."%p.pcdu_w
		elif p.get("storage_tb",0)>0:description="Stores %.2f TB of observations. Larger storage supports longer surveys before downlink."%p.storage_tb
		if p.get("vacuum",false):description="Vacuum nozzle: efficient after ascent; unsuitable for lift-off."
		elif p.category=="ENGINES":description="Sea-level engine for lift-off. Compare fuel, thrust and efficiency."
		elif p.category=="FUEL TANKS":description="Choose this tank's capacity and fuel to match the engine and stage mass."
		elif p.category=="BOOSTERS":description="Solid motor: extra lift-off thrust for %.0f seconds. Compare burn duration, thrust and loaded mass."%p.get("burn_s",0)
		elif p.category=="Science":description="Measures "+", ".join(p.get("capabilities",[])).replace("_"," ").to_lower()+". Compare its power use and mass with the mission's other instruments."
	return clean(p.name+"\n"+description+"\n"+" | ".join(facts))

static func minimums(m: Dictionary) -> Dictionary:
	return {"battery": {"M02":5.0,"M03":5.0,"M04":5.0,"M07":5.0}.get(m.get("code",""),1.0),
	"storage":{"M01":0.02,"M02":0.01,"M03":0.25,"M04":1.0,"M05":0.05,"M06":0.1,"M07":0.02,"M08":0.5,"M09":1.0,"M10":0.01}.get(m.get("code",""),0.01)}

static func repair(issue:String,craft:Dictionary,mission:Dictionary) -> String:
	var tag:=issue.to_upper().replace(" ","_")
	if tag in mission.get("required",[]):
		var choices:Array[String]=[]
		for part in JSON.parse_string(FileAccess.get_file_as_string("res://data/spacecraft_components.json")):
			if part.family in ["Common",craft.type] and tag in part.get("capabilities",[]):choices.append(part.name+" ("+part.category+")")
		return "Missing "+capability(tag).to_lower()+". Open Spacecraft Design and fit "+(" or ".join(choices.slice(0,2)) if not choices.is_empty() else "a compatible mission module")+"."
	if issue=="power deficit":
		return "Not enough electricity: %.0f W generated, %.0f W required. At Spacecraft Design > Power, fit a stronger solar array or power source."%[craft.generation_w,craft.load_w]
	if issue=="power distribution":
		return "Power routing is too small: %.0f W PCDU, %.0f W load. At Spacecraft Design > Power, fit a higher-rated PCDU."%[craft.pcdu_w,craft.load_w]
	if issue.begins_with("battery"):
		return "Battery reserve is %.1f kWh; this mission needs at least %.1f kWh. At Spacecraft Design > Power, add battery capacity."%[craft.battery_kwh,minimums(mission).battery]
	if issue.begins_with("storage"):
		return "Science memory is %.2f TB; this mission needs at least %.2f TB. At Spacecraft Design > Storage, fit a Science Data Recorder."%[craft.storage_tb,minimums(mission).storage]
	if issue.contains("800 kg"):
		return "Deliverable propellant is below 800 kg. At Spacecraft Design > Cargo, add a fuel cargo module."
	return "Spacecraft equipment: "+issue+" Return to Spacecraft Design and replace the indicated module."
