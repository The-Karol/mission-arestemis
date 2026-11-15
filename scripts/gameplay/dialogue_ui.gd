extends Control

signal finished

var speaker: Label
var line: Label
var speaker_name := "Engineer"
var next_button: Button
var lines: Array = []
var index := 0
var _typing := 0.0
const LETTERS_PER_SECOND := 38.0
const SYLLABLES: Array[AudioStream] = [
	preload("res://assets/audio/sfx/voices/ah.wav"),
	preload("res://assets/audio/sfx/voices/ee.wav"),
	preload("res://assets/audio/sfx/voices/oh.wav")
]
const VOICE_PITCH := {"Engineer":1.42, "Payload scientist":1.34, "Flight controller":1.62, "Assembly specialist":0.83}
var voice := AudioStreamPlayer.new()
var voice_wait := 0.0

func _ready() -> void:
	add_child(voice)
	voice.bus = &"SFX"
	voice.volume_db = -17.0
	SpaceUI.fill(self)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.anchor_left = 0.19
	panel.anchor_right = 0.81
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -113
	panel.offset_bottom = -45
	var border := Color("d5b58b")
	var background := SpaceUI.style(Color(0.18,0.115,0.09,0.94),20,border)
	background.content_margin_top = 16
	background.content_margin_bottom = 12
	background.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel",background)
	var row := HBoxContainer.new()
	panel.add_child(row)
	line = SpaceUI.label(row,"",21,Color("fff2d8"),true)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_button = Button.new()
	next_button.draw.connect(func():
		var center := next_button.size*0.5
		var points := PackedVector2Array([center+Vector2(-4,-6),center+Vector2(5,0),center+Vector2(-4,6)])
		next_button.draw_colored_polygon(points,Color("fff1d8")))
	next_button.flat = true
	next_button.tooltip_text = "Continue  /  Space / Enter"
	next_button.custom_minimum_size.x = 34
	next_button.add_theme_font_size_override("font_size",23)
	for state in ["normal","hover","pressed","focus"]:
		next_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	next_button.pressed.connect(advance)
	row.add_child(next_button)
	var tag := PanelContainer.new()
	add_child(tag)
	tag.anchor_left = 0.19
	tag.anchor_top = 1.0
	tag.anchor_bottom = 1.0
	tag.offset_left = 21
	tag.offset_top = -133
	tag.offset_bottom = -105
	var badge := SpaceUI.style(Color("493326"),18,border)
	badge.content_margin_top = 2
	badge.content_margin_bottom = 2
	badge.set_corner_radius_all(13)
	tag.add_theme_stylebox_override("panel",badge)
	speaker = SpaceUI.label(tag,speaker_name,17,Color("fff1d8"))
	_update_line()

func configure(name_text: String, dialogue_lines: Array) -> void:
	speaker_name = name_text
	index = 0
	lines = dialogue_lines.duplicate()
	if is_instance_valid(speaker):
		speaker.text = name_text
		_update_line()

func advance() -> void:
	if line.visible_characters >= 0 and line.visible_characters < line.get_total_character_count():
		voice.stop()
		line.visible_characters = -1
		_typing = float(line.get_total_character_count())
		return
	index += 1
	if index >= lines.size():
		finished.emit()
	else:
		_update_line()

func _update_line() -> void:
	if lines.is_empty():
		return
	voice.stop()
	voice_wait = 0.0
	line.text = str(lines[index])
	line.visible_characters = 0
	_typing = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(line) or line.visible_characters < 0: return
	var previous := line.visible_characters
	var total := line.get_total_character_count()
	if previous >= total: return
	_typing += delta * LETTERS_PER_SECOND
	line.visible_characters = mini(int(_typing),total)
	voice_wait -= delta
	if line.visible_characters <= previous or voice_wait > 0: return
	var pos := line.visible_characters-1
	var letter := line.text.substr(pos,1).to_lower()
	if letter == letter.to_upper(): return
	var phoneme := pos % 3
	if letter in ["a","а","я"]: phoneme = 0
	elif letter in ["i","e","и","е"]: phoneme = 1
	elif letter in ["u","o","у","о"]: phoneme = 2
	var cadence := 1.0 + 0.068*sin(float(pos)*0.61 + index)
	if total-pos < 9: cadence *= 0.95
	voice.stream = SYLLABLES[phoneme]
	voice.pitch_scale = float(VOICE_PITCH.get(speaker_name,1.0)) * cadence
	voice.play()
	voice_wait = 0.070 + 0.009*phoneme

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed("ui_cancel"):
		# Escape also completes the dialogue's callback, so skipping cannot
		# strand the introductory quest in a locked state.
		get_viewport().set_input_as_handled()
		finished.emit()
