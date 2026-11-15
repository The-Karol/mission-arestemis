class_name SpaceUI
extends RefCounted

const FONT := preload("res://assets/fonts/PixelifySans.ttf")

const INK := Color(0.85, 0.90, 0.85)
const MUTED := Color(0.47, 0.61, 0.59)
const ACCENT := Color(0.95, 0.65, 0.32)
const GREEN := Color(0.52, 0.86, 0.65)

static func style(color: Color = Color(0.035, 0.075, 0.075, 0.98), padding: int = 20, border: Color = Color(0.18, 0.32, 0.30)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.shadow_color = Color(0,0,0,0.22)
	box.shadow_size = 8
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func label(parent: Node, text: String, font_size: int = 18, color: Color = INK, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = preload("res://scripts/gameplay/design_help.gd").clean(text)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, callback: Callable, minimum_height: float = 42) -> Button:
	var node := Button.new()
	node.text = preload("res://scripts/gameplay/design_help.gd").clean(text)
	node.custom_minimum_size.y = minimum_height
	node.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var active: bool = state in ["hover", "focus"]
		var box := style(Color(0.08,0.17,0.18,0.98) if active else Color(0.045,0.095,0.10,0.98),12, GREEN if active else Color(0.19,0.31,0.32))
		box.set_corner_radius_all(10)
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		node.add_theme_stylebox_override(state,box)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node

static func column(parent: Node, separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

static func panel(parent: Node, padding: int = 20) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", style(Color(0.035, 0.075, 0.075, 0.98), padding))
	parent.add_child(node)
	return node

static func fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

# Mission briefings share the warm metal and ivory palette of dialogue panels.
static func briefing_panel(parent: Node, padding: int = 24) -> PanelContainer:
	var node := PanelContainer.new()
	var box := style(Color("292722f5"),padding,Color("b39a75"))
	box.shadow_size = 18
	box.shadow_color = Color(0,0,0,0.38)
	node.add_theme_stylebox_override("panel",box)
	parent.add_child(node)
	return node

static func briefing_button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var b := button(parent,text,callback,42)
	for state in ["normal","hover","focus","pressed"]:
		var active: bool = state in ["hover","focus"]
		var box := style(Color("6e5339") if primary or active else Color("36332c"),12,Color("f0d3a2") if active else Color("9b8564"))
		box.set_corner_radius_all(10)
		b.add_theme_stylebox_override(state,box)
		b.add_theme_color_override("font_color",Color("fff0d4"))
	return b
