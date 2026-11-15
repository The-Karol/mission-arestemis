extends Node

const SETTINGS_PATH := "user://space_settings.cfg"

var master_volume := 0.8
var music_volume := 0.65
var sfx_volume := 0.8
var mouse_sensitivity := 0.0025
var fullscreen := false
var graphics := 1
var guidance := -1
var seen_guides := PackedStringArray()

func _ready() -> void:
	load_settings()
	apply_view(get_viewport())

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_audio()
		return
	guidance = int(config.get_value("guidance","enabled",-1))
	seen_guides = config.get_value("guidance","seen",PackedStringArray())
	master_volume = float(config.get_value("audio", "master", master_volume))
	music_volume = float(config.get_value("audio", "music", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx", sfx_volume))
	mouse_sensitivity = float(config.get_value("controls", "mouse_sensitivity", mouse_sensitivity))
	graphics = clampi(int(config.get_value("display","graphics",1)),0,2)
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	_apply_audio()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("guidance","enabled",guidance)
	config.set_value("guidance","seen",seen_guides)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display","graphics",graphics)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))

func apply_view(view: Viewport) -> void:
	view.mesh_lod_threshold = [8.0,1.5,1.0][graphics]
	view.msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][graphics]
	view.scaling_3d_scale = [0.55,0.90,1.0][graphics]
	view.positional_shadow_atlas_size = [512,2048,4096][graphics]

func set_graphics(value: int) -> void:
	graphics = clampi(value,0,2)
	apply_view(get_viewport())
	var scene:=get_tree().current_scene
	if scene is Node3D:apply_world(scene)
	save_settings()

func set_volume(bus_name: String, value: float) -> void:
	var normalized := clampf(value, 0.0, 1.0)
	match bus_name:
		"Master": master_volume = normalized
		"Music": music_volume = normalized
		"SFX": sfx_volume = normalized
	_apply_audio()
	save_settings()

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.01)
	save_settings()

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	if not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	# Web fullscreen is intentionally requested only by the Settings UI's direct user gesture.
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func _apply_audio() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, linear_to_db(maxf(master_volume, 0.0001)))
	for bus_data in [["Music", music_volume], ["SFX", sfx_volume]]:
		var index := AudioServer.get_bus_index(bus_data[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(bus_data[1]), 0.0001)))


func apply_world(world:Node3D) -> void:
	for light:Light3D in world.find_children("*","Light3D",true,false):
		if not light.has_meta("quality_shadow"):light.set_meta("quality_shadow",light.shadow_enabled)
		light.shadow_enabled=bool(light.get_meta("quality_shadow")) and graphics>0
	for node:Node3D in world.find_children("*","Node3D",true,false):
		if node.has_meta("decorative_fx"):node.visible=graphics>0
