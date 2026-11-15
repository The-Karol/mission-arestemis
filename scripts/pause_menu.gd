extends CanvasLayer

@onready var resume_button: Button = %ResumeButton
@onready var menu_button: Button = %MainMenuButton
var _player: CharacterBody3D
var _settings_page: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://materials/pause_glass.gdshader")
	$Shade.material = glass
	var panel := $CenterContainer/Panel as PanelContainer
	panel.add_theme_stylebox_override("panel",SpaceUI.style(Color("1b2926ee"),32,Color("a09170")))
	var column := panel.get_node("Content") as VBoxContainer
	var heading := column.get_node("Title") as Label
	heading.text = "Mission paused"
	heading.add_theme_font_override("font",preload("res://assets/fonts/PixelifySans.ttf"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_font_size_override("font_size",52)
	heading.add_theme_color_override("font_color",Color("f1e2c4"))
	var mission := GameState.objective if not GameState.sandbox else "Free design workshop"
	var objective := SpaceUI.label(column,mission,16,Color("cebfa3"),true)
	column.move_child(objective,1)
	var settings_button:=SpaceUI.button(column,"Settings",_open_settings,48)
	column.move_child(settings_button,menu_button.get_index())
	for button in [resume_button,settings_button,menu_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font",preload("res://assets/fonts/PixelifySans.ttf"))
		button.add_theme_font_size_override("font_size",21)
		for state in ["normal","hover","pressed","focus"]:
			var active: bool = state != "normal"
			var box := SpaceUI.style(Color("3e5148") if active else Color("24322e"),14,Color("d0b98d") if active else Color("4a544a"))
			box.set_corner_radius_all(6)
			button.add_theme_stylebox_override(state,box)
	resume_button.text = "Resume mission"
	menu_button.text = "Main menu"
	resume_button.pressed.connect(_resume)
	menu_button.pressed.connect(_go_to_menu)
	resume_button.grab_focus()
	get_tree().paused = true

func configure(player: CharacterBody3D) -> void:
	_player = player
	player.ui.hud.hide()
	player.get_node("HUD").hide()

func _resume() -> void:
	SaveStore.save_now()
	get_tree().paused = false
	if is_instance_valid(_player):
		_player.request_walk_capture()
		_player.set_controls_enabled(true)
		_player.ui.hud.show()
		_player.get_node("HUD").show()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_settings_page):return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()

func _go_to_menu() -> void:
	SaveStore.save_now()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_free()
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn")

func _open_settings() -> void:
	if is_instance_valid(_settings_page):return
	_settings_page=preload("res://scenes/ui/settings_menu.tscn").instantiate()
	_settings_page.in_game=true
	_settings_page.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(_settings_page)
	SpaceUI.fill(_settings_page)
	$CenterContainer.hide()
	_settings_page.closed.connect(func():
		$CenterContainer.show()
		resume_button.grab_focus())
