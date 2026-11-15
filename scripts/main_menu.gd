extends Control

const TITLE_FONT = preload("res://assets/fonts/PixelifySans.ttf")
const BUTTON_FONT = preload("res://assets/fonts/PixelifySans.ttf")
var _title: Label
var _buttons: VBoxContainer
var _clock := 0.0
var _intro: Tween
var galaxy: ShaderMaterial
var flight: Node3D

func _ready() -> void:
	if "--launch-demo" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file","res://scenes/demo/launch_demo.tscn")
		return
	GameAudio.menu_music(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sky := ColorRect.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://materials/menu_galaxy.gdshader")
	sky_material.set_shader_parameter("nebula_volume",preload("res://assets/ui/nebula_volume.res"))
	galaxy = sky_material
	sky.material = sky_material
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "RocketView"
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.name = "RocketViewport"
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport_container.add_child(viewport)
	flight = preload("res://scenes/presentation/menu_rocket.tscn").instantiate()
	viewport.add_child(flight)
	SettingsStore.apply_view(viewport)
	_title = Label.new()
	_title.text = "Mission Arestemis"
	var title_ink:=ShaderMaterial.new()
	title_ink.shader=preload("res://materials/title_gradient.gdshader")
	_title.material=title_ink
	_title.add_theme_font_override("font", TITLE_FONT)
	_title.add_theme_color_override("font_color", Color("e6a566"))
	_title.add_theme_color_override("font_shadow_color", Color(0.3,0.18,0.10,0.3))
	_title.add_theme_color_override("font_outline_color",Color("fff7e7"))
	_title.add_theme_constant_override("outline_size",3)
	_title.add_theme_constant_override("shadow_offset_y",5)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 13)
	add_child(_buttons)
	for entry in ([["CONTINUE",_resume]] if SaveStore.has_save() else [])+[["MISSION", _play], ["SANDBOX", _sandbox], ["WORKSHOP", _workshop], ["SETTINGS", _settings]]:
		var button := Button.new()
		button.text = entry[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", BUTTON_FONT)
		button.add_theme_color_override("font_color", Color("e9e0ce"))
		button.add_theme_color_override("font_hover_color", Color("ffe3bc"))
		button.add_theme_color_override("font_focus_color", Color("ffe3bc"))
		button.add_theme_color_override("font_disabled_color", Color(0.7,0.68,0.66,0.38))
		for key in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxEmpty.new()
			style.content_margin_left = 18
			button.add_theme_stylebox_override(key, style)
		_buttons.add_child(button)
		if entry[1].is_valid():
			button.pressed.connect(entry[1])
		button.mouse_entered.connect(_hover.bind(button, true))
		button.mouse_exited.connect(_hover.bind(button, false))
		button.focus_entered.connect(_hover.bind(button, true))
		button.focus_exited.connect(_hover.bind(button, false))
	resized.connect(_layout)
	_layout()
	_title.modulate.a = 0
	_buttons.modulate.a = 0
	_intro = create_tween()
	_intro.tween_property(_title, "modulate:a", 1.0, 1.2).set_delay(4.8)
	_intro.parallel().tween_property(_buttons, "modulate:a", 1.0, 1.0).set_delay(5.4)
	if SceneManager.menu_intro_seen:
		_intro.kill()
		flight.skip_intro()
		_buttons.modulate.a = 1.0
		_title.modulate.a = 1.0
	else:
		SceneManager.menu_intro_seen = true
		GameAudio.play_effect("flyby",-13)
	# Draw selection above the starfield and the viewport.
	var selection := Control.new()
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(selection)
	selection.draw.connect(_draw_selection.bind(selection))
	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("selection", selection)
	if SaveStore.has_save() and not SaveStore.offer_shown:call_deferred("_offer_continue")

func _layout() -> void:
	_title.position = Vector2(size.x * 0.055, size.y * 0.055)
	_title.add_theme_font_size_override("font_size", mini(int(size.y * 0.135),int(size.x*0.088)))
	(_title.material as ShaderMaterial).set_shader_parameter("title_top",0.055)
	(_title.material as ShaderMaterial).set_shader_parameter("title_height",float(_title.get_theme_font_size("font_size"))*1.2/maxf(size.y,1))
	_buttons.position = Vector2(size.x * 0.073, size.y * 0.39)
	_buttons.size.x = size.x * 0.28
	for button in _buttons.get_children():
		button.custom_minimum_size = Vector2(size.x * 0.26, size.y * 0.082)
		button.add_theme_font_size_override("font_size", int(size.y * 0.048))
	queue_redraw()

func _hover(button: Button, active: bool) -> void:
	if button.disabled: return
	button.set_meta("hovered", active)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	var cam: Camera3D = flight.camera
	galaxy.set_shader_parameter("sky_basis",cam.global_basis)
	galaxy.set_shader_parameter("lens",Vector2(size.x/maxf(size.y,1),tan(deg_to_rad(cam.fov)*0.5)))
	if has_meta("selection"): get_meta("selection").queue_redraw()

func _draw() -> void:
	pass

func _draw_selection(canvas: Control) -> void:
	if is_instance_valid(_buttons):
		for button in _buttons.get_children():
			if button.get_meta("hovered", false):
				var at: Vector2 = _buttons.position + button.position
				at += Vector2(-8 + sin(_clock * 4) * 2, button.size.y * 0.5)
				canvas.draw_polyline(PackedVector2Array([at+Vector2(-6,-8),at+Vector2(2,0),at+Vector2(-6,8)]),Color("ffa575"),3,true)
				canvas.draw_line(at+Vector2(24,button.size.y*0.39),at+Vector2(160,button.size.y*0.39),Color(1,0.51,0.31,0.5),1,true)

func _play() -> void:
	if has_node("GuideChoice"): return
	var layer := ColorRect.new()
	layer.name = "GuideChoice"
	layer.color = Color(0.02,0.04,0.045,0.92)
	add_child(layer)
	SpaceUI.fill(layer)
	var center := CenterContainer.new()
	layer.add_child(center)
	SpaceUI.fill(center)
	var card := SpaceUI.briefing_panel(center,28)
	card.custom_minimum_size.x = 430
	var col := SpaceUI.column(card,13)
	SpaceUI.label(col,"FLIGHT ACADEMY",13,Color("c5ab7f"))
	SpaceUI.label(col,"Need a hand?",30,Color("fff0d4"))
	SpaceUI.label(col,"Short tips at each computer.",17,Color("d1c4ad"))
	SpaceUI.briefing_button(col,"Yes, show tips",_choose_guidance.bind(true),true).grab_focus()
	SpaceUI.briefing_button(col,"No, I'll explore",_choose_guidance.bind(false))
	SpaceUI.briefing_button(col,"<- Back",func():layer.queue_free())

func _choose_guidance(enabled: bool) -> void:
	SettingsStore.guidance = int(enabled)
	SettingsStore.seen_guides.clear()
	SettingsStore.save_settings()
	_start_campaign()

func _start_campaign() -> void:
	SaveStore.clear_slot(false)
	GameState.new_session()
	SceneManager.change_scene("res://scenes/world/world.tscn")
func _sandbox() -> void:
	SaveStore.clear_slot(true)
	GameState.new_session(true)
	SceneManager.change_scene("res://scenes/world/world.tscn")
func _settings() -> void:
	SceneManager.change_scene("res://scenes/ui/settings_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_accept"):
		$RocketView/RocketViewport.get_child(0).skip_intro()
		if is_instance_valid(_intro): _intro.kill()
		_title.modulate.a = 1
		_buttons.modulate.a = 1

func _resume() -> void:
	SaveStore.prepare_resume()
	if SaveStore.pending.is_empty():return
	SceneManager.change_scene("res://scenes/world/world.tscn")

func _offer_continue() -> void:
	if not is_inside_tree():return
	SaveStore.offer_shown=true
	var shade:=ColorRect.new()
	shade.name="ResumeChoice"
	shade.color=Color(0.01,0.02,0.03,.93)
	add_child(shade)
	SpaceUI.fill(shade)
	var center:=CenterContainer.new()
	shade.add_child(center)
	SpaceUI.fill(center)
	var card:=SpaceUI.briefing_panel(center,28)
	card.custom_minimum_size.x=450
	var col:=SpaceUI.column(card,12)
	SpaceUI.label(col,"WELCOME BACK",14,Color("c7ad7e"))
	SpaceUI.label(col,"Continue your mission?",27,Color("fff0d4"))
	SpaceUI.briefing_button(col,"Continue",_resume,true).grab_focus()
	SpaceUI.briefing_button(col,"New campaign",func():shade.queue_free();_play())
	SpaceUI.briefing_button(col,"Back",func():shade.queue_free())

func _workshop() -> void:
	SceneManager.change_scene("res://scenes/ui/workshop_menu.tscn")
