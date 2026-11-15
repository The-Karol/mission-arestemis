extends Control

signal closed
var in_game := false

@onready var master_slider: HSlider = %MasterVolume
@onready var music_slider: HSlider = %MusicVolume
@onready var sfx_slider: HSlider = %SFXVolume
@onready var sensitivity_slider: HSlider = %MouseSensitivity
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_button: Button = %BackButton

func _ready() -> void:
	$CenterContainer/Panel.add_theme_stylebox_override("panel",SpaceUI.style(Color("292722f5"),24,Color("b39a75")))
	var row := HBoxContainer.new()
	var content := back_button.get_parent()
	content.add_child(row)
	content.move_child(row,fullscreen_toggle.get_index())
	var label := Label.new()
	label.text = "Graphics quality"
	label.custom_minimum_size.x = 190
	row.add_child(label)
	var quality := OptionButton.new()
	for title in ["Low","Balanced","High"]: quality.add_item(title)
	quality.tooltip_text="Low: lower 3D resolution, no real-time shadows, particles or turn blur, and cheaper mirrors. Balanced: sharper 3D with shadows and effects. Interface text stays at full resolution."
	quality.select(SettingsStore.graphics)
	quality.item_selected.connect(SettingsStore.set_graphics)
	row.add_child(quality)
	var hints:=CheckButton.new()
	hints.text="Mission guidance"
	hints.button_pressed=SettingsStore.guidance==1
	hints.toggled.connect(func(on):
		SettingsStore.guidance=int(on)
		if on: SettingsStore.seen_guides.clear()
		SettingsStore.save_settings())
	content.add_child(hints)
	content.move_child(hints,fullscreen_toggle.get_index())
	master_slider.value = SettingsStore.master_volume
	music_slider.value = SettingsStore.music_volume
	sfx_slider.value = SettingsStore.sfx_volume
	sensitivity_slider.value = SettingsStore.mouse_sensitivity
	fullscreen_toggle.button_pressed = SettingsStore.fullscreen
	master_slider.value_changed.connect(func(value: float) -> void: SettingsStore.set_volume("Master", value))
	music_slider.value_changed.connect(func(value: float) -> void: SettingsStore.set_volume("Music", value))
	sfx_slider.value_changed.connect(func(value: float) -> void: SettingsStore.set_volume("SFX", value))
	sensitivity_slider.value_changed.connect(SettingsStore.set_mouse_sensitivity)
	fullscreen_toggle.toggled.connect(SettingsStore.set_fullscreen)
	back_button.text="Back to pause" if in_game else "Back"
	back_button.pressed.connect(_back)

func _back() -> void:
	if in_game:
		closed.emit()
		queue_free()
	else: SceneManager.change_scene("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()

