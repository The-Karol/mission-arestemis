extends Control

@onready var mission_button: Button = %MissionButton
@onready var sandbox_button: Button = %SandboxButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	mission_button.pressed.connect(func() -> void:
		GameState.new_session()
		SceneManager.change_scene("res://scenes/world/world.tscn"))
	back_button.pressed.connect(func() -> void: SceneManager.change_scene("res://scenes/ui/main_menu.tscn"))
	sandbox_button.disabled = true
	mission_button.grab_focus()

