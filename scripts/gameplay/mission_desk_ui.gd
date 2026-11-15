extends Control

var table: Node3D
var ui: CanvasLayer
var hovered: Node3D
var selected: Node3D
var paper: MeshInstance3D
var paper_viewport: SubViewport
var busy := false
var back: Button
var caption: Label
var select_button: Button

func _ready() -> void:
	SpaceUI.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = SpaceUI.button(self,"BACK  /  ESC",_back)
	back.position = Vector2(28,24)
	back.custom_minimum_size.x = 180
	caption = SpaceUI.label(self,"CHOOSE A DOSSIER",14,Color(0.88,0.86,0.75))
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.position.y -= 44
	caption.position.x -= 90

func _process(_delta: float) -> void:
	if busy or ui._transitioning or is_instance_valid(selected): return
	var camera: Camera3D = ui.inspection_camera
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP,table.global_position.y+table.top+0.03).intersects_ray(origin,direction)
	var next: Node3D
	if hit != null:
		for file in table.folders:
			var local: Vector3 = file.to_local(hit)
			if absf(local.x) < 0.28 and absf(local.z) < 0.36: next = file
	if next != hovered:
		if is_instance_valid(hovered): hovered.hover(false)
		hovered = next
		if is_instance_valid(hovered): hovered.hover(true)

func _input(event: InputEvent) -> void:
	if busy or ui._transitioning: return
	if is_instance_valid(paper) and event is InputEventMouse:
		var camera: Camera3D = ui.inspection_camera
		var ray_from := camera.project_ray_origin(event.position)
		var ray_dir := camera.project_ray_normal(event.position)
		var hit: Variant = Plane(paper.global_basis.z,paper.global_position).intersects_ray(ray_from,ray_dir)
		if hit != null:
			var point: Vector3 = paper.to_local(hit)
			var dimensions: Vector2 = paper.mesh.size
			var uv := Vector2(point.x/dimensions.x+0.5,0.5-point.y/dimensions.y)
			var forwarded := event.duplicate() as InputEventMouse
			forwarded.position = uv * Vector2(paper_viewport.size)
			forwarded.global_position = forwarded.position
			paper_viewport.push_input(forwarded,true)
			if uv.x >= 0 and uv.x <= 1 and uv.y >= 0 and uv.y <= 1:
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(hovered):
		get_viewport().set_input_as_handled()
		open_folder(hovered)

func open_folder(file: Node3D) -> void:
	busy = true
	selected = file
	caption.hide()
	await file.unfold()
	_build_paper(file.mission)
	var pose := Transform3D(Basis.from_euler(Vector3(-PI/2,0,0)),paper.global_position+Vector3.UP*0.74)
	await ui.move_inspection(pose,44.0,0.75)
	busy = false
	back.text = "OTHER DOSSIERS  /  ESC"

func _build_paper(mission: Dictionary) -> void:
	paper_viewport = SubViewport.new()
	paper_viewport.disable_3d = true
	paper_viewport.size = Vector2i(700,940)
	paper_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	selected.add_child(paper_viewport)
	paper = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.40,0.537)
	paper.mesh = quad
	paper.position = Vector3(0.225,0.045,0)
	paper.rotation.x = -PI/2
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = paper_viewport.get_texture()
	paper.material_override = mat
	selected.add_child(paper)
	var page := PanelContainer.new()
	page.size = paper_viewport.size
	var stock := SpaceUI.style(Color("eee7d4"),38,Color("cec2a8"))
	stock.set_corner_radius_all(2)
	page.add_theme_stylebox_override("panel",stock)
	paper_viewport.add_child(page)
	var column := SpaceUI.column(page,18)
	var ink := Color("252925")
	SpaceUI.label(column,"HYPERION   /   MISSION DIRECTORATE",16,Color("73664e"))
	column.add_child(HSeparator.new())
	SpaceUI.label(column,str(mission.title),34,ink,true)
	SpaceUI.label(column,str(mission.target_body).to_upper()+"   /   "+str(mission.difficulty).to_upper(),17,Color("795745"),true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := SpaceUI.column(scroll,18)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preload("res://scripts/gameplay/design_data.gd").mission_plate(body,mission,140,ink)
	for entry in [["BRIEF",mission.description],["PRIMARY OBJECTIVE",mission.primary_objective],["SECONDARY OBJECTIVES","- "+"\n- ".join(mission.secondary_objectives)],["SPACECRAFT",mission.spacecraft_type],["PAYLOAD","- "+"\n- ".join(mission.instruments)],["TRAJECTORY",mission.recommended_orbit],["DESIGN CONSTRAINTS",mission.constraints]]:
		SpaceUI.label(body,entry[0],15,Color("81725c"))
		SpaceUI.label(body,str(entry[1]),22,ink,true)
	var choice := SpaceUI.button(column,"SELECT MISSION",func():
		if GameState.select_mission(str(mission.id)): ui.close_modal(),56)
	select_button = choice
	for state in ["normal","hover","pressed","focus","disabled"]:
		var outline := SpaceUI.style(Color("ddd2b8") if state in ["hover","pressed"] else Color(0,0,0,0),14,ink)
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(3)
		choice.add_theme_stylebox_override(state,outline)
		choice.add_theme_color_override("font_"+state+"_color",ink)
	choice.add_theme_color_override("font_color",ink)
	choice.disabled = not GameState.selected_mission.is_empty() or GameState.sandbox
	if choice.disabled: choice.text = "ACTIVE MISSION" if GameState.selected_mission == mission.id else "READ ONLY"
	SpaceUI.label(column,"FLIGHT DIRECTOR SIGNATURE   __________________",13,Color("81725c"))

func _back() -> void:
	if busy or ui._transitioning: return
	if is_instance_valid(selected):
		busy = true
		clear_paper()
		await ui.move_inspection(table.camera_pose(),44.0,0.65)
		busy = false
		back.text = "BACK  /  ESC"
		caption.show()
	else: ui.close_modal()

func clear_paper() -> void:
	if is_instance_valid(paper): paper.queue_free()
	if is_instance_valid(paper_viewport): paper_viewport.queue_free()
	paper = null
	paper_viewport = null
	if is_instance_valid(selected): selected.fold()
	selected = null

func _exit_tree() -> void:
	clear_paper()
	for file in table.folders: file.hover(false)
