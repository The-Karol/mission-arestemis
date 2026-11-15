extends VBoxContainer

var action: Callable
var output: RichTextLabel
var run_button: Button
var animation: Tween
const GREEN := Color("b3edaf")
const RED := Color("ff8b87")

func open(callback: Callable, cartridge: String) -> void:
	action=callback
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	var panel:=PanelContainer.new()
	panel.size_flags_vertical=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",SpaceUI.style(Color("09231a"),18,Color("497457")))
	add_child(panel)
	output=RichTextLabel.new()
	var fixed:=SpaceUI.FONT
	output.add_theme_font_override("normal_font",fixed)
	output.add_theme_font_size_override("normal_font_size",17)
	output.scroll_following=false
	output.text=""
	panel.add_child(output)
	_line("HYPERION  /  PREFLIGHT",GREEN)
	_line("> mounted   "+cartridge,GREEN)
	_line("Ready for diagnostics.",GREEN)
	run_button=SpaceUI.button(self,"Run diagnostics",run_report,38)

func _line(message: String, color: Color) -> void:
	output.push_color(color)
	output.add_text(message+"\n")
	output.pop()

func run_report() -> void:
	if run_button.disabled:return
	run_button.disabled=true
	output.clear()
	var report: String=action.call()
	_line("> check --mission --payload --launcher",GREEN)
	_line("  Reading mission brief ...",GREEN)
	_line("  Comparing spacecraft and launcher ...",GREEN)
	for record in report.split("\n",false):
		if record.begins_with("Engineering review: "):
			for fault in record.trim_prefix("Engineering review: ").split("; ",false):
				_line("  [CHECK] "+fault,RED)
		else:
			var bad: bool=record.begins_with("FAIL") or record.begins_with("ERROR")
			_line(record,RED if bad else GREEN)
	output.scroll_to_line(0)
	output.visible_characters=0
	animation=create_tween()
	animation.tween_method(func(n:int):output.visible_characters=n,0,output.get_total_character_count(),clampf(output.get_total_character_count()/200.0,0.5,5.0))
	animation.tween_callback(func():run_button.disabled=false)
