extends SubViewportContainer
const Design = preload("res://scripts/gameplay/design_data.gd")
const BASE := {"Rover":"rover","Satellite":"satellite","Automated Cargo Spacecraft":"cargo","Space Telescope":"telescope","Interplanetary Probe":"probe"}
var view := SubViewport.new()
var pivot := Node3D.new()
var camera := Camera3D.new()
var subject: Node3D
var distance := 6.0
var zoom := 1.0
signal module_picked(index: int)
var dragging := false
var drag_start := Vector2.ZERO
var modules := {}
var highlight := -1
var pale := _ink(Color("d0deba"))
var amber := _ink(Color("ffd186"))
var callouts: Array=[]
var overlay: Control

func _ready() -> void:
	stretch = true
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	view.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(view)
	view.add_child(pivot)
	view.add_child(camera)
	camera.fov=37
	camera.current=true
	overlay=preload("res://scripts/gameplay/craft_drawing.gd").new()
	overlay.viewport_control=self
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	SpaceUI.fill(overlay)
	resized.connect(_frame)
	mouse_exited.connect(func(): dragging=false)

func rebuild(kind: String, ids: Array, selected: Variant = -1) -> void:
	callouts.clear()
	modules.clear()
	highlight = selected if selected is int else -1
	if subject:
		pivot.remove_child(subject)
		subject.queue_free()
	subject=Node3D.new()
	pivot.add_child(subject)
	var name_base: String=Design.BUSES[kind][2]
	var body := (load("res://assets/models/spacecraft/%s/%s.glb" % [BASE[kind],name_base]) as PackedScene).instantiate() as Node3D
	subject.add_child(body)
	_strip_builtin_equipment(body,kind)
	amber.set_shader_parameter("line_weight",4.5)
	_color(body,pale)
	var used := {}
	for i in ids.size():
		var p: Dictionary=Design.by_id[ids[i]]
		var id: String = p.id
		var sockets: Array = []
		match p.category:
			"Power":
				if "solar" in p.model: sockets=["SolarLeft","SolarRight","Power"]
				elif id=="F3.2": sockets=["Power"]
			"Communications":
				if id in ["A4.5","A4.6","A4.7"]: sockets=["Antenna"]
			"Science","Cargo","Docking": sockets=["InstrumentArm","InstrumentFront","InstrumentTop","Payload_A","Payload_B","InstrumentRear"]
			"Thermal": sockets=["Radiator"]
			"Propulsion": sockets=["Thruster"]
		for s in sockets:
			var anchor := body.find_child("SOCKET_"+str(s),true,false) as Node3D
			if not anchor or used.has(s): continue
			var module := (load("res://assets/models/spacecraft/modules/%s.glb" % p.model) as PackedScene).instantiate() as Node3D
			subject.add_child(module)
			var mount := module.find_child("SOCKET_Attach",true,false) as Node3D
			var local_mount := module.global_transform.affine_inverse()*mount.global_transform if mount else Transform3D.IDENTITY
			module.global_transform=anchor.global_transform*local_mount.affine_inverse()
			modules[i] = module
			_color(module,amber if i==highlight else pale)
			used[s]=true
			var mark := {"label":str(p.name).get_slice(" -",0).to_upper(),"anchor":anchor,"index":i,"active":i==highlight}
			if i==highlight and not callouts.any(func(item):return item.active): callouts.push_front(mark)
			elif not callouts.any(func(item):return item.label==mark.label):callouts.append(mark)
			break
	if callouts.is_empty(): callouts.append({"label":"BUS","anchor":body,"active":false})
	var bounds := SpaceVisuals.bounds_of(subject)
	subject.position=-bounds.get_center()
	distance=maxf(1.5,bounds.size.length()*1.39)
	_frame()

func mark(index: int) -> void:
	if modules.has(highlight): _color(modules[highlight],pale)
	highlight = index
	if modules.has(index): _color(modules[index],amber)
	for point in callouts: point.active = point.get("index",-2)==index
	overlay.queue_redraw()

func _pick(at: Vector2) -> void:
	var screen := at*Vector2(view.size)/size
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best := INF
	var index := -1
	for key in modules:
		for mesh: MeshInstance3D in modules[key].find_children("*","MeshInstance3D",true,false):
			var inv := mesh.global_transform.affine_inverse()
			var hit = mesh.get_aabb().intersects_ray(inv*origin,inv.basis*direction)
			if hit == null: continue
			var dist := origin.distance_squared_to(mesh.global_transform*Vector3(hit))
			if dist < best:
				best = dist
				index = key
	module_picked.emit(index)

func _ink(c: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://materials/design_plate.gdshader")
	mat.set_shader_parameter("ink",c)
	return mat

func _color(root: Node, mat: Material) -> void:
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=mat

func _frame() -> void:
	var aspect := maxf(0.35,size.x/maxf(1.0,size.y))
	camera.position=Vector3(0.85,0.62,1).normalized()*distance*zoom/minf(1,aspect)
	camera.look_at(Vector3.ZERO)
	if overlay: overlay.queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed: drag_start=e.position
			elif dragging and drag_start.distance_to(e.position)<5: _pick(e.position)
			dragging=e.pressed
		if e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom=clampf(zoom*(0.88 if e.button_index==MOUSE_BUTTON_WHEEL_UP else 1.14),0.55,1.85)
			_frame()
		accept_event()
	elif e is InputEventMouseMotion and dragging:
		pivot.rotation.y+=e.relative.x*0.012
		pivot.rotation.x=clampf(pivot.rotation.x+e.relative.y*0.009,-1,1)
		overlay.queue_redraw()
		accept_event()

func _strip_builtin_equipment(body: Node3D, kind: String) -> void:
	# Fixed chassis/optical tube/wheels remain. Mission equipment is represented
	# only by the installed, selectable module instances.
	var prefixes:=["solar","array_","antenna","comms_","highgain","rcs_","aft_thruster","instrument_deckbox","instrument_toppanel"]
	if kind=="Rover":
		prefixes.append_array(["arm_","mast_","power_unit","power_radiator","deck_avionics","deck_calibration","front_hazardcamera"])
	if kind=="Satellite":prefixes.append_array(["optical_instrument","optical_aperture"])
	for mesh in body.find_children("*","MeshInstance3D",true,false):
		var title:=str(mesh.name).to_lower()
		for prefix in prefixes:
			if title.begins_with(prefix):
				mesh.hide()
				break
