extends Node3D

@onready var label: Label3D = $Label3D

func set_title(value: String, tint: Color = Color(0.78, 0.86, 0.84)) -> void:
	label.font = SpaceUI.FONT
	label.text = value
	label.font_size = 28 if value.length() > 22 else 36
	label.modulate = tint

