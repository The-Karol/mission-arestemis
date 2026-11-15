extends Control
## A bounded, mission-specific cinematic. Display times are edited mission elapsed
## times; the map is illustrative, not a numerical orbital propagation solver.
signal finished
const MAX_DURATION := 184.0
static var flight_sky:Sky
const Design = preload("res://scripts/gameplay/design_data.gd")
var mission: Dictionary
var craft: Dictionary
var parts: Array
var performance: Dictionary
var elapsed := 0.0
var countdown_time := 12.0
var phase := -1
var view: SubViewport
var world: Node3D
var camera: Camera3D
var rocket: Node3D
var core: Node3D
var upper: Node3D
var nose: Node3D
var exhaust: Node3D
var upper_exhaust: Node3D
var pad: Node3D
var actor: Node3D
var planet: MeshInstance3D
var payload: Node3D
var surface: Node3D
var panels: Array[Node3D]=[]
var debris: Array[Node3D]=[]
var vapor: CPUParticles3D
var orbit: Node3D
var heading: Label
var subtitle: Label
var telemetry: Label
var fade: ColorRect
var result: Control
var countdown: AudioStreamPlayer
var rumble: AudioStreamPlayer
var report: Dictionary={}
var base_height:=2.0
var two_stage:=false
var rocket_height:=18.0
var lander:Node3D
var descent_exhaust:Node3D
var drill_arm:Node3D
var scan_ring:MeshInstance3D
var broadcast:Control
var crt:ColorRect
var smoke:CPUParticles3D
var body_model:Node3D
var comet_tail:CPUParticles3D
var ignition_light:OmniLight3D
var stage_shots := [0,1,4,2,3,5,6,7,8,9]
var cuts := [22.0,38.0,48.0,60.0,78.0,103.0,124.0,142.0]
var _clock_usec:=0
var deterministic_clock:=false
var shot_index := -1
var acceleration := 1.0
var engine_bottom := [-1.3,-1.3]

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	GameAudio.ambience("")
	GameAudio.menu_music(true)
	var container:=SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch=true
	add_child(container)
	view=SubViewport.new()
	view.size=Vector2i(960,720)
	view.own_world_3d=true
	container.add_child(view)
	world=Node3D.new()
	view.add_child(world)
	_build_world()
	SettingsStore.apply_view(view)
	SettingsStore.apply_world(world)
	orbit=preload("res://scripts/gameplay/orbit_tracking.gd").new()
	orbit.mission=mission
	orbit.camera=camera
	world.add_child(orbit)
	orbit.hide()
	for top in [true,false]:
		var bar:=ColorRect.new()
		bar.color=Color(0.015,0.022,0.03,0.94)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_bottom=86 if top else 0
		bar.offset_top=0 if top else -104
		bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(bar)
	heading=SpaceUI.label(self,"",24,Color("f5d3a0"))
	heading.position=Vector2(32,18)
	telemetry=SpaceUI.label(self,"",15,Color("94c8d3"))
	telemetry.position=Vector2(32,51)
	subtitle=SpaceUI.label(self,"",20,Color("eee0ca"),true)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left=32
	subtitle.offset_right=-32
	subtitle.offset_top=-85
	subtitle.offset_bottom=-18
	fade=ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color=Color.BLACK
	fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	countdown=AudioStreamPlayer.new()
	countdown.bus=&"SFX"
	countdown.stream=GameAudio.CLIPS.countdown
	countdown.volume_db=-10
	add_child(countdown)
	countdown_time=clampf(countdown.stream.get_length()+1,12,30)
	countdown.play()
	rumble=AudioStreamPlayer.new()
	rumble.bus=&"SFX"
	var bed:AudioStream=preload("res://assets/audio/sfx/world/launch_rumble.wav").duplicate()
	if bed is AudioStreamWAV:
		bed.loop_mode=AudioStreamWAV.LOOP_FORWARD
		bed.loop_begin=0
		bed.loop_end=int(bed.get_length()*bed.mix_rate)
	if bed is AudioStreamOggVorbis:bed.loop=true
	rumble.stream=bed
	rumble.volume_db=-60
	add_child(rumble)
	rumble.play()
	_make_broadcast()
	_clock_usec=Time.get_ticks_usec()
	_update(0)

func _node(parent:Node3D,at:=Vector3.ZERO) -> Node3D:
	var n:=Node3D.new()
	parent.add_child(n)
	n.position=at
	return n

func _beam(parent:Node3D,a:Vector3,b:Vector3,width:float,color:Color) -> void:
	var mesh:=SpaceVisuals.box(parent,"Structural beam",Vector3(width,width,a.distance_to(b)),(a+b)*.5,color)
	mesh.look_at_from_position(mesh.global_position,parent.to_global(b),Vector3.FORWARD if absf((b-a).normalized().dot(Vector3.UP))>.99 else Vector3.UP)

func _sphere(parent:Node3D,radius:float,at:Vector3,color:Color) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	var s:=SphereMesh.new()
	s.radius=radius
	s.height=radius*2
	s.radial_segments=48
	s.rings=24
	m.mesh=s
	m.material_override=SpaceVisuals.material(color)
	parent.add_child(m)
	m.position=at
	return m

func _build_world() -> void:
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_SKY
	# Reuse the generated sky across launches; radiance cubemaps stay bounded.
	if flight_sky==null:
		flight_sky=Sky.new()
		var sky_material:=ShaderMaterial.new()
		sky_material.shader=preload("res://materials/flight_sky.gdshader")
		flight_sky.sky_material=sky_material
	flight_sky.sky_material.set_shader_parameter("space_blend",0.0)
	env.environment.sky=flight_sky
	env.environment.background_color=Color("6e91ac")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("7791ad")
	env.environment.ambient_light_energy=0.65
	world.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-28,-38,0)
	sun.light_color=Color("ffdcaf")
	sun.light_energy=1.7
	sun.shadow_enabled=true
	world.add_child(sun)
	camera=Camera3D.new()
	camera.far=4000
	world.add_child(camera)
	camera.current=true
	pad=_node(world)
	SpaceVisuals.box(pad,"Coastal ground",Vector3(1800,1,1800),Vector3(0,-1,0),Color("62695f"))
	var foundation:=SpaceVisuals.model(pad,"launch/launch_pad_base",Vector3.ZERO,0,24,false)
	var foundation_height:float=foundation.get_meta("model_bounds").size.y
	var mount:=SpaceVisuals.model(pad,"launch/launch_mount",Vector3(0,foundation_height,0),0,5,false)
	base_height=foundation_height+float(mount.get_meta("model_bounds").size.y)+1.3
	for x in [-6.2,-3.8]:
		for z in [-1.2,1.2]:_beam(pad,Vector3(x,0,z),Vector3(x,23,z),.14,Color("47565a"))
	for y in range(0,21,3):
		for z in [-1.2,1.2]:_beam(pad,Vector3(-6.2,y,z),Vector3(-3.8,y+3,z),.07,Color("78817d"))
	SpaceVisuals.box(pad,"Apron",Vector3(60,.05,80),Vector3(0,-.42,20),Color("777a73"))
	for x in [-9,9]:
		SpaceVisuals.box(pad,"Access stripe",Vector3(.18,.06,70),Vector3(x,-.37,25),Color("ccac63"))
	for i in 10:
		SpaceVisuals.box(pad,"Flame trench slat",Vector3(6,.15,.18),Vector3(0,0,4+i*.4),Color("454b4d"))
	for y in range(2,23,3):
		SpaceVisuals.box(pad,"Tower platform",Vector3(4,.22,4),Vector3(-5,y,0),Color("888e87"))
		SpaceVisuals.box(pad,"Service arm",Vector3(4,.3,.4),Vector3(-3,y,0),Color("c7b794"))
	rocket=_node(world,Vector3(0,2,0))
	core=_node(rocket)
	upper=_node(rocket)
	nose=_node(rocket)
	var heights:=[0.0,0.0]
	for stage in 2:
		var root:Node3D=core if stage==0 else upper
		var tanks:=parts.filter(func(p):return p.category=="FUEL TANKS" and int(p.get("stage",0))==stage)
		var h:=0.0
		for p in tanks:
			var body:=SpaceVisuals.model(root,"rocket/stages/first_stage_body" if stage==0 else "rocket/stages/second_stage_body",Vector3(0,h,0),0,2.4,false)
			h+=float(body.get_meta("model_bounds").size.y)
		if h==0 and stage==0:
			SpaceVisuals.model(root,"rocket/stages/first_stage_body",Vector3.ZERO,0,2.4,false)
			h=8
		heights[stage]=h
		var engines:=parts.filter(func(p):return p.category=="ENGINES" and int(p.get("stage",0))==stage)
		if not engines.is_empty():
			var engine_name:String={"engine_s":"rutherford","engine_m":"merlin_1d","engine_l":"rs25","engine_vac_s":"rl10c2","engine_vac_m":"be3u","engine_vac_l":"be4","be3u":"be3u","be4":"be4","rl10":"rl10c2"}.get(str(engines[0].id),"merlin_1d")
			var engine:=SpaceVisuals.model(root,"rocket/engines/"+engine_name,Vector3.ZERO,0,1.8,false)
			var engine_h:float=engine.get_meta("model_bounds").size.y
			engine.position.y=-engine_h+.12
			engine_bottom[stage]=engine.position.y
			engine.name="VisibleEngine"
	upper.position.y=heights[0]+1
	var has_upper:bool=heights[1]>0
	two_stage=has_upper
	rocket_height=heights[0]+heights[1]+5
	base_height+=maxf(0,-engine_bottom[0]-1.3)
	rocket.position.y=base_height
	if has_upper:SpaceVisuals.model(core,"rocket/stages/interstage",Vector3(0,heights[0],0),0,2.4,false)
	nose.position.y=heights[0]+(1+heights[1] if has_upper else 0)
	SpaceVisuals.model(nose,"rocket/fairings/fairing_closed",Vector3.ZERO,0,2.7,false)
	var boosters:=parts.filter(func(p):return p.category=="BOOSTERS")
	for i in boosters.size():
		var a:=TAU*i/maxi(1,boosters.size())
		SpaceVisuals.model(core,"rocket/stages/booster_medium",Vector3(cos(a)*1.9,0,sin(a)*1.9),0,1.1,false)
	exhaust=_plume(core,Vector3(0,engine_bottom[0],0))
	exhaust.scale=Vector3(2.4,3.6,2.4)
	upper_exhaust=_plume(upper,Vector3(0,engine_bottom[1],0))
	exhaust.hide()
	upper_exhaust.hide()
	ignition_light=OmniLight3D.new()
	ignition_light.light_color=Color("ffad5b")
	ignition_light.omni_range=45
	ignition_light.light_energy=0
	rocket.add_child(ignition_light)
	smoke=_smoke(pad,Vector3(0,base_height-2,0),160,8,10)
	SpaceVisuals.model(pad,"architecture/exterior/control_building",Vector3(12,-.5,112),PI,28,false)
	SpaceVisuals.model(pad,"architecture/exterior/assembly_building",Vector3(-27,-.5,130),0,38,false)
	SpaceVisuals.model(pad,"launch/water_deluge",Vector3(4,0,0),0,5,false)
	var rng_t:=RandomNumberGenerator.new()
	rng_t.seed=75
	for i in 90:
		var at:=Vector3(rng_t.randf_range(-130,130),-.5,rng_t.randf_range(-80,180))
		if absf(at.x)<32:continue
		var height:=rng_t.randf_range(3,7)
		SpaceVisuals.box(pad,"Tree trunk",Vector3(.25,height,.25),at+Vector3.UP*height*.5,Color("504b42"))
		var tree:=_sphere(pad,height*.32,at+Vector3.UP*height*.8,Color("454f45"))
		tree.scale=Vector3(.8,1.4,.85)
	actor=_node(world,Vector3(20,0,90))
	var model:=preload("res://assets/characters/technician/technician.glb").instantiate() as Node3D
	actor.add_child(model)
	var bounds:=SpaceVisuals.bounds_of(model)
	var factor:=1.78/bounds.size.y
	model.scale*=factor
	model.position.y=-bounds.position.y*factor
	actor.rotation.y=atan2(-20.0,-90.0)
	var rig:=model.find_children("*","Skeleton3D",true,false)
	if not rig.is_empty():
		var pose:=preload("res://scripts/gameplay/crew_pose.gd").new()
		pose.role="technician"
		rig[0].add_child(pose)
		var min_foot:=INF
		for i in rig[0].get_bone_count():
			if str(rig[0].get_bone_name(i)).to_lower().contains("toe"):
				var foot:Vector3=rig[0].to_global(rig[0].get_bone_global_pose(i).origin)
				min_foot=minf(min_foot,foot.y)
		if min_foot<INF:actor.position.y+=.03-min_foot
	planet=_sphere(world,270,Vector3(0,-290,0),Color("285773"))
	var planet_mat:=ShaderMaterial.new()
	planet_mat.shader=preload("res://materials/flight_planet.gdshader")
	planet.material_override=planet_mat
	planet.hide()
	payload=_node(world)
	var path:String={"Rover":"spacecraft/rover/rover_base","Satellite":"spacecraft/satellite/satellite_base","Space Telescope":"spacecraft/telescope/space_telescope_base","Interplanetary Probe":"spacecraft/probe/interplanetary_probe_base","Automated Cargo Spacecraft":"spacecraft/cargo/cargo_spacecraft_base"}.get(str(craft.get("type","Satellite")),"spacecraft/satellite/satellite_base")
	SpaceVisuals.model(payload,path,Vector3.ZERO,0,3,false)
	Design.catalog()
	for i in mini(craft.get("module_ids",[]).size(),8):
		var p:Dictionary=Design.by_id.get(craft.module_ids[i],{})
		if p.is_empty():continue
		var a:=TAU*i/8.0
		SpaceVisuals.model(payload,"spacecraft/modules/"+str(p.model),Vector3(cos(a)*.85,1,sin(a)*.85),a,.55,false)
	for side in [-1,1]:
		var hinge:=_node(payload,Vector3(side*1.1,1,0))
		hinge.set_meta("side",side)
		SpaceVisuals.box(hinge,"Solar array",Vector3(2.8,.06,1.3),Vector3(side*1.4,0,0),Color("19345f"))
		for n in 7:SpaceVisuals.box(hinge,"Cell bus",Vector3(.018,.065,1.3),Vector3(side*(.2+n*.4),0,0),Color("8192a1"))
		panels.append(hinge)
	payload.hide()
	surface=_node(world)
	var ground_color:=Color("9b6146") if mission.get("target_body","")=="Mars" else Color("777b7c")
	SpaceVisuals.box(surface,"Regolith",Vector3(300,.5,300),Vector3(0,-.5,0),ground_color)
	var rng:=RandomNumberGenerator.new()
	rng.seed=902
	for i in 45:
		var rock:=_sphere(surface,rng.randf_range(.2,1.4),Vector3(rng.randf_range(-30,30),-.1,rng.randf_range(-35,25)),ground_color.darkened(.18))
		rock.scale=Vector3(1,.5,1.4)
	if mission.get("id","")=="lunar_ice":
		for i in 12:
			var ice:=_sphere(surface,.18,Vector3(rng.randf_range(-2,2),-.05,rng.randf_range(-2,2)),Color("afd5df"))
			ice.scale=Vector3(1,.35,1.3)
	surface.hide()
	lander=_node(world)
	SpaceVisuals.box(lander,"Descent platform",Vector3(4,.5,3.8),Vector3(0,.85,0),Color("bb9657"))
	for x in [-2,2]:
		for z in [-2,2]:
			_beam(lander,Vector3(x*.7,.8,z*.7),Vector3(x,0,z),.13,Color("a6a6a0"))
			SpaceVisuals.box(lander,"Landing foot",Vector3(.65,.09,.65),Vector3(x,0,z),Color("6d7071"))
	var ramp:=SpaceVisuals.box(lander,"Rover ramp",Vector3(1.8,.08,3),Vector3(0,.5,-3),Color("858c88"))
	ramp.rotation.x=-.35
	descent_exhaust=_plume(lander,Vector3(0,.5,0))
	descent_exhaust.scale=Vector3.ONE*.16
	lander.hide()
	drill_arm=_node(payload,Vector3(.8,.65,-.4))
	SpaceVisuals.box(drill_arm,"Instrument arm",Vector3(.1,.1,1.25),Vector3(0,0,-.6),Color("b9ad8c"))
	SpaceVisuals.box(drill_arm,"Sampling drill",Vector3(.12,.65,.12),Vector3(0,-.25,-1.2),Color("667d89"))
	drill_arm.hide()
	scan_ring=MeshInstance3D.new()
	var ring:=TorusMesh.new()
	ring.inner_radius=.92
	ring.outer_radius=1
	ring.rings=32
	ring.ring_segments=8
	scan_ring.mesh=ring
	scan_ring.material_override=SpaceVisuals.material(Color("67b6ce"),true)
	scan_ring.position=Vector3(0,.015,-2)
	surface.add_child(scan_ring)
	scan_ring.hide()
	vapor=_smoke(world,Vector3.ZERO,70,2.2,3)
	vapor.one_shot=true
	vapor.explosiveness=.95
	vapor.direction=Vector3.RIGHT
	vapor.spread=180
	vapor.gravity=Vector3.ZERO
	vapor.scale_amount_min=.15
	vapor.scale_amount_max=.5

func _plume(parent:Node3D,at:Vector3) -> Node3D:
	var root:=_node(parent,at)
	for c in [0.0,1.0]:
		var mesh:=MeshInstance3D.new()
		var shape:=CylinderMesh.new()
		shape.height=1
		shape.top_radius=1
		shape.bottom_radius=1
		shape.radial_segments=20
		shape.rings=30
		shape.cap_top=false
		shape.cap_bottom=false
		mesh.mesh=shape
		var mat:=ShaderMaterial.new()
		mat.shader=preload("res://materials/engine_plume.gdshader")
		mat.set_shader_parameter("core",c)
		mesh.material_override=mat
		mesh.custom_aabb=AABB(Vector3(-3,-16,-3),Vector3(6,17,6))
		root.add_child(mesh)
	return root

func _process(delta:float) -> void:
	if is_instance_valid(result):return
	var now:=Time.get_ticks_usec()
	var step:=delta if deterministic_clock else maxf(0,float(now-_clock_usec)/1000000.0)
	_clock_usec=now
	elapsed+=step*acceleration
	_update(delta)

func _update(_delta:float) -> void:
	var t:=maxf(0,elapsed-countdown_time)
	var index:=0
	if elapsed>=countdown_time:
		index=1
		for boundary in cuts:
			if t>=boundary:index+=1
	if index!=shot_index:
		# Apply skipped transitions in order so Space cannot leave stale state.
		for i in range(shot_index+1,index+1):
			phase=stage_shots[i]
			_enter_phase()
		shot_index=index
	ignition_light.light_energy=14.0 if phase==1 else 0.0
	fade.color.a=maxf(0,fade.color.a-_delta*1.8)
	if phase==0:
		var cut:=int(elapsed/countdown_time*4)
		camera.fov=38
		if cut==0:
			camera.position=Vector3(26,9,38)
			camera.look_at(rocket.position+Vector3.UP*rocket_height*.45)
		elif cut==1:
			camera.position=Vector3(-10,base_height+1,14)
			camera.look_at(rocket.position+Vector3.UP*3)
		elif cut==2:
			camera.fov=33
			camera.position=actor.position+Vector3(-.65,1.55,-2.5)
			camera.look_at(actor.position+Vector3(0,1.47,0))
		else:
			camera.position=Vector3(19,base_height+rocket_height+7,24)
			camera.look_at(rocket.position+Vector3.UP*rocket_height*.55)
		subtitle.text="FLIGHT CONTROLLER  /  All stations report GO. Stand clear of the pad.  T - %02d" % maxi(0,ceili(countdown_time-elapsed))
	elif phase<=3:
		camera.fov=42
		var rise:=minf(t,22)
		rocket.position=Vector3(pow(t/22,2)*15,base_height+t*t*.24,0)
		if phase in [2,3]:rocket.position=Vector3(0,55,0)
		rocket.rotation.z=-smoothstep(7,60,t)*1.2
		var aim:=rocket.position+Vector3(0,rocket_height*.55,0)
		if phase==1:
			camera.position=aim+Vector3(22,3,36) if t>10 else Vector3(25,5,40)
			camera.look_at(aim)
		elif phase==2:
			var u:=t-38
			if two_stage:
				core.position=Vector3(0,-u*1.4,0)
				core.rotation.z=u*.012
			camera.position=aim+Vector3(8,1,15)
			camera.look_at(rocket.to_global(Vector3(0,upper.position.y,0)))
			camera.position=rocket.to_global(Vector3(11,upper.position.y+1,16))
			camera.look_at(rocket.to_global(Vector3(0,upper.position.y-1,0)))
			upper_exhaust.visible=two_stage and u>2.5
		else:
			if two_stage:core.position.y=-80
			for i in debris.size():
				debris[i].position=rocket.position+Vector3((i*2-1)*(t-48)*.9,13-(t-48)*.3,0)
				debris[i].rotation.z=(i*2-1)*(t-48)*.07
			camera.position=aim+Vector3(18,5,24)
			camera.look_at(aim)
	elif phase==4:
		orbit.update_track(clampf((t-22)/16,0,1))
		if t>34:subtitle.text="First-stage burn nearing completion. Next: separation, then upper-stage insertion."
	elif phase==6:
		_update_coast(clampf((t-78)/25,0,1))
	elif phase==5:
		var u:=t-60
		payload.position=Vector3(u*.16,9,0)
		payload.rotation.y=u*.025
		rocket.position=Vector3(-5-u*.18,-4,0)
		camera.position=Vector3(10,13,20)
		camera.look_at(payload.position+Vector3.UP)
		for p in panels:p.rotation.z=float(p.get_meta("side"))*lerpf(PI/2,0,smoothstep(2,12,u))
	elif phase>=7 and phase<9:
		var u:=t-103
		_update_destination(u)
	if is_instance_valid(crt):
		var flare:=0.0
		if phase==1:
			var local_point:=camera.to_local(rocket.global_position+rocket.basis*Vector3(0,engine_bottom[0]-2,0))
			var depth:=maxf(.1,-local_point.z)
			var tangent:=tan(deg_to_rad(camera.fov)*.5)
			var flare_uv:=Vector2(.5+local_point.x/(2*depth*tangent*4/3),.5-local_point.y/(2*depth*tangent))
			crt.material.set_shader_parameter("flare_center",flare_uv)
			flare=1.6 if t<8 else .75
		crt.material.set_shader_parameter("glare",flare)
	telemetry.text="%s  /  %s  /  %s" % [str(mission.get("code","FLIGHT")),str(mission.get("target_body","Earth")).to_upper(),"EDITED FLIGHT  /  TIME COMPRESSED" if phase>=3 else "LIVE LAUNCH COVERAGE"]
	if phase==8:telemetry.text+="  /  DEBRIEF IN %02d s"%maxi(0,ceili(float(cuts[-1])-t))
	if elapsed>=countdown_time+float(cuts[-1]) and not is_instance_valid(result):
		phase=9
		_show_result()

func _enter_phase() -> void:
	fade.color.a=.8
	orbit.visible=phase==4
	rocket.visible=phase in [0,1,2,3,5]
	pad.visible=phase in [0,1]
	actor.visible=phase==0
	planet.visible=false
	_set_body("earth" if phase<6 else _destination_body())
	body_model.visible=phase in [2,3,5,6,7,8]
	payload.visible=phase in [5,6,7,8]
	var titles:=["HYPERION / FINAL COUNTDOWN","IGNITION / LIFT-OFF","MAIN ENGINE CUT-OFF / STAGE SEPARATION","FAIRING JETTISON / UPPER-STAGE BURN","PARKING ORBIT / GUIDANCE","PAYLOAD RELEASE / ARRAY DEPLOYMENT","TRANSFER / COAST","DESTINATION ACQUISITION","MISSION OPERATIONS","MISSION DEBRIEF"]
	heading.text=titles[phase]
	if phase==2 and not two_stage:heading.text="ENGINE CUT-OFF / COAST"
	var captions:=["","Tower clear. Pitch programme initiated.","Core thrust is zero. Separation confirmed. Upper-stage ignition.","Fairing released. Upper stage accelerates downrange to reach orbital speed.","Insertion complete. Vehicle and destination shown on the trajectory overview.","Orbital insertion complete. Payload released; establishing power and communications.","Long coast compressed. Mid-course correction and destination approach.","Acquiring target. Beginning the mission-specific arrival sequence.",str(mission.get("primary_objective","Mission operations in progress.")),""]
	subtitle.text=captions[phase]
	if phase==2 and not two_stage:subtitle.text="Single-stage vehicle. Engine cut-off confirmed; coasting above the atmosphere."
	if phase==1:
		countdown.stop()
		smoke.emitting=true
		exhaust.show()
		rumble.volume_db=-16
		vapor.position=Vector3(0,1,0)
		vapor.restart()
	if phase==2:
		rocket.position=Vector3(0,55,0)
		exhaust.hide()
		flight_sky.sky_material.set_shader_parameter("space_blend",1.0)
		upper_exhaust.visible=parts.any(func(p):return int(p.get("stage",0))==1)
		GameAudio.play_effect("separation",-12)
		vapor.position=rocket.to_global(Vector3(0,upper.position.y,0))
		vapor.restart()
		rumble.volume_db=-25
	if phase==3:
		nose.hide()
		for i in 2:
			var half:=_node(world)
			var shell:=SpaceVisuals.model(half,"rocket/fairings/fairing_separated",Vector3.ZERO,0,2.7,false)
			for mesh in shell.find_children("*","MeshInstance3D",true,false):
				if (i==0 and mesh.name.contains("Right")) or (i==1 and mesh.name.contains("Left")):mesh.hide()
			debris.append(half)
		GameAudio.play_effect("separation",-20)
		world.get_child(0).environment.sky.sky_material.set_shader_parameter("space_blend",1.0)
	if phase!=1:smoke.emitting=false
	if phase>=3:vapor.emitting=false
	if phase not in [1,2,3]:rumble.volume_db=-60
	if phase>=4:camera.fov=42
	if phase==5:
		upper_exhaust.hide()
		planet.position=Vector3(0,-290,0)
		GameAudio.play_effect("separation",-22)
	if phase==4:
		flight_sky.sky_material.set_shader_parameter("space_blend",1.0)
		heading.text="POWERED ASCENT / STAGING AHEAD"
		subtitle.text="Solid cyan: flown ascent  /  Dashed amber: planned continuation. Orbit not yet reached."
	if phase==6:
		var target_name:String=mission.get("target_body","Earth")
		var earth_orbit:=target_name.begins_with("Earth") or target_name=="LEO station"
		heading.text="EARTH ORBIT / PAYLOAD CHECKOUT" if earth_orbit else "DEPARTURE / "+target_name.to_upper()
		subtitle.text="The spacecraft remains in Earth orbit. Next: "+str(mission.get("primary_objective","mission operations")) if earth_orbit else "Departure burn after parking orbit. Coast to "+target_name+" shown with time compression."
	if phase==7:
		for d in debris:d.hide()
		var body:String=mission.get("target_body","Earth")
		var mat:=planet.material_override as ShaderMaterial
		mat.set_shader_parameter("terrestrial",body.begins_with("Earth") or body=="LEO station" or body=="Sun-Earth L2")
		mat.set_shader_parameter("land",Color("9b6146") if body=="Mars" else Color("72767c"))
		planet.position=Vector3(0,-290,0)
	if phase==8:GameAudio.play_effect("verified",-16)

func _update_destination(u:float) -> void:
	var kind:String=craft.get("type","Satellite")
	if kind=="Rover":
		surface.show()
		lander.show()
		planet.hide()
		body_model.hide()
		lander.position.y=maxf(0,8-u*.55)
		descent_exhaust.visible=u<14.55
		payload.position=Vector3(0,lander.position.y+1.1*(1-smoothstep(16,30,u)),-minf(maxf(u-16,0)*.22,6))
		payload.rotation=Vector3.ZERO
		for p in panels:p.hide()
		drill_arm.visible=u>16
		drill_arm.rotation.x=sin(u*1.8)*.12
		scan_ring.visible=u>16
		scan_ring.scale=Vector3.ONE*(1+fmod(u*.3,1))
		camera.position=Vector3(8,4,12)
		camera.look_at(payload.position+Vector3.UP*.8)
		subtitle.text="Powered descent  /  touchdown confirmed." if u<16 else ("Polar drill survey: sampling ice-bearing regolith. Volatile data transmitted." if mission.get("id","")=="lunar_ice" else "Geology traverse: scanning sedimentary layers and collecting rock samples.")
	elif kind=="Automated Cargo Spacecraft":
		payload.position=Vector3(0,8,maxf(0,10-u*.3))
		payload.rotation=Vector3.ZERO
		if not surface.has_meta("station"):
			surface.set_meta("station",true)
			var station:=_node(world,Vector3(0,8,-4))
			SpaceVisuals.box(station,"Station truss",Vector3(15,.6,.6),Vector3.ZERO,Color("d9d8cc"))
			for x in [-5,5]:SpaceVisuals.box(station,"Station power array",Vector3(3,.08,8),Vector3(x,0,0),Color("203e67"))
			_sphere(station,1.7,Vector3.ZERO,Color("b9c4c9"))
		camera.position=Vector3(14,14,20)
		camera.look_at(Vector3(0,8,0))
		subtitle.text="Rendezvous  /  closing velocity reduced." if u<28 else "Docking capture confirmed. Propellant transfer to the orbital station complete."
	else:
		payload.position=Vector3(0,9,0)
		payload.rotation.y=u*.018
		camera.position=Vector3(11,13,19)
		camera.look_at(payload.position)
		for p in panels:p.rotation.z=0
		var id:String=mission.get("id","")
		if kind=="Space Telescope":
			subtitle.text="Sun-Earth L2 transfer complete. Thermal settling and pointing calibration." if u<22 else ("Spectral observation acquired. Exoplanet atmosphere data downlinked." if id.contains("exoplanet") else "Deep-field survey acquired. Galaxy observations downlinked.")
			body_model.position=Vector3(-200,-450,-700)
		elif kind=="Interplanetary Probe":
			planet.scale=Vector3(1,.72,1.3)*.09
			body_model.position=Vector3(0,-15,-35)
			body_model.scale=Vector3.ONE*.06
			if mission.get("id","")=="comet":
				comet_tail.visible=true
				comet_tail.position=Vector3(0,-2,-35)
			planet.material_override=SpaceVisuals.material(Color("776e65"))
			subtitle.text="Target-relative navigation established." if u<22 else ("Comet flyby: dust and gas measurements transmitted." if id.contains("comet") else "Asteroid survey: shape, surface chemistry and terrain mapped.")
		elif id.contains("navigation"):
			subtitle.text="MEO insertion  /  clock synchronization." if u<22 else "Navigation payload commissioned. Satellite linked to the existing constellation."
			if not payload.has_meta("links") and u>22:
				payload.set_meta("links",true)
				for i in 3:
					var at:=Vector3(-15+i*14,5,-16)
					var line:=MeshInstance3D.new()
					var link:=ImmediateMesh.new()
					link.surface_begin(Mesh.PRIMITIVE_LINES,SpaceVisuals.material(Color("64b5c7"),true))
					link.surface_add_vertex(payload.position)
					link.surface_add_vertex(at)
					link.surface_end()
					line.mesh=link
					world.add_child(line)
					var other:=_node(world,at)
					SpaceVisuals.model(other,"spacecraft/satellite/satellite_base",Vector3.ZERO,0,1.3,false)
		else:subtitle.text="Orbit acquisition  /  attitude stabilized." if u<22 else ("Atmospheric observation strip acquired. Science data received." if id.contains("atmosphere") else "Earth imaging pass complete. Surface imagery received.")

func _show_result() -> void:
	rumble.stop()
	countdown.stop()
	var missing:=Design.missing_systems(craft,mission)
	var failures:Array=performance.get("errors",[]).duplicate()
	for issue in missing:failures.append(preload("res://scripts/gameplay/design_help.gd").repair(issue,craft,mission))
	var power_margin:=float(craft.get("generation_w",0))/maxf(1,float(craft.get("load_w",1)))
	var dv_margin:=float(performance.get("dv",0))/maxf(1,float(performance.get("target",1)))
	var score:=clampi(roundi(80+minf(.25,power_margin-1)*40+minf(.2,dv_margin-1)*50)-failures.size()*15,0,100)
	report={"score":score,"success":failures.is_empty(),"mission":mission.get("id",""),"issues":failures.duplicate()}
	GameState.flight_results[str(mission.get("id",""))]=report.duplicate(true)
	GameState.set_objective("Mission complete" if failures.is_empty() else "Review mission findings",str(mission.get("title",""))+"  /  %d / 100"%score,Vector3.ZERO)
	result=SpaceUI.panel(self,28)
	result.z_index=20
	result.show()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	result.anchor_left=.5
	result.anchor_right=.5
	result.anchor_top=.06
	result.anchor_bottom=.94
	result.offset_left=-330
	result.offset_right=330
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	result.add_child(scroll)
	var col:=SpaceUI.column(scroll,12)
	col.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	SpaceUI.label(col,"MISSION SUCCESS" if failures.is_empty() else "MISSION REVIEW",32,SpaceUI.GREEN)
	SpaceUI.label(col,str(mission.get("title","")),24)
	SpaceUI.label(col,"ENGINEERING RATING   %d / 100"%score,27,SpaceUI.ACCENT)
	SpaceUI.label(col,str(mission.get("primary_objective","")),18,SpaceUI.INK,true)
	SpaceUI.label(col,"Power reserve  +%.0f%%\nVelocity budget  %.2f / %.2f km/s\nPayload  %.0f kg"%[(power_margin-1)*100,float(performance.get("dv",0))/1000,float(performance.get("target",0))/1000,float(craft.get("mass_kg",0))],18,SpaceUI.INK,true)
	if not failures.is_empty():SpaceUI.label(col,"\n".join(failures),16,SpaceUI.INK,true)
	SpaceUI.label(col,"Mission cinematic  /  outcomes illustrate the verified design. Flight and science are simplified.",14,SpaceUI.MUTED,true)
	if failures.is_empty():
		var name_input:=LineEdit.new()
		name_input.text=str(mission.get("short_title","My rocket"))+" launcher"
		name_input.max_length=64
		col.add_child(name_input)
		var saved_note:=SpaceUI.label(col,"",14,SpaceUI.GREEN,true)
		var save_button:=SpaceUI.button(col,"SAVE TO WORKSHOP",func():
			var store=preload("res://scripts/workshop_store.gd")
			var issue:String=store.save(store.pack(name_input.text,parts,craft,mission))
			saved_note.text="Saved. Open Workshop from the main menu to share this rocket." if issue.is_empty() else issue)
		save_button.custom_minimum_size.y=34
	SpaceUI.button(col,"RETURN TO HYPERION",func():finished.emit())
	GameAudio.play_effect("verified" if failures.is_empty() else "failure",-12)
	if is_instance_valid(SaveStore.world):SaveStore.call_deferred("save_now")

func _exit_tree() -> void:
	GameAudio.menu_music(false)
	GameAudio.ambience("facility")

func _make_broadcast() -> void:
	var existing:=get_children()
	var black:=ColorRect.new()
	black.color=Color("080a0b")
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	move_child(black,0)
	broadcast=Control.new()
	broadcast.clip_contents=true
	add_child(broadcast)
	for child in existing:
		if child is Control:child.reparent(broadcast,false)
	crt=ColorRect.new()
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://materials/launch_crt.gdshader")
	crt.material=mat
	broadcast.add_child(crt)
	var hint:=SpaceUI.label(self,"SPACE  NEXT SEQUENCE     HOLD SPACE  4x",14,Color("acb7b3"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top=-24
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_fit_broadcast)
	_fit_broadcast()
	comet_tail=_smoke(world,Vector3.ZERO,100,14,7)
	comet_tail.direction=Vector3(1,.1,-.3)
	comet_tail.initial_velocity_min=9
	comet_tail.initial_velocity_max=15
	comet_tail.preprocess=14
	comet_tail.scale_amount_max=5
	comet_tail.spread=9
	comet_tail.gravity=Vector3.ZERO
	comet_tail.emitting=true
	comet_tail.hide()

func _fit_broadcast() -> void:
	var h:=minf(size.y-28,size.x*.75)
	broadcast.size=Vector2(h*4/3,h)
	broadcast.position=Vector2((size.x-broadcast.size.x)*.5,0)
	crt.material.set_shader_parameter("origin",broadcast.position/size)
	crt.material.set_shader_parameter("extent",broadcast.size/size)

var space_down:=-1.0
func _input(event:InputEvent) -> void:
	if not event is InputEventKey or event.physical_keycode!=KEY_SPACE or event.echo:return
	if is_instance_valid(result):return
	get_viewport().set_input_as_handled()
	if event.pressed:
		space_down=Time.get_ticks_msec()/1000.0
		acceleration=4
	else:
		acceleration=1
		if space_down>=0 and Time.get_ticks_msec()/1000.0-space_down<.35:
			var next_time:=countdown_time if shot_index==0 else countdown_time+float(cuts[mini(shot_index-1,cuts.size()-1)])
			elapsed=next_time+.01
			_update(.016)
		space_down=-1

func _smoke(parent:Node3D,at:Vector3,amount:int,lifetime:float,speed:float) -> CPUParticles3D:
	var fx:=CPUParticles3D.new()
	parent.add_child(fx)
	fx.position=at
	fx.amount=amount if SettingsStore.graphics>0 else amount/2
	fx.lifetime=lifetime
	fx.direction=Vector3(1,.15,0)
	fx.spread=70
	fx.initial_velocity_min=speed*.4
	fx.initial_velocity_max=speed
	fx.gravity=Vector3(0,.3,0)
	fx.scale_amount_min=1.2
	fx.scale_amount_max=3.5
	var curve:=Curve.new()
	curve.add_point(Vector2(0,.2))
	curve.add_point(Vector2(1,1))
	fx.scale_amount_curve=curve
	var gradient:=Gradient.new()
	gradient.set_color(0,Color(.9,.86,.78,.6))
	gradient.set_color(1,Color(.38,.4,.42,0))
	fx.color_ramp=gradient
	var q:=QuadMesh.new()
	q.size=Vector2(3,3)
	fx.mesh=q
	var mat:=StandardMaterial3D.new()
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo=true
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var tex:=GradientTexture2D.new()
	var g:=Gradient.new()
	g.set_color(0,Color(1,1,1,.6))
	g.add_point(.3,Color(1,1,1,.32))
	g.add_point(.65,Color(1,1,1,.08))
	g.set_color(g.get_point_count()-1,Color(1,1,1,0))
	tex.gradient=g
	tex.fill=GradientTexture2D.FILL_RADIAL
	tex.fill_from=Vector2(.5,.5)
	tex.fill_to=Vector2(1,.5)
	mat.albedo_texture=tex
	fx.material_override=mat
	fx.emitting=false
	fx.visibility_aabb=AABB(Vector3(-200,-200,-200),Vector3(400,400,400))
	return fx

func _destination_body() -> String:
	return {"Mars":"mars","Moon":"moon","Near-Earth asteroid":"asteroid","Comet":"comet_nucleus"}.get(str(mission.get("target_body","Earth")),"earth")

func _set_body(kind:String) -> void:
	if is_instance_valid(body_model) and body_model.get_meta("kind","")==kind:return
	if is_instance_valid(body_model):body_model.queue_free()
	# Explicit model catalog also makes celestial assets available in web exports.
	var paths:={"earth":"celestial/earth","mars":"celestial/mars","moon":"celestial/moon","asteroid":"celestial/asteroid","comet_nucleus":"celestial/comet_nucleus"}
	body_model=SpaceVisuals.model(world,paths[kind],Vector3(0,-560,0),0,540,false)
	body_model.set_meta("kind",kind)

func _update_coast(progress:float) -> void:
	payload.position=Vector3(0,8,0)
	payload.rotation.y=.5+progress*.35
	for panel in panels:panel.rotation.z=0
	var deep:bool=not str(mission.get("target_body","Earth")).begins_with("Earth") and mission.get("target_body","")!="LEO station"
	body_model.position=Vector3(-80,-550,-180) if not deep else Vector3(-50,-360,-420)
	camera.position=Vector3(lerpf(12,7,progress),12,lerpf(22,17,progress))
	camera.fov=42
	camera.look_at(payload.position+Vector3.UP)
